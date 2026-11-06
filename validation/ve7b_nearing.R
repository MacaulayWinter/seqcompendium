#!/usr/bin/env Rscript
# ve7b_nearing.R: V-E7 (b), the engine against Nearing et al. 2022
# (doi:10.1038/s41467-022-28034-z) on its first two public datasets in C-locale
# order, ArcticFireSoils ("Soil - Fires") and ArcticFreshwaters ("Freshwater -
# Arctic"); validation/PREREGISTRATION.md §5, CLAUDE.md D41, D42.
#
#   Rscript validation/ve7b_nearing.R <Hackathon/Studies folder> <source_data_all.xlsx> <results dir>
#
# The data are downloaded by the user's machine (figshare 14531724; the paper's
# Source Data), never committed. For every method the engine shares with the
# paper (ALDEx2, Wilcoxon on CLR, LEfSe), the number of significant features
# is compared with the paper's filtered table (Figure 1B: features in fewer
# than 10% of samples removed), counted as the paper counts them: BH q < 0.05
# (LEfSe: the features it reports). Equal passes; a difference is reported with
# the settings and package versions that differ.
args <- commandArgs(trailingOnly = TRUE); sdir <- args[1]; xlsx <- args[2]; rdir <- args[3]
suppressPackageStartupMessages(library(seqcompendium))
dir.create(rdir, recursive = TRUE, showWarnings = FALSE)
SETS <- list(ArcticFireSoils = list(label = "Soil - Fires", column = "Fire"),
             ArcticFreshwaters = list(label = "Freshwater - Arctic", column = "Location"))
METHODS <- c(D04 = "ALDEx2", D17 = "Wilcoxon (CLR)", D19 = "LEfSe")
paper <- as.data.frame(readxl::read_excel(xlsx, sheet = "Figure1B_counts (filt)")); names(paper)[1] <- "method"
rows <- list()
for (d in names(SETS)) {
  s <- SETS[[d]]; w <- tempfile(d); b <- file.path(w, "bundle")
  dir.create(file.path(b, "metadata"), recursive = TRUE); dir.create(file.path(b, "layers"))
  asv <- utils::read.delim(file.path(sdir, d, sprintf("%s_ASVs_table.tsv", d)), check.names = FALSE, skip = 1, comment.char = "")
  names(asv)[1] <- "feature"
  meta <- utils::read.delim(file.path(sdir, d, sprintf("%s_meta.tsv", d)), check.names = FALSE, comment.char = "")
  names(meta)[1] <- "sample"
  keep <- intersect(meta$sample[!is.na(meta[[s$column]]) & nzchar(meta[[s$column]])], names(asv)[-1])
  m <- as.matrix(asv[, keep]); rownames(m) <- asv$feature
  m <- m[rowMeans(m > 0) >= 0.10, , drop = FALSE]          # the paper's filter: present in >= 10% of samples
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
  o <- file.path(w, "out"); t0 <- proc.time()[["elapsed"]]
  err <- tryCatch({ suppressMessages(suppressWarnings(run_compendium(b, o))); NA_character_ }, error = function(e) conditionMessage(e))
  secs <- proc.time()[["elapsed"]] - t0
  ag <- if (is.na(err)) utils::read.csv(file.path(o, "04_agreement", "Q4.csv")) else NULL
  ds <- if (is.na(err) && file.exists(file.path(o, "04_agreement", "Q4_describe_only.csv"))) utils::read.csv(file.path(o, "04_agreement", "Q4_describe_only.csv")) else NULL
  for (id in names(METHODS)) {
    n_engine <- if (!is.na(err)) NA else if (id == "D19") { if (is.null(ds)) NA else length(unique(ds$feature[ds$method_id == "D19"])) }
                else { x <- ag[ag$method_id == id & is.finite(ag$p), ]; sum(stats::p.adjust(x$p, "BH") < 0.05) }
    n_paper <- paper[[s$label]][paper$method == METHODS[[id]]]
    rows[[length(rows) + 1]] <- data.frame(dataset = d, paper_label = s$label, method = METHODS[[id]], samples = ncol(m), features = nrow(m),
                                           engine = n_engine, paper = n_paper, equal = isTRUE(n_engine == n_paper), seconds = round(secs), error = err)
  }
  unlink(w, recursive = TRUE)
}
res <- do.call(rbind, rows)
res$differences <- "paper: R 4.0-era package versions, its own pre-processing scripts; engine: Bioconductor 3.23 versions, ALDEx2 and CLR as the engine runs them (pseudocount R-PSEUDO = 0.5), both groups' samples only"
utils::write.csv(res, file.path(rdir, "ve7b_nearing.csv"), row.names = FALSE)
utils::write.csv(data.frame(mark = "V-E7", scenario = sprintf("(b) Nearing 2022, %s: %d of %d method counts equal the paper's", paste(names(SETS), collapse = " and "), sum(res$equal), nrow(res)),
                            number = mean(res$equal), threshold = "every count equal (published counts are whole numbers)", pass = all(res$equal), runs = nrow(res)),
                 file.path(rdir, "ve7b_marks.csv"), row.names = FALSE)
print(res[, c("dataset", "method", "samples", "features", "engine", "paper", "equal", "seconds", "error")], row.names = FALSE)
