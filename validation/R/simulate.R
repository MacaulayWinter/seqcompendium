# simulate.R: simulated bundles for the engine's validation
# (validation/PREREGISTRATION.md §3; CLAUDE.md D33, D34).
#
# S1 counts: MIDASim fitted to a template (samples x features counts),
# simulating at the template's library sizes. Planting multiplies a set of
# features by the fold change in one group on the absolute scale before counts
# are drawn, so observed shares shift through renormalisation, as in real data.
# Every bundle gets 2 extraction blanks carrying the 5 contaminant features and
# 1 mock with 8 features at equal known abundance (F8).

# The template, fitted once. counts: samples x features; reads: the template's
# denominator (total reads per sample) or NULL.
fit_template <- function(counts, reads = NULL, seed = 20261029L) {
  counts <- round(as.matrix(counts))
  counts <- counts[rowSums(counts) > 0, colSums(counts) > 0, drop = FALSE]
  set.seed(seed)
  midas <- suppressMessages(MIDASim::MIDASim.setup(counts, mode = "parametric"))
  base <- colMeans(counts / rowSums(counts)); base <- pmax(base, 1e-8); base <- base / sum(base)
  ratio <- if (is.null(reads)) NULL else reads[match(rownames(counts), names(reads))] / rowSums(counts)
  list(midas = midas, counts = counts, base = base, libs = rowSums(counts), ratio = ratio,
       common = colnames(counts)[colMeans(counts > 0) >= 0.5])
}

# The samples of one design. design: "two_group", "three_group", "longitudinal",
# "blocks", "paired" (two conditions per subject, one time). n: per group (per
# group within each block for "blocks"). Snapshot samples are their own subjects.
design_samples <- function(design, n) {
  g2 <- c("control", "treated"); g3 <- c("control", "dose_low", "dose_high")
  blocked <- grepl("_blocks$", design) || design == "blocks"
  base <- sub("_blocks$", "", design); if (base == "blocks") base <- "two_group"
  one <- function(pre) switch(base,
    two_group    = data.frame(subject = sprintf("%sS%03d", pre, seq_len(2 * n)), group = rep(g2, each = n), day = "T0"),
    three_group  = data.frame(subject = sprintf("%sS%03d", pre, seq_len(3 * n)), group = rep(g3, each = n), day = "T0"),
    longitudinal = { s <- sprintf("%sS%03d", pre, seq_len(2 * n)); data.frame(subject = rep(s, each = 2), group = rep(rep(g2, each = n), each = 2), day = rep(c("T0", "T1"), 2 * n)) },
    paired       = { s <- sprintf("%sS%03d", pre, seq_len(n)); data.frame(subject = rep(s, each = 2), group = rep(g2, n), day = "T0") },
    stop("unknown design ", design))
  d <- if (blocked) rbind(cbind(one("A"), site = "siteA"), cbind(one("B"), site = "siteB")) else cbind(one(""), site = NA)
  d$sample <- sprintf("%s_%s_%s", d$subject, d$day, substr(d$group, 1, 4))
  d
}

# Draw one study's counts. plant: list(features, fc, in_group) or NULL;
# subject_sd: log-scale sd of each subject's own composition, shared by its
# samples (designs with repeated subjects); block_shift: features x2 in siteB.
simulate_counts <- function(fit, samples, plant = NULL, subject_sd = 0.5, block_shift = NULL, extra = NULL) {
  n <- nrow(samples); p <- length(fit$base)
  M <- matrix(fit$base, n, p, byrow = TRUE, dimnames = list(samples$sample, names(fit$base)))
  if (anyDuplicated(samples$subject)) {
    eff <- matrix(stats::rnorm(length(unique(samples$subject)) * p, 0, subject_sd), ncol = p, dimnames = list(unique(samples$subject), NULL))
    M <- M * exp(eff[samples$subject, , drop = FALSE])
  }
  if (length(block_shift)) M[samples$site %in% "siteB", block_shift] <- M[samples$site %in% "siteB", block_shift] * 2
  if (!is.null(plant) && length(plant$features)) {
    i <- samples$group %in% plant$in_group & (is.null(plant$at_time) | samples$day %in% plant$at_time)
    M[i, plant$features] <- M[i, plant$features] * plant$fc
  }
  if (!is.null(extra)) M <- extra(M, samples)
  M <- M / rowSums(M)
  lib <- sample(fit$libs, n, replace = TRUE)
  mod <- suppressMessages(MIDASim::MIDASim.modify(fit$midas, lib.size = lib, individual.rel.abund = M))
  m <- suppressMessages(MIDASim::MIDASim(mod))$sim_count
  dimnames(m) <- list(samples$sample, names(fit$base))
  den <- if (is.null(fit$ratio)) NULL else round(rowSums(m) * sample(fit$ratio, n, replace = TRUE))
  list(m = m, den = den)
}

