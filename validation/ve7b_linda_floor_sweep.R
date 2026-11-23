#!/usr/bin/env Rscript
# Toy sweep for the LinDA read floor R-LINDAFLOOR (CLAUDE.md D67). Simulated tables with a KNOWN answer only; no real data, and the floor is
# chosen from this sweep and from reasoning before any real rerun, never from a real result.
#   Rscript validation/ve7b_linda_floor_sweep.R <out csv>
# For each design and seed: LinDA (MicrobiomeStat 1.4, as the engine calls it) is run after leaving out the samples with fewer than `floor`
# reads, for floors 0 (nothing left out: the engine's behaviour today), 20, 50, 100, 150, 200 and 500. Reported: whether LinDA fitted, how many
# samples were left out, true and false positives at BH q < 0.05 against the planted truth.
suppressPackageStartupMessages(library(seqcompendium))
fit_once <- seqcompendium:::fit_linda_once
out <- commandArgs(TRUE)[1]
`%||%` <- function(a, b) if (is.null(a)) b else a
designs <- list(
  small_sparse   = list(n = 30,  p = 150, depth_sd = 1.0, tiny = 0.05, planted = 15),
  medium_sparse  = list(n = 100, p = 300, depth_sd = 1.2, tiny = 0.05, planted = 30),
  large_deep_tail = list(n = 300, p = 300, depth_sd = 1.2, tiny = 0.03, planted = 30),
  shallow_library = list(n = 60,  p = 200, depth_sd = 0.8, tiny = 0.0,  planted = 20, scale = 0.05)   # most samples have few hundred reads: does a floor throw away real data?
)
rows <- list()
for (dn in names(designs)) { d <- designs[[dn]]
  for (seed in 1:20) {
    set.seed(1000 * match(dn, names(designs)) + seed)
    n <- d$n; p <- d$p; g <- factor(rep(c("A", "B"), each = n)); mu <- exp(rnorm(p, 0.8, 1.5)) * (d$scale %||% 1)
    truth <- seq_len(p) <= d$planted; lfc <- ifelse(truth, sample(c(-1.5, 1.5), p, TRUE), 0)
    depth <- rlnorm(2 * n, 0, d$depth_sd); k <- sample(2 * n, round(d$tiny * 2 * n)); depth[k] <- depth[k] * 10^runif(length(k), -3.5, -1.5)   # a few almost-empty samples
    m <- sapply(seq_len(p), function(j) rnbinom(2 * n, mu = mu[j] * depth * ifelse(g == "B", 2^lfc[j], 1), size = 0.5))
    colnames(m) <- paste0("f", seq_len(p)); rownames(m) <- paste0("s", seq_len(2 * n)); tot <- rowSums(m)
    for (fl in c(0, 20, 50, 100, 150, 200, 500)) {
      keep <- tot >= fl & tot > 0
      ud <- list(m = m[keep, , drop = FALSE], g = droplevels(g[keep]), samples = rownames(m)[keep], cov = NULL)
      r <- tryCatch(fit_once(ud, colnames(m)), error = function(e) NULL)
      if (is.null(r)) { rows[[length(rows) + 1]] <- data.frame(design = dn, seed = seed, floor = fl, fitted = FALSE, dropped = sum(!keep), tp = NA, fp = NA, planted = d$planted); next }
      q <- p.adjust(r$p, "BH"); hit <- q < 0.05; tr <- truth[match(r$feature, colnames(m))]
      rows[[length(rows) + 1]] <- data.frame(design = dn, seed = seed, floor = fl, fitted = TRUE, dropped = sum(!keep), tp = sum(hit & tr), fp = sum(hit & !tr), planted = d$planted)
    }
  }
}
res <- do.call(rbind, rows); utils::write.csv(res, out, row.names = FALSE)
agg <- do.call(rbind, lapply(split(res, list(res$design, res$floor)), function(x) data.frame(design = x$design[1], floor = x$floor[1], fitted_share = mean(x$fitted),
  mean_dropped = round(mean(x$dropped), 1), mean_power = round(mean(x$tp / x$planted, na.rm = TRUE), 3), mean_false_positives = round(mean(x$fp, na.rm = TRUE), 2),
  mean_fdp = round(mean(ifelse(x$tp + x$fp > 0, x$fp / (x$tp + x$fp), 0), na.rm = TRUE), 3))))
rownames(agg) <- NULL; print(agg[order(agg$design, agg$floor), ], row.names = FALSE)
