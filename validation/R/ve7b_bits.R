# ve7b_bits.R: the parts of validation/ve7b_nearing.R that are tested on their
# own (validation/tests/test-ve7b.R; CLAUDE.md D52).

# The tables are large (ArcticFreshwaters: 178,927 ASVs x 2,468 samples, 1.8 GB of
# text), so they are read with data.table and filtered column by column before
# becoming a matrix (features x samples).
# prev_over = "analysed" (the default, as before): the 10% is counted over the analysed samples.
# prev_over = "all_samples" (optional, D66): over every sample of the table, in the order the paper's own script evidently used.
read_asvs <- function(f, samples, prev_over = c("analysed", "all_samples")) {
  prev_over <- match.arg(prev_over)
  dt <- data.table::fread(f, skip = 1, header = TRUE, sep = "\t", showProgress = FALSE)
  feat <- dt[[1]]; keep <- intersect(samples, names(dt)[-1])
  cnt <- if (prev_over == "all_samples") names(dt)[-1] else keep
  nz <- integer(nrow(dt)); for (k in cnt) nz <- nz + (dt[[k]] > 0)
  rows <- nz >= 0.10 * length(cnt)                        # the paper's filter: present in >= 10% of samples
  m <- vapply(keep, function(k) as.numeric(dt[[k]][rows]), numeric(sum(rows)))
  rownames(m) <- feat[rows]
  m
}

VE7B_SETS <- list(ArcticFireSoils = list(label = "Soil - Fires", column = "Fire"),
                  ArcticFreshwaters = list(label = "Freshwater - Arctic", column = "Location"))