# Control samples (F8): 2 blanks carrying exactly the 5 contaminants at low
# counts, 1 mock with 8 features at equal known abundance. The contaminants
# and the mock members are features the study samples also carry.
control_counts <- function(fit, contaminants, mock_members) {
  p <- length(fit$base); f <- names(fit$base)
  blank <- function() { v <- stats::setNames(numeric(p), f); v[contaminants] <- stats::rnbinom(length(contaminants), mu = 30, size = 2) + 1; v }
  mock <- stats::setNames(numeric(p), f); mock[mock_members] <- 2000
  m <- rbind(BLANK1 = blank(), BLANK2 = blank(), MOCK1 = mock)
  list(m = m, kind = c("negative_extraction", "negative_extraction", "positive_mock"))
}

# One simulated bundle, written in the engine's input format, with its truth.
# spec: list(design, n, fc = 1, plant_share = 0, plant_time = NULL,
#            contaminants_in_study = FALSE, extra = NULL, controls = TRUE)
simulate_bundle <- function(fit, spec, seed, dir, scenario = NA_character_) {
  set.seed(seed)
  spec <- utils::modifyList(list(zero_inflate = NULL, plant_top = NULL, fc = 1, plant_share = 0, plant_time = NULL, contaminants_in_study = FALSE, extra = NULL, controls = TRUE, block_shift = 0.1), spec)
  smp <- design_samples(spec$design, spec$n)
  f <- names(fit$base)
  planted <- if (spec$plant_share > 0) sort(sample(fit$common, max(1, round(spec$plant_share * length(f))))) else character(0)
  # V-E5 (ii): the 3 dominant features x 10 in one group, nothing else changed.
  if (!is.null(spec$plant_top)) planted <- names(sort(fit$base, decreasing = TRUE))[seq_len(spec$plant_top)]
  in_group <- if (spec$design == "three_group") "dose_high" else "treated"
  plant <- if (length(planted)) list(features = planted, fc = spec$fc, in_group = in_group, at_time = spec$plant_time) else NULL
  shift <- if (grepl("blocks", spec$design)) sample(f, max(1, round(spec$block_shift * length(f)))) else NULL
  sim <- simulate_counts(fit, smp, plant = plant, block_shift = shift, extra = spec$extra)
  # The 5 contaminants are rare in study samples unless the scenario plants them there (V-E2b).
  rare <- f[order(fit$base)][seq_len(min(length(f), max(25, ceiling(length(f) / 2))))]
  contaminants <- sort(sample(setdiff(rare, planted), 5))
  mock_members <- sort(sample(setdiff(f, contaminants), 8))
  md <- data.frame(sample = smp$sample, subject = smp$subject, group = smp$group, day = smp$day, site = smp$site, kind = "none", stringsAsFactors = FALSE)
  m <- sim$m; den <- sim$den
  if (!is.null(spec$zero_inflate)) {
    # V-E5 (iii): this share of each feature's non-zero values set to zero.
    for (j in seq_len(ncol(m))) { nz <- which(m[, j] > 0); if (length(nz)) m[nz[stats::runif(length(nz)) < spec$zero_inflate], j] <- 0 }
  }
  if (spec$controls) {
    ctl <- control_counts(fit, contaminants, mock_members)
    md <- rbind(md, data.frame(sample = rownames(ctl$m), subject = NA, group = NA, day = NA, site = NA, kind = ctl$kind))
    m <- rbind(m, ctl$m)
    if (!is.null(den)) den <- c(den, stats::setNames(round(rowSums(ctl$m) * stats::median(fit$ratio)), rownames(ctl$m)))
  }
  if (!spec$contaminants_in_study) m[md$kind == "none", contaminants] <- pmin(m[md$kind == "none", contaminants], 1)
  write_bundle(dir, md, m, den, spec, seed, scenario, has_block = grepl("blocks", spec$design), mock_members = if (spec$controls) mock_members)
  truth <- list(scenario = scenario, seed = seed, design = spec$design, n = spec$n, fc = spec$fc, planted = planted, in_group = in_group,
                contaminants = contaminants, mock_members = mock_members, block_shifted = shift,
                class = if (grepl("^longitudinal", spec$design)) "longitudinal" else if (grepl("^paired", spec$design)) "snapshot-paired" else "snapshot-independent",
                n_study_samples = nrow(smp), subjects = length(unique(smp$subject)),
                timepoints = if (grepl("^longitudinal", spec$design)) "T0, T1" else "T0", blocks = if (grepl("blocks", spec$design)) "site" else "none")
  yaml::write_yaml(truth, file.path(dir, "truth.yaml"))
  invisible(truth)
}

