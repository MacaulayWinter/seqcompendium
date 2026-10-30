# toy.R: invented test bundles (never research data; CLAUDE.md hard rules).
#
# The main toy: 12 subjects (6 control, 6 treated), each sampled at T0 and T1,
# 30 invented features in three classes, two extraction blanks and one mock
# community. Every number comes from the random generator with a fixed seed;
# nothing resembles a real study.

#' Write an invented bundle for tests and demonstrations
#'
#' @param dir folder to write the bundle into (created).
#' @param variant "main"; "no_controls" (no control samples, no sample_control
#'   column); "copy_null" (each treated sample is an exact copy of a control
#'   sample's counts, so the groups cannot differ); "planted" (treated samples'
#'   reads concentrated in 3 features: far lower diversity, shifted
#'   composition); "planted_da" (3 features, toyG06-08, at 8 times the mean in
#'   treated samples, forming the set "planted"); "spread" (9 control and 3
#'   treated subjects, treated far more variable); "zeroinfl_few" (3 features
#'   with 60 percent structural zeros) and "zeroinfl_many" (15 features with
#'   70 percent);
#'   "presence" (toyG15 present in every treated sample, absent from every
#'   control); "no_denominator" (no denominators file); "proportions" (the
#'   layer as proportions, unit proportion); "calib" (20 subjects, 10 per
#'   group, one timepoint, 2 mocks with a known composition: enough reference
#'   samples for the override rule's simulation, E4) and "calib_mocks6" (the
#'   same with 6 mocks, so the shuffled-label mock test can run).
#'   E5 (longitudinal; the same subjects at every timepoint): "long_planted"
#'   (toyG06-08 at 8 times the mean in treated samples at T1 only),
#'   "long_div" (treated samples' reads concentrated in 3 features at T1 only),
#'   "few_subjects" (2 subjects per group), "long40" (20 subjects per group),
#'   "long4tp" (4 timepoints), "long_zeroinfl" (40 subjects; 15 features with extra
#'   structural zeros; 50 percent in "long_zeroinfl"). E5 (adjustment, one timepoint, 20 subjects): "adjust"
#'   (a second predictor `diet`, unbalanced across groups, carries the planted
#'   effect on toyG06-08) and "confounded_batch" (batch identical to group).
#'   "main" and "no_controls" are longitudinal too; every other variant gives
#'   each sample its own subject, so it is a snapshot design.
#'   In every variant with controls, toyG26-30 are contaminants: common in the
#'   blanks, rare in study samples.
#' @param seed random seed.
#' @return the bundle folder, invisibly.
#' @export
make_toy_bundle <- function(dir, variant = c("main", "no_controls", "copy_null", "planted", "planted_da", "spread", "zeroinfl_few",
                                             "zeroinfl_many", "presence", "no_denominator", "proportions", "calib", "calib_mocks6",
                                             "long_planted", "long_div", "few_subjects", "long40", "long4tp", "long_zeroinfl",
                                             "adjust", "confounded_batch"), seed = 20261029L) {
  variant <- match.arg(variant)
  set.seed(seed)
  n_f <- 30
  feats <- sprintf("toyG%02d", seq_len(n_f))
  calib <- variant %in% c("calib", "calib_mocks6")
  one_time <- variant %in% c("calib", "calib_mocks6", "adjust", "confounded_batch")
  paired <- variant %in% c("main", "no_controls", "long_planted", "long_div", "few_subjects", "long40", "long4tp", "long_zeroinfl")
  n_subj <- if (one_time) 20 else switch(variant, long40 = 40, long_zeroinfl = 40, few_subjects = 4, 12)
  times <- if (one_time) "T0" else if (variant == "long4tp") sprintf("T%d", 0:3) else c("T0", "T1")
  subj <- sprintf("S%02d", seq_len(n_subj))
  group <- if (variant == "spread") rep(c("control", "treated"), c(9, 3)) else rep(c("control", "treated"), each = length(subj) / 2)
  study <- expand.grid(t = times, s = seq_along(subj), stringsAsFactors = FALSE)
  md <- data.frame(sample = sprintf("%s_%s", subj[study$s], study$t), subject = subj[study$s], group = group[study$s],
                   day = study$t, run = ifelse(study$s %% 2 == 1, "run1", "run2"), kind = "none", stringsAsFactors = FALSE)
  if (variant == "confounded_batch") md$run <- ifelse(md$group == "control", "run1", "run2")
  if (variant == "adjust") {
    # diet unbalanced across group: 8 of 10 treated subjects high-fat, 2 of 10 controls.
    k <- (study$s - 1) %% 10
    md$diet <- ifelse((md$group == "treated" & k < 8) | (md$group == "control" & k < 2), "high", "low")
  }
  mu <- exp(stats::rnorm(n_f, 3, 1.2))
  depth <- stats::runif(nrow(md), 0.5, 2)
  mu[26:30] <- 0.15   # contaminants: rare in study samples
  treated <- md$group == "treated"
  size <- if (variant == "spread") ifelse(treated, 0.15, 5) else rep(2, nrow(md))
  counts <- t(vapply(seq_len(nrow(md)), function(j) stats::rnbinom(n_f, mu = mu * depth[j], size = size[j]), numeric(n_f)))
  if (variant == "planted_da") counts[treated, 6:8] <- t(vapply(which(treated), function(j) stats::rnbinom(3, mu = 8 * mu[6:8] * depth[j], size = 2), numeric(3)))
  if (variant %in% c("zeroinfl_few", "zeroinfl_many")) {
    # few: 3 features (a misfit chance could explain); many: 15 of 30 with more
    # zeros (clearly more failures than chance; CLAUDE.md D17, D18).
    zf <- if (variant == "zeroinfl_few") 9:11 else 9:23
    for (k in zf) counts[stats::runif(nrow(md)) < (if (variant == "zeroinfl_few") 0.6 else 0.7), k] <- 0
  }
  if (variant == "long_planted") { i <- which(treated & md$day == "T1"); counts[i, 6:8] <- t(vapply(i, function(j) stats::rnbinom(3, mu = 8 * mu[6:8] * depth[j], size = 2), numeric(3))) }
  if (variant == "long_div") for (j in which(treated & md$day == "T1")) counts[j, ] <- stats::rnbinom(n_f, mu = c(rep(400, 3), rep(0.3, n_f - 3)) * depth[j], size = 2)
  if (variant == "long_zeroinfl") for (k in 9:23) counts[stats::runif(nrow(md)) < 0.5, k] <- 0
  if (variant == "adjust") { i <- which(md$diet == "high"); counts[i, 6:8] <- t(vapply(i, function(j) stats::rnbinom(3, mu = 6 * mu[6:8] * depth[j], size = 2), numeric(3))) }
  if (variant == "presence") { counts[!treated, 15] <- 0; counts[treated, 15] <- stats::rnbinom(sum(treated), mu = 50, size = 5) + 1 }
  if (variant == "copy_null") {
    # Treated subject k (7-12) at time t is an exact copy of control subject k-6 at time t.
    for (j in which(treated)) counts[j, ] <- counts[md$subject == subj[match(md$subject[j], subj) - 6] & md$day == md$day[j], ]
  }
  if (variant == "planted") {
    for (j in which(treated)) counts[j, ] <- stats::rnbinom(n_f, mu = c(rep(400, 3), rep(0.3, n_f - 3)) * depth[j], size = 2)
  }
  if (variant != "no_controls") {
    n_mock <- switch(variant, calib = 2, calib_mocks6 = 6, 1)
    ctl <- data.frame(sample = c("BLANK1", "BLANK2", sprintf("MOCK%d", seq_len(n_mock))), subject = NA, group = NA, day = NA, run = "run1",
                      kind = c("negative_extraction", "negative_extraction", rep("positive_mock", n_mock)), stringsAsFactors = FALSE)
    blank <- function() stats::rnbinom(n_f, mu = c(rep(0.05, n_f - 5), rep(30, 5)), size = 2)
    # The mock: 8 known members at equal abundance (toyG01-08).
    mock <- function() if (n_mock == 1) c(rep(200, 8), rep(0, n_f - 8)) else c(stats::rnbinom(8, mu = 200, size = 50), rep(0, n_f - 8))
    counts <- rbind(counts, blank(), blank(), t(vapply(seq_len(n_mock), function(i) mock(), numeric(n_f))))
    if (!is.null(md$diet)) ctl$diet <- NA
    md <- rbind(md, ctl)
  }
  if (variant == "no_controls") md$kind <- NULL
  rownames(counts) <- md$sample; colnames(counts) <- feats

  dir.create(file.path(dir, "metadata"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(dir, "layers"), recursive = TRUE, showWarnings = FALSE)
  tsv <- function(x, f) utils::write.table(x, file.path(dir, f), sep = "\t", quote = FALSE, row.names = FALSE, na = "")
  # Snapshot variants: each sample is its own subject, so no subject is
  # sampled twice (CLAUDE.md D26).
  if (!paired) md$subject <- ifelse(is.na(md$subject), NA, paste0(md$subject, "_", md$day))
  tsv(md, "metadata/study_metadata.tsv")
  guide <- data.frame(column = c("subject", "group", "day", "run", "kind"),
                      role = c("subject_id", "predictor", "time", "batch", "sample_control"),
                      type = c("text", "categorical", "ordinal", "categorical", "categorical"),
                      levels = c("", "control|treated", paste(if (variant == "long4tp") times else c("T0", "T1"), collapse = "|"), "run1|run2", "none|negative_extraction|positive_mock"),
                      description = c("toy subject", "toy treatment group", "toy sampling time", "toy extraction run", "control samples (F8)"))
  if (variant == "adjust") guide <- rbind(guide, data.frame(column = "diet", role = "predictor", type = "categorical", levels = "low|high", description = "toy diet"))
  if (variant == "no_controls") guide <- guide[guide$column != "kind", ]
  utils::write.csv(guide, file.path(dir, "metadata/column_guide.csv"), row.names = FALSE, na = "")
  values <- if (variant == "proportions") round(counts / pmax(rowSums(counts), 1), 8) else counts
  long <- data.frame(sample = rep(md$sample, each = n_f), feature = rep(feats, nrow(md)), value = as.vector(t(values)))
  tsv(long, "layers/toy_counts.tsv")
  cls <- rep(c("A", "B", "C"), length.out = n_f)
  if (variant == "planted_da") cls[6:8] <- "planted"
  tsv(data.frame(feature = feats, label = sprintf("toy gene %d", seq_len(n_f)), toy_class = cls), "layers/toy_counts_features.tsv")
  if (calib) tsv(data.frame(feature = feats[1:8], proportion = 0.125), "layers/mock_composition.tsv")
  if (!variant %in% c("no_denominator", "proportions"))
    tsv(data.frame(sample = md$sample, total_reads = as.integer(rowSums(counts) * 50 + 1000)), "layers/toy_counts_denominators.tsv")
  yaml::write_yaml(list(
    bundle_version = 1L,
    produced_by = list(pipeline = "seqcompendium make_toy_bundle()", variant = variant, seed = seed),
    metadata = list(table = "metadata/study_metadata.tsv", column_guide = "metadata/column_guide.csv"),
    layers = list(Filter(Negate(is.null), list(name = "toy_counts", file = "layers/toy_counts.tsv",
                       unit = if (variant == "proportions") "proportion" else "count", feature_level = "toy gene",
                       features = "layers/toy_counts_features.tsv", feature_columns = list(label = "label", toy_class = "set"),
                       denominators = if (!variant %in% c("no_denominator", "proportions")) list(file = "layers/toy_counts_denominators.tsv", columns = list(total_reads = "reads")),
                       mock_composition = if (calib) "layers/mock_composition.tsv",
                       source = list(tool = "make_toy_bundle", version = "1"))))),
    file.path(dir, "manifest.yaml"))
  invisible(dir)
}
