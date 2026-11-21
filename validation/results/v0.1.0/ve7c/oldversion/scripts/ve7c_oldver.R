# Section 11 diagnostic: the quick counts of validation/ve7c_quick.R with ONE method swapped for the paper's older version (separate library).
# Rscript ve7c_oldver.R <aldex|ancombc> <1|2> <phyloseq.rds> <out dir>   (run with the engine on R_LIBS; old libraries are put first on the search path here)
a <- commandArgs(trailingOnly = TRUE); mode <- a[1]
if (mode == "aldex")   .libPaths(c("/work/oldlibs/ALDEx2_1.22.0", .libPaths()))
if (mode == "ancombc") .libPaths(c("/work/oldlibs/ANCOMBC_1.0.5", .libPaths()))
suppressPackageStartupMessages(library(seqcompendium)); ns <- asNamespace("seqcompendium")
if (mode == "ancombc") {
  stopifnot(as.character(packageVersion("ANCOMBC")) == "1.0.5")
  old_ancombc <- function(ud, feats) {   # ANCOM-BC 1.0.5's ancombc(); settings mirror the engine's D06 call (no prevalence/library cut, BH, alpha 0.05); the paper's own call was not read
    set.seed(seqcompendium:::seed_for(42))
    ps <- phyloseq::phyloseq(phyloseq::otu_table(t(ud$m[, feats, drop = FALSE]), taxa_are_rows = TRUE), phyloseq::sample_data(data.frame(g = ud$g, row.names = ud$samples)))
    o <- suppressMessages(suppressWarnings(ANCOMBC::ancombc(phyloseq = ps, formula = "g", p_adj_method = "BH", zero_cut = 1, lib_cut = 0, group = "g", struc_zero = FALSE,
                                                              neg_lb = FALSE, tol = 1e-5, max_iter = 100, conserve = FALSE, alpha = 0.05, global = FALSE)))
    r <- o$res; data.frame(feature = rownames(r$beta), effect = r$beta[, 1] / log(2), se = r$se[, 1] / log(2), stat = r$W[, 1], p = r$p_val[, 1], effect_unit = "log2 fold change (ANCOM-BC 1.0.5)")
  }
  unlockBinding("FITS", ns); ns$FITS$D06 <- old_ancombc; lockBinding("FITS", ns)
}
if (mode == "aldex") stopifnot(as.character(packageVersion("ALDEx2")) == "1.22.0")
# hand over to the unchanged quick-count script (its `vers` line records the versions actually used)
commandArgs <- function(trailingOnly = FALSE) if (trailingOnly) c("wallen", a[2], a[3], a[4]) else c("--file=/src/validation/ve7c_quick.R")
source("/src/validation/ve7c_quick.R", chdir = FALSE, local = FALSE)