write_bundle <- function(dir, md, m, den, spec, seed, scenario, has_block, mock_members) {
  dir.create(file.path(dir, "metadata"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(dir, "layers"), recursive = TRUE, showWarnings = FALSE)
  tsv <- function(x, f) utils::write.table(x, file.path(dir, f), sep = "\t", quote = FALSE, row.names = FALSE, na = "")
  groups <- unique(stats::na.omit(md$group))
  if (!has_block) md$site <- NULL
  if (is.null(mock_members)) md$kind <- NULL
  tsv(md, "metadata/study_metadata.tsv")
  guide <- data.frame(column = c("subject", "group", "day"), role = c("subject_id", "predictor", "time"), type = c("text", "categorical", "ordinal"),
                      levels = c("", paste(groups, collapse = "|"), paste(sort(unique(stats::na.omit(md$day))), collapse = "|")),
                      description = c("simulated subject", "simulated group", "simulated sampling time"))
  if (has_block) guide <- rbind(guide, data.frame(column = "site", role = "block", type = "categorical", levels = "siteA|siteB", description = "simulated site"))
  if (!is.null(mock_members)) guide <- rbind(guide, data.frame(column = "kind", role = "sample_control", type = "categorical", levels = "none|negative_extraction|positive_mock", description = "control samples (F8)"))
  utils::write.csv(guide, file.path(dir, "metadata/column_guide.csv"), row.names = FALSE, na = "")
  f <- colnames(m)
  tsv(data.frame(sample = rep(rownames(m), each = ncol(m)), feature = rep(f, nrow(m)), value = as.vector(t(m))), "layers/sim_counts.tsv")
  tsv(data.frame(feature = f, label = f), "layers/sim_counts_features.tsv")
  if (!is.null(mock_members)) tsv(data.frame(feature = mock_members, proportion = 1 / length(mock_members)), "layers/mock_composition.tsv")
  if (!is.null(den)) tsv(data.frame(sample = names(den), total_reads = as.integer(den)), "layers/sim_counts_denominators.tsv")
  yaml::write_yaml(list(
    bundle_version = 1L,
    produced_by = list(pipeline = "seqcompendium validation simulate_bundle()", scenario = scenario, seed = seed),
    metadata = list(table = "metadata/study_metadata.tsv", column_guide = "metadata/column_guide.csv"),
    layers = list(Filter(Negate(is.null), list(name = "sim_counts", file = "layers/sim_counts.tsv", unit = "count", feature_level = "simulated taxon",
                       features = "layers/sim_counts_features.tsv", feature_columns = list(label = "label"),
                       denominators = if (!is.null(den)) list(file = "layers/sim_counts_denominators.tsv", columns = list(total_reads = "reads")),
                       mock_composition = if (!is.null(mock_members)) "layers/mock_composition.tsv",
                       source = list(tool = "simulate_bundle", version = "1"))))),
    file.path(dir, "manifest.yaml"))
}

# Seeds (PREREGISTRATION.md §4): run k of scenario s.
run_seed <- function(s, k, fresh = FALSE) 20261029L + 1000L * as.integer(s) + as.integer(k) + if (fresh) 500000L else 0L

# Fresh data (PREREGISTRATION.md §8): the next templates in the data-choice order.
fresh_template <- function(t) c(shotgun1 = "shotgun4", shotgun2 = "shotgun5", shotgun3 = "shotgun4", `16S1` = "16S3", `16S2` = "16S3")[[t]]
