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
#'   reads concentrated in 3 features, so their diversity is far lower).
#' @param seed random seed.
#' @return the bundle folder, invisibly.
#' @export
make_toy_bundle <- function(dir, variant = c("main", "no_controls", "copy_null", "planted"), seed = 20261029L) {
  variant <- match.arg(variant)
  set.seed(seed)
  n_f <- 30
  feats <- sprintf("toyG%02d", seq_len(n_f))
  subj <- sprintf("S%02d", 1:12)
  group <- rep(c("control", "treated"), each = 6)
  study <- expand.grid(t = c("T0", "T1"), s = seq_along(subj), stringsAsFactors = FALSE)
  md <- data.frame(sample = sprintf("%s_%s", subj[study$s], study$t), subject = subj[study$s], group = group[study$s],
                   day = study$t, run = ifelse(study$s %% 2 == 1, "run1", "run2"), kind = "none", stringsAsFactors = FALSE)
  mu <- exp(stats::rnorm(n_f, 3, 1.2))
  depth <- stats::runif(nrow(md), 0.5, 2)
  counts <- t(vapply(seq_len(nrow(md)), function(j) stats::rnbinom(n_f, mu = mu * depth[j], size = 2), numeric(n_f)))
  treated <- md$group == "treated"
  if (variant == "copy_null") {
    # Treated subject k (7-12) at time t is an exact copy of control subject k-6 at time t.
    for (j in which(treated)) counts[j, ] <- counts[md$subject == subj[match(md$subject[j], subj) - 6] & md$day == md$day[j], ]
  }
  if (variant == "planted") {
    for (j in which(treated)) counts[j, ] <- stats::rnbinom(n_f, mu = c(rep(400, 3), rep(0.3, n_f - 3)) * depth[j], size = 2)
  }
  if (variant != "no_controls") {
    ctl <- data.frame(sample = c("BLANK1", "BLANK2", "MOCK1"), subject = NA, group = NA, day = NA, run = "run1",
                      kind = c("negative_extraction", "negative_extraction", "positive_mock"), stringsAsFactors = FALSE)
    blank <- function() stats::rnbinom(n_f, mu = c(rep(2, 5), rep(0.05, n_f - 5)), size = 1)
    counts <- rbind(counts, blank(), blank(), c(rep(200, 8), rep(0, n_f - 8)))
    md <- rbind(md, ctl)
  }
  if (variant == "no_controls") md$kind <- NULL
  rownames(counts) <- md$sample; colnames(counts) <- feats

  dir.create(file.path(dir, "metadata"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(dir, "layers"), recursive = TRUE, showWarnings = FALSE)
  tsv <- function(x, f) utils::write.table(x, file.path(dir, f), sep = "\t", quote = FALSE, row.names = FALSE, na = "")
  tsv(md, "metadata/study_metadata.tsv")
  guide <- data.frame(column = c("subject", "group", "day", "run", "kind"),
                      role = c("subject_id", "predictor", "time", "batch", "sample_control"),
                      type = c("text", "categorical", "ordinal", "categorical", "categorical"),
                      levels = c("", "control|treated", "T0|T1", "run1|run2", "none|negative_extraction|positive_mock"),
                      description = c("toy subject", "toy treatment group", "toy sampling time", "toy extraction run", "control samples (F8)"))
  if (variant == "no_controls") guide <- guide[guide$column != "kind", ]
  utils::write.csv(guide, file.path(dir, "metadata/column_guide.csv"), row.names = FALSE, na = "")
  long <- data.frame(sample = rep(md$sample, each = n_f), feature = rep(feats, nrow(md)), value = as.vector(t(counts)))
  tsv(long, "layers/toy_counts.tsv")
  tsv(data.frame(feature = feats, label = sprintf("toy gene %d", seq_len(n_f)), toy_class = rep(c("A", "B", "C"), length.out = n_f)),
      "layers/toy_counts_features.tsv")
  tsv(data.frame(sample = md$sample, total_reads = as.integer(rowSums(counts) * 50 + 1000)), "layers/toy_counts_denominators.tsv")
  yaml::write_yaml(list(
    bundle_version = 1L,
    produced_by = list(pipeline = "seqcompendium make_toy_bundle()", variant = variant, seed = seed),
    metadata = list(table = "metadata/study_metadata.tsv", column_guide = "metadata/column_guide.csv"),
    layers = list(list(name = "toy_counts", file = "layers/toy_counts.tsv", unit = "count", feature_level = "toy gene",
                       features = "layers/toy_counts_features.tsv", feature_columns = list(label = "label", toy_class = "set"),
                       denominators = list(file = "layers/toy_counts_denominators.tsv", columns = list(total_reads = "reads")),
                       source = list(tool = "make_toy_bundle", version = "1")))),
    file.path(dir, "manifest.yaml"))
  invisible(dir)
}
