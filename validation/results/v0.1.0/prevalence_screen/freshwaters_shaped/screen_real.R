# Screen-only run on a Freshwaters-shaped bundle built the harness way (the all-samples filter OFF), with the table's other samples in the bundle as an
# unused level, so that the screen can see study samples that no comparison analyses. NO engine run, NO Q4, NO scoring. Data and full outputs stay in /work.
suppressPackageStartupMessages(library(seqcompendium))
ns <- asNamespace("seqcompendium"); f <- function(n) get(n, envir = ns)
W <- "/work/screen_real"; d <- "/work/nearing/Hackathon/Studies/ArcticFreshwaters"
dt <- data.table::fread(file.path(d, "ArcticFreshwaters_ASVs_table.tsv"), skip = 1, header = TRUE, sep = "\t", showProgress = FALSE)
feat <- dt[[1]]; all_s <- names(dt)[-1]
analysed <- strsplit(readLines(file.path(d, "ArcticFreshwaters_ASVs_table_rare.tsv"), n = 2)[2], "\t")[[1]][-1]
meta <- utils::read.delim(file.path(d, "ArcticFreshwaters_meta.tsv"), check.names = FALSE, comment.char = ""); names(meta)[1] <- "sample"
grp <- meta$Location[match(all_s, meta$sample)]
an <- all_s %in% analysed & !is.na(grp) & nzchar(grp)
cat("table samples", length(all_s), "; analysed (the harness's set)", sum(an), "\n")
nz <- integer(length(feat)); for (k in all_s[an]) nz <- nz + (dt[[k]] > 0)
rows <- nz >= 0.10 * sum(an)                                   # the harness's default filter (over the analysed samples): the all-samples filter is OFF
m <- vapply(all_s, function(k) as.numeric(dt[[k]][rows]), numeric(sum(rows))); rownames(m) <- feat[rows]; rm(dt); invisible(gc())
cat("features after the analysed-samples filter:", nrow(m), "\n")
b <- file.path(W, "bundle"); unlink(b, recursive = TRUE); dir.create(file.path(b, "metadata"), recursive = TRUE); dir.create(file.path(b, "layers"))
level <- ifelse(an, grp, "unused")
utils::write.table(data.frame(sample = all_s, group = level), file.path(b, "metadata/study_metadata.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
utils::write.csv(data.frame(column = "group", role = "predictor", type = "categorical", levels = paste(c(sort(unique(level[an])), "unused"), collapse = "|"), description = "Location; samples outside the analysed set are 'unused'"),
                 file.path(b, "metadata/column_guide.csv"), row.names = FALSE)
utils::write.table(data.frame(sample = rep(colnames(m), each = nrow(m)), feature = rep(rownames(m), ncol(m)), value = as.vector(m)), file.path(b, "layers/asv.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
utils::write.table(data.frame(feature = rownames(m), label = rownames(m)), file.path(b, "layers/asv_features.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
yaml::write_yaml(list(bundle_version = 1L, produced_by = list(pipeline = "prevalence screen demonstration (Nearing 2022 table)", dataset = "ArcticFreshwaters"),
                      metadata = list(table = "metadata/study_metadata.tsv", column_guide = "metadata/column_guide.csv"),
                      layers = list(list(name = "asv", file = "layers/asv.tsv", unit = "count", feature_level = "ASV", features = "layers/asv_features.tsv",
                                         feature_columns = list(label = "label"), source = list(tool = "Nearing 2022 figshare 14531724", version = "21_03_08")))),
                 file.path(b, "manifest.yaml"))
rm(m); invisible(gc())
# The engine's own steps up to the comparisons (as run_compendium does them), then the screen only.
x <- f("read_bundle")(b); gcd <- f("check_guide")(x$md, x$guide); lc <- f("check_layers")(x$layers, gcd$md); stopifnot(!length(c(gcd$stops, lc$stops)))
des <- f("read_design")(gcd$md, x$guide, gcd$info); cells <- f("design_cells")(des); units <- f("contrast_units")(lc$layers, des, cells)
des$long_reason <- f("long_ready")(des); long <- is.null(des$long_reason) && length(f("long_units")(lc$layers, des, cells)) > 0
cat("units:", paste(vapply(units, function(u) paste(u$contrast, if (u$testable) "testable" else "not testable"), ""), collapse = " | "), "; longitudinal:", long, "\n")
for (mode in c("report", "default")) {
  t0 <- proc.time()[["elapsed"]]; s <- f("prevalence_screen")(units, lc$layers, des, mode, long); cat(mode, "mode took", round(proc.time()[["elapsed"]] - t0), "s\n")
  utils::write.csv(s$rows, file.path(W, sprintf("rows_%s.csv", mode)), row.names = FALSE); utils::write.csv(s$decision, file.path(W, sprintf("decision_%s.csv", mode)), row.names = FALSE)
  if (!is.null(s$removed)) utils::write.csv(s$removed, file.path(W, sprintf("removed_%s.csv", mode)), row.names = FALSE) else cat(mode, ": nothing left out\n")
  print(s$decision[, c("contrast", "flagged_at_apply_cut", "analysed_share", "would_leave_out", "applied")], row.names = FALSE)
}
unlink(b, recursive = TRUE)
cat("DONE\n")
