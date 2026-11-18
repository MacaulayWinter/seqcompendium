#!/usr/bin/env Rscript
# ve6_diagnostics.R: V-E6, the residual checks (validation/PREREGISTRATION.md §5;
# CLAUDE.md D37). Per model family, datasets with a planted violation and
# clean datasets from the model's own family; each dataset is one feature or
# one test, 10 per group (15 and 5 where groups must be unbalanced).
#
#   Rscript validation/ve6_diagnostics.R <family> <first> <last> <results dir>
#   family: nb, lm_hill, permanova, logistic
#
# Violations (the pre-registration's list, in its order):
#   nb        dispersion beyond the model: one group's dispersion 20 times the
#             other's (size 0.5 vs 10), which a common-dispersion NB cannot fit
#   lm_hill   50% structural zeros in the Hill numbers
#   permanova unequal group spread (log-scale noise sd 1.5 vs 0.3), groups 15 and 5
#   logistic  separation: one group all present
# Flagged = the engine's own check fails: DHARMa on the NB refit (check_nb);
# residual skewness above R-SKEW (Q2's check); betadisper p below R-DIAGP;
# separation detected (the switch to Firth).
args <- commandArgs(trailingOnly = TRUE)
fam <- args[1]; first <- as.integer(args[2]); last <- as.integer(args[3]); rdir <- args[4]
suppressPackageStartupMessages(library(seqcompendium)); e <- asNamespace("seqcompendium")
SEED0 <- c(nb = 1, lm_hill = 2, permanova = 3, logistic = 4)[[fam]]
one <- function(kind, k) {
  set.seed(20261029L + 900000L + 100000L * SEED0 + 1000L * (kind == "violated") + k)
  switch(fam,
    nb = {
      g <- factor(rep(c("A", "B"), each = 10)); size <- if (kind == "violated") rep(c(0.5, 10), each = 10) else 2
      y <- stats::rnbinom(20, mu = 50, size = size); m <- matrix(y, ncol = 1, dimnames = list(sprintf("s%02d", 1:20), "f"))
      ck <- e$check_nb(list(m = m, g = g, den = NULL, lib = rep(1e4, 20), cov = NULL), "f", k); ck$failed },
    lm_hill = {
      h <- stats::rnorm(20, 20, 4); if (kind == "violated") h[sample(20, 10)] <- 0
      a <- h[1:10]; b <- h[11:20]; r <- c(a - mean(a), b - mean(b))
      sk <- if (stats::sd(r) > 0) mean(r^3) / stats::sd(r)^3 else NA
      is.finite(sk) && abs(sk) > e$rule("R-SKEW") },
    permanova = {
      n <- c(15, 5); g <- factor(rep(c("A", "B"), n)); p <- 30; base <- stats::rnorm(p, 4, 1)
      sd <- if (kind == "violated") rep(c(0.3, 1.5), n) else rep(0.6, sum(n))
      mu <- exp(outer(rep(1, sum(n)), base) + matrix(stats::rnorm(sum(n) * p), sum(n)) * sd)
      m <- matrix(stats::rpois(length(mu), mu), sum(n))
      d <- vegan::vegdist(m[, colSums(m) > 0], method = "robust.aitchison"); bd <- vegan::betadisper(d, g)
      set.seed(e$seed_for(32)); vegan::permutest(bd, permutations = e$rule("R-PERM"))$tab[1, "Pr(>F)"] < e$rule("R-DIAGP") },
    logistic = {
      g <- factor(rep(c("A", "B"), each = 10))
      y <- if (kind == "violated") c(stats::rbinom(10, 1, 0.4), rep(1L, 10)) else stats::rbinom(20, 1, 0.5)
      any(tapply(y, g, function(z) all(z == 0) || all(z == 1))) })
}
rows <- do.call(rbind, lapply(c("violated", "clean"), function(kind) do.call(rbind, lapply(first:last, function(k)
  data.frame(family = fam, kind = kind, k = k, flagged = as.numeric(tryCatch(isTRUE(one(kind, k)), error = function(err) NA)))))))
dir.create(file.path(rdir, "rows"), recursive = TRUE, showWarnings = FALSE)
f <- file.path(rdir, "rows", sprintf("ve6_%s_%03d-%03d.csv", fam, first, last)); utils::write.csv(rows, f, row.names = FALSE); cat("wrote", f, "\n")
