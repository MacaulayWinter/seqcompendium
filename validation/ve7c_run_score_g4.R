#!/usr/bin/env Rscript
# ve7c_run_score_g4.R: scores the G4 re-run on Zhou 2022 (results/v0.1.0/ve7c/zhou_g4/G4_PLAN.md) with EXACTLY the rules and the judge() of ve7c_run_score.R
# (9.5 allowances, SCORING_MAPPING.md column map); only the engine tables differ (the g4f and g4 modes of ve7c_quick.R). Run once, after those tables were frozen.
#   Rscript ve7c_run_score_g4.R <g4 engine dir> <reference files dir> <out dir> <g4f|g4>
args <- commandArgs(trailingOnly = TRUE); eng <- args[1]; ref <- args[2]; out <- args[3]; mode <- args[4]; stopifnot(mode %in% c("g4f", "g4")); dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "R", "ve7c_score.R"))
bh <- function(p) { ok <- is.finite(p); q <- rep(NA_real_, length(p)); q[ok] <- p.adjust(p[ok], "BH"); q }
rdr <- function(f) utils::read.delim(f, check.names = FALSE, stringsAsFactors = FALSE, quote = "")
rows <- list(); lines <- list()
# Orientation of a reference's effect sign (engine: second level versus first): fixed from ALL common features, never from the significant ones.
orient <- function(e, r) { u <- intersect(e$feature[is.finite(e$effect)], r$feature[is.finite(r$effect)]); if (length(u) < 3) return(NA)
  stats::cor(e$effect[match(u, e$feature)], r$effect[match(u, r$feature)], method = "spearman") < 0 }
judge <- function(refname, ds, id, refcount, eng_ct, eng_ft, ref_ft, note = "") {
  ec <- eng_ct$count[eng_ct$method_id == id]; ok1 <- ve7c_count_ok(id, refcount, ec)
  e <- eng_ft[eng_ft$method_id == id & !is.na(eng_ft$feature), c("feature", "effect", "q")]
  r2 <- r3 <- NA; flip <- NA
  if (!is.null(ref_ft) && id != "D19") { flip <- orient(e, ref_ft); if (isTRUE(flip) || identical(flip, FALSE)) { r2 <- ve7c_rule2(e, ref_ft, flip = flip); rr <- ref_ft; if (flip) rr$effect <- -rr$effect; r3 <- ve7c_rule3(e, rr) } }
  data.frame(reference = refname, dataset = ds, method_id = id, engine_count = ec, reference_count = refcount, allowance = ve7c_allowance(id, refcount), count_ok = ok1,
             sign_agreement = if (!is.null(ref_ft) && id != "D19") ve7c_sign_agreement(e, ref_ft, isTRUE(flip)) else NA, rule2 = r2,
             spearman = if (!is.null(ref_ft) && id != "D19") ve7c_spearman(e, transform(ref_ft, effect = if (isTRUE(flip)) -effect else effect)) else NA, rule3 = r3, flipped = flip,
             ok = ve7c_method_ok(ok1, r2, r3), note = note, stringsAsFactors = FALSE)
}
rows <- list(); lines <- list()
zl <- readRDS(list.files(ref, "pval.mat.list.rds", recursive = TRUE, full.names = TRUE)[1]); ZC <- c(D09 = "LinDA", D06 = "ANCOM-BC", D04 = "ALDEx2", D17 = "Wilcoxon")
for (nm in c("CDI", "IBD", "RA", "SMOKE")) {
  ct <- utils::read.csv(file.path(eng, sprintf("ve7c_zhou_%s_%s_counts.csv", nm, mode))); ft <- utils::read.csv(file.path(eng, sprintf("ve7c_zhou_%s_%s_features.csv", nm, mode)))
  engf <- unique(ft$feature); ov <- sapply(zl, function(m) length(intersect(rownames(m), engf)) / max(nrow(m), 1)); k <- which.max(ov)
  lines[[nm]] <- sprintf("%s: matrix %d (%d rows; %.0f%% of its rows are in the engine's feature table; others %s)", nm, k, nrow(zl[[k]]), 100 * ov[k], paste(sprintf("%.0f%%", 100 * ov[-k]), collapse = ", "))
  m <- zl[[k]]; zc <- if (nm == "SMOKE") c(D09 = "LinDA-LMM(Both)") else ZC
  for (id in names(zc)) rows[[length(rows) + 1]] <- judge(paste("Zhou 2022", mode), nm, id, sum(bh(m[, zc[[id]]]) < 0.05, na.rm = TRUE), ct, ft, NULL, note = if (id == "D09") "LinDA's authors' own reference: own line, not counted" else "")
}
res <- do.call(rbind, rows); utils::write.csv(res, file.path(out, sprintf("ve7c_zhou_%s_method_lines.csv", mode)), row.names = FALSE); writeLines(unlist(lines), file.path(out, sprintf("ve7c_zhou_%s_matrix_match.txt", mode)))
cong <- ve7c_reference_congruent(data.frame(method_id = res$method_id, ok = res$ok), linda_authors = TRUE)
print(res[, c("dataset", "method_id", "engine_count", "reference_count", "allowance", "count_ok", "ok")], row.names = FALSE); cat("Zhou", mode, "congruent (LinDA excluded, 9.5):", cong, "\n"); cat(unlist(lines), sep = "\n")
