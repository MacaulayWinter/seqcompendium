#!/usr/bin/env Rscript
# T_count measurement (PREREGISTRATION section 9.5): repeat the engine's Q4 methods on Wallen 2021's two feature tables with
# different seeds. Reads ONLY the feature tables; the paper's counts are never read. The seed is changed by shifting the engine's
# seed_for() (rep 0 = the engine's own seeds), a harness change, not an engine change.
# Rscript wallen_tcount.R <dataset 1|2> <reps> <out dir>
args <- commandArgs(trailingOnly = TRUE); dn <- as.integer(args[1]); reps <- as.integer(args[2]); out <- args[3]
suppressPackageStartupMessages({library(seqcompendium); library(phyloseq)})
source("/src/validation/R/ve7b_bits.R")
e <- asNamespace("seqcompendium"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
stamp <- function(...) cat(format(Sys.time(), "%F %H:%M:%S"), ..., "\n")
p <- readRDS(sprintf("/work/wallen_tables/dataset%d/phyloseq.rds", dn))
m <- as(otu_table(p), "matrix"); if (!taxa_are_rows(p)) m <- t(m)
meta <- data.frame(sample = sample_names(p), group = as.character(as.data.frame(sample_data(p))$case_control))
meta <- meta[match(colnames(m), meta$sample), ]; stopifnot(!anyNA(meta$group), all(meta$group %in% c("Case", "Control")))
keep <- rowSums(m > 0) >= 0.05 * ncol(m)   # a superset of the engine's own 10%-in-one-group rule, to keep the bundle small
m <- m[keep, , drop = FALSE]
stamp(sprintf("dataset %d: %d samples (%s), %d features kept for the bundle (of %d)", dn, ncol(m), paste(sprintf("%s %d", names(table(meta$group)), table(meta$group)), collapse = ", "), nrow(m), length(keep)))
b <- file.path(tempfile(sprintf("wallen%d", dn)), "bundle"); dir.create(file.path(b, "metadata"), recursive = TRUE); dir.create(file.path(b, "layers"))
utils::write.table(meta, file.path(b, "metadata/study_metadata.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
utils::write.csv(data.frame(column = "group", role = "predictor", type = "categorical", levels = "Case|Control", description = "case_control"), file.path(b, "metadata/column_guide.csv"), row.names = FALSE)
utils::write.table(data.frame(sample = rep(colnames(m), each = nrow(m)), feature = rep(rownames(m), ncol(m)), value = as.vector(m)), file.path(b, "layers/asv.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
utils::write.table(data.frame(feature = rownames(m), label = rownames(m)), file.path(b, "layers/asv_features.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
yaml::write_yaml(list(bundle_version = 1L, produced_by = list(pipeline = "T_count measurement: Wallen 2021 feature tables", dataset = dn),
                      metadata = list(table = "metadata/study_metadata.tsv", column_guide = "metadata/column_guide.csv"),
                      layers = list(list(name = "asv", file = "layers/asv.tsv", unit = "count", feature_level = "ASV", features = "layers/asv_features.tsv", feature_columns = list(label = "label"), source = list(tool = "Wallen 2021 phyloseq", version = "1")))), file.path(b, "manifest.yaml"))
rm(m); invisible(gc())
bb <- e$read_bundle(b); gcheck <- e$check_guide(bb$md, bb$guide); lc <- e$check_layers(bb$layers, gcheck$md)
des <- e$read_design(gcheck$md, bb$guide, gcheck$info); cells <- e$design_cells(des)
units <- Filter(function(u) isTRUE(u$testable), e$contrast_units(lc$layers, des, cells)); stopifnot(length(units) == 1)
u <- units[[1]]; L <- lc$layers[[u$layer]]; ud <- e$unit_data(u, L, des); feats <- e$prevalent(ud$m, ud$g)
agr <- e$agreement_ids("Q4", L); ids <- unique(c(agr, "D04", "D19"))
stamp(sprintf("%d samples, %d prevalent features; ids: %s", nrow(ud$m), length(feats), paste(ids, collapse = " ")))
orig <- get("seed_for", e); shift <- new.env(); shift$v <- 0L
unlockBinding("seed_for", e); assign("seed_for", function(offset) orig(offset) + shift$v, envir = e)
f <- file.path(out, sprintf("tcount_dataset%d.csv", dn)); if (file.exists(f)) file.remove(f)
for (r in 0:reps) {            # rep 0 = the engine's own seeds
  shift$v <- 100000L * r
  for (id in c(setdiff(ids, c("D04", "D06", "D09")), "D04", "D06", "D09")[c(setdiff(ids, c("D04", "D06", "D09")), "D04", "D06", "D09") %in% ids]) {
    t0 <- proc.time()[["elapsed"]]; ag <- ds <- NULL
    if (id == "D19") ds <- cbind(method_id = "D19", e$describe_lefse(ud, feats)) else ag <- e$q4_agreement(ud, feats, id)
    n <- ve7b_engine_count(id, ag, ds); why <- ve7b_engine_failure(id, ag, ds)
    row <- data.frame(dataset = dn, rep = r, seed_shift = shift$v, method_id = id, samples = nrow(ud$m), features = length(feats), count = n, failed = nzchar(why), note = why, seconds = round(proc.time()[["elapsed"]] - t0))
    utils::write.table(row, f, sep = ",", row.names = FALSE, col.names = !file.exists(f), append = file.exists(f), qmethod = "double")
    stamp(sprintf("rep %d %s: %s (%d s)%s", r, id, n, row$seconds, if (nzchar(why)) paste(" FAILED:", why) else "")); invisible(gc())
  }
}
stamp("done dataset", dn, "; ALDEx2", as.character(utils::packageVersion("ALDEx2")), "; lefser", as.character(utils::packageVersion("lefser")), "; ANCOMBC", as.character(utils::packageVersion("ANCOMBC")))
