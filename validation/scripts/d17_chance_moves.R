#!/usr/bin/env Rscript
# D17's pass mark (E4-M8; CLAUDE.md D17, D19): how often a whole comparison
# moves down the fallback ladder on clean data, where nothing is wrong.
# Grid: 3 feature counts x 2 group sizes x 2 defaults = 12 cells, numbered 1-12
# in that order; 200 comparisons per cell. Pass: share moved <= 0.081 in every
# cell. Seeds: 20261029 + 1000 x cell + comparison.
# Usage: d17_chance_moves.R <cell 1-12> <out.csv> [comparisons, default 200] [seed offset, default 0]
# (seed offset 500000 = the fresh-data confirmation of PREREGISTRATION.md section 8)
args <- commandArgs(trailingOnly = TRUE)
cell <- as.integer(args[1]); out <- args[2]; n_comp <- if (length(args) >= 3) as.integer(args[3]) else 200L
offset <- if (length(args) >= 4) as.integer(args[4]) else 0L
grid <- expand.grid(n_features = c(30, 100, 300), n_per_group = c(6, 10), default = c("D01", "D09"), stringsAsFactors = FALSE)
g <- grid[cell, ]
suppressPackageStartupMessages(library(seqcompendium))
ns <- asNamespace("seqcompendium")
one <- function(k) {
  set.seed(20261029L + offset + 1000L * cell + k)
  n <- 2 * g$n_per_group; p <- g$n_features
  mu <- exp(stats::rnorm(p, 3, 1.2)); size <- stats::rgamma(p, 4, 2); depth <- stats::runif(n, 0.5, 2)
  # Clean data: negative binomial counts, the model the DESeq2 default assumes.
  m <- t(vapply(seq_len(n), function(j) stats::rnbinom(p, mu = mu * depth[j], size = size), numeric(p)))
  dimnames(m) <- list(sprintf("s%02d", seq_len(n)), sprintf("f%03d", seq_len(p)))
  grp <- factor(rep(c("a", "b"), each = g$n_per_group))
  ud <- list(m = m, g = grp, den = if (g$default == "D01") rowSums(m) else NULL, lib = rowSums(m), samples = rownames(m))
  feats <- ns$prevalent(m, grp)
  chk <- do.call(rbind, lapply(seq_along(feats), function(i) if (g$default == "D01") ns$check_nb(ud, feats[i], i) else ns$check_lm_clr(ud, feats[i])))
  chance <- ns$chance_failure_rate(ud, feats, g$default == "D01")
  pv <- stats::binom.test(sum(chk$failed), length(feats), chance, alternative = "greater")$p.value
  data.frame(cell = cell, comparison = k, n_features = length(feats), n_per_group = g$n_per_group, default = g$default,
             failed = sum(chk$failed), chance_rate = chance, excess_p = pv, moved = pv < ns$rule("R-EXCESS"))
}
res <- do.call(rbind, lapply(seq_len(n_comp), one))
utils::write.csv(res, out, row.names = FALSE)
share <- mean(res$moved)
cat(sprintf("cell %d (%d features, %d per group, %s): moved %d of %d = %.3f; pass mark <= 0.081: %s\n",
            cell, g$n_features, g$n_per_group, g$default, sum(res$moved), n_comp, share, if (share <= 0.081) "PASS" else "FAIL"))
