# ve7b_bits.R: the parts of validation/ve7b_nearing.R that are tested on their
# own (validation/tests/test-ve7b.R; CLAUDE.md D52).

# The tables are large (ArcticFreshwaters: 178,927 ASVs x 2,468 samples, 1.8 GB of
# text), so they are read with data.table and filtered column by column before
# becoming a matrix (features x samples).
read_asvs <- function(f, samples) {
  dt <- data.table::fread(f, skip = 1, header = TRUE, sep = "\t", showProgress = FALSE)
  feat <- dt[[1]]; keep <- intersect(samples, names(dt)[-1])
  nz <- integer(nrow(dt)); for (k in keep) nz <- nz + (dt[[k]] > 0)
  rows <- nz >= 0.10 * length(keep)                       # the paper's filter: present in >= 10% of samples
  m <- vapply(keep, function(k) as.numeric(dt[[k]][rows]), numeric(sum(rows)))
  rownames(m) <- feat[rows]
  m
}

VE7B_SETS <- list(ArcticFireSoils = list(label = "Soil - Fires", column = "Fire"),
                  ArcticFreshwaters = list(label = "Freshwater - Arctic", column = "Location"))

# Writes data set d as an engine bundle in folder b and returns its matrix
# (features x samples after the paper's 10% filter).
ve7b_write_bundle <- function(sdir, d, s, b) {
  dir.create(file.path(b, "metadata"), recursive = TRUE); dir.create(file.path(b, "layers"))
  meta <- utils::read.delim(file.path(sdir, d, sprintf("%s_meta.tsv", d)), check.names = FALSE, comment.char = "")
  names(meta)[1] <- "sample"
  # The paper's sample set: the samples kept by its rarefaction (the columns of
  # <data set>_ASVs_table_rare.tsv; Source Data "Figure1B_dataset_char (filt)" gives
  # 147 and 936 samples), with the unrarefied counts (D48).
  rare <- strsplit(readLines(file.path(sdir, d, sprintf("%s_ASVs_table_rare.tsv", d)), n = 2)[2], "\t")[[1]][-1]
  m <- read_asvs(file.path(sdir, d, sprintf("%s_ASVs_table.tsv", d)), intersect(meta$sample[!is.na(meta[[s$column]]) & nzchar(meta[[s$column]])], rare))
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
# paper counts them: BH q < 0.05 over the method's finite p-values (Q4.csv); for
# LEfSe (D19) the features it reports (Q4_describe_only.csv). LEfSe always
# writes one row: with feature NA it means LEfSe flagged nothing or did not run
# (its note says which), so NA is never counted as a feature.
ve7b_engine_count <- function(id, ag, ds) {
  if (id == "D19") {
    if (is.null(ds)) return(NA_integer_)
    return(length(unique(stats::na.omit(ds$feature[ds$method_id == "D19"]))))
  }
  x <- ag[ag$method_id == id & is.finite(ag$p), , drop = FALSE]
  sum(stats::p.adjust(x$p, "BH") < 0.05)
}

# The engine's own tables, notes and report are copied out of the compendium
# before it is deleted, so a difference can be traced without a rerun.
VE7B_KEEP <- c("04_agreement/Q4.csv", "04_agreement/Q4_describe_only.csv", "03_results/Q4_differential/results.csv",
               "00_input_check/bundle_check.csv", "report/compendium_report.md", "provenance/engine.yaml")
ve7b_keep_engine_files <- function(out, keep_dir) {
  unlink(keep_dir, recursive = TRUE); dir.create(keep_dir, recursive = TRUE)
  have <- VE7B_KEEP[file.exists(file.path(out, VE7B_KEEP))]
  file.copy(file.path(out, have), file.path(keep_dir, gsub("/", "__", have)))
  invisible(gsub("/", "__", have))
}
