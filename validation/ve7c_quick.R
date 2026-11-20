#!/usr/bin/env Rscript
# ve7c_quick.R: the engine side of V-E7(c) for a published reference (validation/PREREGISTRATION.md 9.4, 9.12): QUICK COUNTS, i.e. the engine's Q4
# methods (the default LinDA, the agreement set and LEfSe) run on a reference's feature table with the engine's own prevalence rule, WITHOUT the
# override check. It reads the feature table and the group labels ONLY. It never reads a reference's counts or results, and is run with the
# reference's own files not on disk (the freeze procedure, run plan section 4). Outputs (small tables):
#   <out>/ve7c_<kind>_<name>_counts.csv    one row per method: count of features at BH q < 0.05, features tested, failed, seconds, versions
#   <out>/ve7c_<kind>_<name>_features.csv  one row per method and feature: effect, p, q (LEfSe: lda_score as effect, no p, q)
#   <out>/ve7c_<kind>_<name>_meta.csv      the two group levels (effect = second level versus first, the engine's own convention), sample counts
# Rscript ve7c_quick.R <wallen|zhou> <name> <input file> <out dir>
#   wallen: name 1 or 2, input = that data set's phyloseq.rds (groups: case_control Case / Control)
#   zhou:   name CDI, IBD, RA or SMOKE, input = CDI_IBD_RA_SMOKE.rds (inputs only; groups: Disease, or Smoke for SMOKE)
# Optional 5th argument (zhou only), the G4 re-run of grounds-for-doubt G4 (9.2): reproduce Zhou's own pre-processing step (realdata/code_result/runfun.R,
# preprocess.fun), in the paper's order, before the engine's methods run:
#   g4   = samples with library < 1000 reads dropped; features nonzero in < 10% of the kept samples dropped; winsorising at quantile 0.97 (the paper's full step);
#          and the paper's own design columns carried as the engine's `batch` role (its way to adjust): IBD Antibiotic; SMOKE Sex (SMOKE's subject random effect is
#          NOT expressed: the engine's Q4 has no random effect, recorded in the meta file)
#   g4f  = the same two filters only (no winsorising, no covariate): the part of the step the coordinator named
# Without the 5th argument nothing changes: the original frozen run. Both are kept and reported.
args <- commandArgs(trailingOnly = TRUE); kind <- args[1]; name <- args[2]; inp <- args[3]; out <- args[4]
g4 <- if (length(args) >= 5) args[5] else ""; stopifnot(g4 %in% c("", "g4", "g4f"), g4 == "" || kind == "zhou")
stopifnot(kind %in% c("wallen", "zhou"))
suppressPackageStartupMessages(library(seqcompendium))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "R", "ve7b_bits.R"))
e <- asNamespace("seqcompendium"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
stamp <- function(...) cat(format(Sys.time(), "%F %H:%M:%S"), ..., "\n")

if (kind == "wallen") {
  suppressPackageStartupMessages(library(phyloseq))
  p <- readRDS(inp); m <- as(otu_table(p), "matrix"); if (!taxa_are_rows(p)) m <- t(m)
  g <- as.character(as.data.frame(sample_data(p))$case_control[match(colnames(m), sample_names(p))])
  stopifnot(!anyNA(g), all(g %in% c("Case", "Control")))
} else {
  d <- readRDS(inp); m <- as.matrix(d[[paste0(name, ".otu")]]); meta <- d[[paste0(name, ".meta")]]
  g <- as.character(meta[[if (name == "SMOKE") "Smoke" else "Disease"]][match(colnames(m), rownames(meta))])
  ok <- !is.na(g); m <- m[, ok, drop = FALSE]; g <- g[ok]
  covs <- NULL
  if (nzchar(g4)) {
    keep <- colSums(m) >= 1000; m <- m[, keep, drop = FALSE]; g <- g[keep]
    m <- m[rowSums(m > 0) / ncol(m) >= 0.1, , drop = FALSE]
    if (g4 == "g4") {
      P <- t(t(m) / colSums(m)); cut <- apply(P, 1, stats::quantile, 0.97); P <- pmin(P, cut)   # winsor.fun in runfun.R
      m <- round(t(t(P) * colSums(m)))
      cn <- c(IBD = "Antibiotic", SMOKE = "Sex")[name]
      if (!is.na(cn)) covs <- data.frame(factor(as.character(meta[[cn]][match(colnames(m), rownames(meta))])), row.names = colnames(m)); if (!is.null(covs)) names(covs) <- cn
    }
  }
}
stopifnot(identical(length(g), ncol(m)), length(unique(g)) == 2)
m <- m[rowSums(m) > 0, , drop = FALSE]      # only all-zero features are dropped here; the engine's own prevalence rule does the rest
tag <- sprintf("%s_%s%s", kind, name, if (nzchar(g4)) paste0("_", g4) else ""); sm <- paste0("s", seq_len(ncol(m))); colnames(m) <- sm
b <- file.path(tempfile(tag), "bundle"); dir.create(file.path(b, "metadata"), recursive = TRUE); dir.create(file.path(b, "layers"))
md <- data.frame(sample = sm, group = g)
if (exists("covs") && !is.null(covs)) { stopifnot(!anyNA(covs[[1]])); md[[names(covs)]] <- as.character(covs[[1]]) }
utils::write.table(md, file.path(b, "metadata/study_metadata.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
lv <- sort(unique(g))
utils::write.csv(data.frame(column = "group", role = "predictor", type = "categorical", levels = paste(lv, collapse = "|"), description = "group"), file.path(b, "metadata/column_guide.csv"), row.names = FALSE)
if (exists("covs") && !is.null(covs)) utils::write.table(rbind(utils::read.csv(file.path(b, "metadata/column_guide.csv")), data.frame(column = names(covs), role = "batch", type = "categorical", levels = paste(sort(unique(as.character(covs[[1]]))), collapse = "|"), description = "paper design covariate, carried as the engine's adjustment role")), file.path(b, "metadata/column_guide.csv"), sep = ",", row.names = FALSE, qmethod = "double")
utils::write.table(data.frame(sample = rep(colnames(m), each = nrow(m)), feature = rep(rownames(m), ncol(m)), value = as.vector(m)), file.path(b, "layers/asv.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
utils::write.table(data.frame(feature = rownames(m), label = rownames(m)), file.path(b, "layers/asv_features.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
yaml::write_yaml(list(bundle_version = 1L, produced_by = list(pipeline = "V-E7(c) quick counts", reference = tag),
                      metadata = list(table = "metadata/study_metadata.tsv", column_guide = "metadata/column_guide.csv"),
                      layers = list(list(name = "asv", file = "layers/asv.tsv", unit = "count", feature_level = "ASV", features = "layers/asv_features.tsv", feature_columns = list(label = "label"), source = list(tool = paste("V-E7(c) reference", tag), version = "1")))), file.path(b, "manifest.yaml"))
n_feat_in <- nrow(m); rm(m); invisible(gc())
bb <- e$read_bundle(b); gcheck <- e$check_guide(bb$md, bb$guide); lc <- e$check_layers(bb$layers, gcheck$md)
des <- e$read_design(gcheck$md, bb$guide, gcheck$info); cells <- e$design_cells(des)
units <- Filter(function(u) isTRUE(u$testable), e$contrast_units(lc$layers, des, cells)); stopifnot(length(units) == 1)
u <- units[[1]]; L <- lc$layers[[u$layer]]; ud <- e$unit_data(u, L, des); feats <- e$prevalent(ud$m, ud$g)
agr <- e$agreement_ids("Q4", L); ids <- unique(c("D09", agr, "D19"))
stamp(sprintf("%s: %d samples (%s), %d features in, %d prevalent; ids: %s", tag, nrow(ud$m), paste(sprintf("%s %d", levels(ud$g), tabulate(ud$g)), collapse = ", "), n_feat_in, length(feats), paste(ids, collapse = " ")))
order_ids <- c(setdiff(ids, c("D04", "D06", "D09")), "D04", "D06", "D09"); order_ids <- order_ids[order_ids %in% ids]
cnt <- list(); ft <- list()
for (id in order_ids) {
  t0 <- proc.time()[["elapsed"]]; ag <- ds <- NULL
  if (id == "D19") ds <- cbind(method_id = "D19", e$describe_lefse(ud, feats)) else ag <- e$q4_agreement(ud, feats, id)
  n <- ve7b_engine_count(id, ag, ds); why <- ve7b_engine_failure(id, ag, ds)
  cnt[[id]] <- data.frame(reference = tag, method_id = id, count = n, features_tested = length(feats), samples = nrow(ud$m), failed = nzchar(why), note = why, seconds = round(proc.time()[["elapsed"]] - t0))
  ft[[id]] <- if (id == "D19") data.frame(reference = tag, method_id = id, feature = ds$feature, effect = ds$lda_score, p = NA_real_, q = NA_real_)
              else data.frame(reference = tag, method_id = id, feature = ag$feature, effect = ag$effect, p = ag$p, q = ag$q)
  stamp(sprintf("%s: %s (%d s)%s", id, n, cnt[[id]]$seconds, if (nzchar(why)) paste(" FAILED:", why) else "")); invisible(gc())
}
vers <- sapply(c("ALDEx2", "lefser", "ANCOMBC", "MicrobiomeStat", "seqcompendium"), function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(x) NA_character_))
cn <- do.call(rbind, cnt); cn$versions <- paste(names(vers), vers, collapse = "; ")
utils::write.csv(cn, file.path(out, sprintf("ve7c_%s_counts.csv", tag)), row.names = FALSE)
utils::write.csv(do.call(rbind, ft), file.path(out, sprintf("ve7c_%s_features.csv", tag)), row.names = FALSE)
utils::write.csv(data.frame(reference = tag, level1 = levels(ud$g)[1], level2 = levels(ud$g)[2], n1 = tabulate(ud$g)[1], n2 = tabulate(ud$g)[2], features_in = n_feat_in, features_prevalent = length(feats), note = paste0("engine effect = level2 versus level1", if (nzchar(g4)) paste0("; G4 mode ", g4, "; adjusted_for: ", ud$adjusted_for, if (g4 == "g4" && name == "SMOKE") "; subject random effect NOT expressed" else "") else "")), file.path(out, sprintf("ve7c_%s_meta.csv", tag)), row.names = FALSE)
stamp("done", tag)