# Writes data set d as an engine bundle in folder b and returns its matrix
# (features x samples after the paper's 10% filter).
ve7b_write_bundle <- function(sdir, d, s, b, filter = c("analysed", "all_samples")) {
  filter <- match.arg(filter)
  if (filter == "all_samples" && d != "ArcticFreshwaters") stop("the optional all-samples prevalence filter is for ArcticFreshwaters only (CLAUDE.md D66)")
  dir.create(file.path(b, "metadata"), recursive = TRUE); dir.create(file.path(b, "layers"))
  meta <- utils::read.delim(file.path(sdir, d, sprintf("%s_meta.tsv", d)), check.names = FALSE, comment.char = "")
  names(meta)[1] <- "sample"
  # The paper's sample set: the samples kept by its rarefaction (the columns of
  # <data set>_ASVs_table_rare.tsv; Source Data "Figure1B_dataset_char (filt)" gives
  # 147 and 936 samples), with the unrarefied counts (D48).
  rare <- strsplit(readLines(file.path(sdir, d, sprintf("%s_ASVs_table_rare.tsv", d)), n = 2)[2], "\t")[[1]][-1]
  m <- read_asvs(file.path(sdir, d, sprintf("%s_ASVs_table.tsv", d)), intersect(meta$sample[!is.na(meta[[s$column]]) & nzchar(meta[[s$column]])], rare), filter)
  keep <- colnames(m)
  lv <- sort(unique(meta[[s$column]][match(keep, meta$sample)]))
  utils::write.table(data.frame(sample = keep, group = meta[[s$column]][match(keep, meta$sample)]), file.path(b, "metadata/study_metadata.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.csv(data.frame(column = "group", role = "predictor", type = "categorical", levels = paste(lv, collapse = "|"), description = s$column),
                   file.path(b, "metadata/column_guide.csv"), row.names = FALSE)
  utils::write.table(data.frame(sample = rep(colnames(m), each = nrow(m)), feature = rep(rownames(m), ncol(m)), value = as.vector(m)),
                     file.path(b, "layers/asv.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.table(data.frame(feature = rownames(m), label = rownames(m)), file.path(b, "layers/asv_features.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  yaml::write_yaml(list(bundle_version = 1L, produced_by = list(pipeline = "validation V-E7b: Nearing 2022", dataset = d),
                        metadata = list(table = "metadata/study_metadata.tsv", column_guide = "metadata/column_guide.csv"),
                        layers = list(list(name = "asv", file = "layers/asv.tsv", unit = "count", feature_level = "ASV", features = "layers/asv_features.tsv",
                                           feature_columns = list(label = "label"), source = list(tool = "Nearing 2022 figshare 14531724", version = "21_03_08")))),
                   file.path(b, "manifest.yaml"))
  m
}

# The engine's count of significant features for one method, counted as the
# paper counts them: BH q < 0.05 over the method's finite p-values; for
# LEfSe (D19) the features it reports (Q4_describe_only.csv). LEfSe always
# writes one row: with feature NA it means LEfSe flagged nothing or did not run
# (its note says which), so NA is never counted as a feature.
# A method that failed is NA (unknown), never 0: on the cluster ALDEx2 failed
# inside the engine and the old script counted it as 0 (V-E7b, D55).
#
# Where the rows come from (the scoring rule of PREREGISTRATION section 9, "V-E7(c) scorer"):
# a method that is the engine's DEFAULT for the comparison has its rows in the default
# table (03_results/Q4_differential/results.csv, argument `df`), not in the table of the
# alternatives (04_agreement/Q4.csv, `ag`). Count from `df` when the method is in it;
# otherwise from `ag`. A method in both is counted from `df`. `df` is optional (NULL keeps
# the old behaviour, reading `ag` only).
ve7b_count_source <- function(id, ag, ds, df = NULL) {
  if (id == "D19") return("describe_only")
  if (!is.null(df) && any(df$method_id == id, na.rm = TRUE)) return("default")
  "alternatives"
}
ve7b_engine_count <- function(id, ag, ds, df = NULL) {
  if (nzchar(ve7b_engine_failure(id, ag, ds, df))) return(NA_integer_)
  if (id == "D19") return(length(unique(stats::na.omit(ds$feature[ds$method_id == "D19"]))))
  tab <- if (identical(ve7b_count_source(id, ag, ds, df), "default")) df else ag
  x <- tab[tab$method_id == id & is.finite(tab$p), , drop = FALSE]
  sum(stats::p.adjust(x$p, "BH") < 0.05)
}

# Why the engine has no count for a method ("" when it has one): its table is
# missing, LEfSe did not run, or the method failed to fit (the engine's note,
# which carries the method's own error message since D55).
ve7b_engine_failure <- function(id, ag, ds, df = NULL) {
  tab <- if (id == "D19") ds else if (identical(ve7b_count_source(id, ag, ds, df), "default")) df else ag
  if (is.null(tab)) return(sprintf("no %s table from the engine", if (id == "D19") "Q4_describe_only.csv" else "Q4.csv"))
  x <- tab[tab$method_id == id, , drop = FALSE]
  if (!nrow(x)) return("the method has no rows in the engine's table")
  note <- if ("note" %in% names(x)) unique(stats::na.omit(x$note[grepl("failed to fit|did not run", x$note)])) else character(0)
  if (length(note)) return(paste(note, collapse = " | "))
  if (id != "D19" && !any(is.finite(x$p))) return("the method gave no p-value for any feature")
  ""
}

# The engine's own tables, notes and report are copied out of the compendium
# before it is deleted, so a difference can be traced without a rerun.
VE7B_KEEP <- c("04_agreement/Q4.csv", "04_agreement/Q4_describe_only.csv", "03_results/Q4_differential/results.csv",
               "00_input_check/bundle_check.csv", "report/compendium_report.md", "provenance/engine.yaml", "provenance/step_timings.tsv")
ve7b_keep_engine_files <- function(out, keep_dir) {
  unlink(keep_dir, recursive = TRUE); dir.create(keep_dir, recursive = TRUE)
  have <- VE7B_KEEP[file.exists(file.path(out, VE7B_KEEP))]
  file.copy(file.path(out, have), file.path(keep_dir, gsub("/", "__", have)))
  invisible(gsub("/", "__", have))
}
