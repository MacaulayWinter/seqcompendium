#!/usr/bin/env Rscript
# ve7c_run_score.R: the scoring side of V-E7(c). Run ONCE, after the engine's tables were frozen and pushed (results/v0.1.0/ve7c/{wallen,zhou}/ and
# SCORING_MAPPING.md). It is the only code that reads a reference's counts or results. It applies validation/R/ve7c_score.R (9.5, 9.7) with the
# mapping fixed in SCORING_MAPPING.md. Writes small tables.
#   Rscript ve7c_run_score.R <engine dir (…/ve7c)> <reference files dir> <out dir>
args <- commandArgs(trailingOnly = TRUE); eng <- args[1]; ref <- args[2]; out <- args[3]; dir.create(out, recursive = TRUE, showWarnings = FALSE)
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
# ---- Wallen 2021 ----
W <- list(D04 = list(f = "ALDEx2_10pct.txt", q = "we.eBH", eff = function(d) d$diff.btw), D06 = list(f = "ANCOM-BC_10pct.txt", q = "FDR_BH", eff = function(d) d$Beta),
          D17 = list(f = "KW_CLR_10pct.txt", q = "FDR_BH", eff = function(d) d$Case_Mean_CLR - d$Control_Mean_CLR), D19 = list(f = "LEfSe_10pct.txt", q = "FDR_BH", eff = function(d) rep(NA_real_, nrow(d))))
for (n in 1:2) {
  ct <- utils::read.csv(file.path(eng, "wallen", sprintf("ve7c_wallen_%d_counts.csv", n))); ft <- utils::read.csv(file.path(eng, "wallen", sprintf("ve7c_wallen_%d_features.csv", n)))
  for (id in names(W)) {
    d <- rdr(file.path(ref, "wallen", sprintf("Dataset%d_Output", n), W[[id]]$f)); q <- d[[W[[id]]$q]]
    rf <- data.frame(feature = d$Representative_ASV, effect = W[[id]]$eff(d), q = q, stringsAsFactors = FALSE)
    rows[[length(rows) + 1]] <- judge("Wallen 2021", paste("dataset", n), id, sum(q < 0.05, na.rm = TRUE), ct, ft, rf, note = if (id == "D06") "reference ran ANCOM-BC 1.0.5; version-only difference is reported, not passed (9.4 a)" else "")
  }
}
# ---- Zhou 2022 (counts only: pval.mat.list.rds has p-values, no effects) ----
zl <- readRDS(list.files(ref, "pval.mat.list.rds", recursive = TRUE, full.names = TRUE)[1]); ZC <- c(D09 = "LinDA", D06 = "ANCOM-BC", D04 = "ALDEx2", D17 = "Wilcoxon")
for (nm in c("CDI", "IBD", "RA", "SMOKE")) {
  ct <- utils::read.csv(file.path(eng, "zhou", sprintf("ve7c_zhou_%s_counts.csv", nm))); ft <- utils::read.csv(file.path(eng, "zhou", sprintf("ve7c_zhou_%s_features.csv", nm)))
  engf <- unique(ft$feature); ov <- sapply(zl, function(m) length(intersect(rownames(m), engf)) / max(nrow(m), 1)); k <- which.max(ov)
  lines[[nm]] <- sprintf("%s: matrix %d (%d rows; %.0f%% of its rows are in the engine's feature table; others %s)", nm, k, nrow(zl[[k]]), 100 * ov[k], paste(sprintf("%.0f%%", 100 * ov[-k]), collapse = ", "))
  m <- zl[[k]]
  for (id in names(ZC)) rows[[length(rows) + 1]] <- judge("Zhou 2022", nm, id, sum(bh(m[, ZC[[id]]]) < 0.05, na.rm = TRUE), ct, ft, NULL, note = if (id == "D09") "LinDA's authors' own reference: own line, not counted" else "")
}
res <- do.call(rbind, rows); utils::write.csv(res, file.path(out, "ve7c_method_lines.csv"), row.names = FALSE); writeLines(unlist(lines), file.path(out, "ve7c_zhou_matrix_match.txt"))
cong <- function(rn) { x <- res[res$reference == rn, ]; ve7c_reference_congruent(data.frame(method_id = x$method_id, ok = x$ok), linda_authors = rn == "Zhou 2022") }
refs <- data.frame(reference = c("planted truth", "Wallen 2021", "Zhou 2022"), congruent = c(NA, cong("Wallen 2021"), cong("Zhou 2022")), published = c(FALSE, TRUE, TRUE), author_free = c(FALSE, TRUE, FALSE))
utils::write.csv(refs, file.path(out, "ve7c_references.csv"), row.names = FALSE); writeLines(ve7c_outcome(refs), file.path(out, "ve7c_outcome.txt"))
print(res[, c("reference", "dataset", "method_id", "engine_count", "reference_count", "allowance", "count_ok", "sign_agreement", "rule2", "spearman", "rule3", "ok")], row.names = FALSE)
print(refs); cat(ve7c_outcome(refs), "\n"); cat(unlist(lines), sep = "\n")
