# Profile of leave-one-out Q5 on an invented table (no research data).
# usage: Rscript profile_q5.R <repo> <samples> <features> <leads> <left-out samples timed>
a <- commandArgs(TRUE); for (r in c("profile.R", "units.R", "loo.R")) source(file.path(a[1], "R", r))   # only wide, unit_data, drop_sample are used
n <- as.integer(a[2]); p <- as.integer(a[3]); L <- as.integer(a[4]); K <- as.integer(a[5])
set.seed(20261125)
s <- sprintf("S%04d", seq_len(n)); f <- sprintf("F%04d", seq_len(p))
g <- rep(c("a", "b"), c(n %/% 2, n - n %/% 2))
m <- matrix(rbinom(n * p, 1, 0.2) * rpois(n * p, 20), n, p, dimnames = list(s, f))
layer <- list(data = data.frame(sample = rep(s, p), feature = rep(f, each = n), value = as.vector(m)))
u <- list(ref_samples = s[g == "a"], level_samples = s[g == "b"], reference = "a", level = "b", predictor = "group")
pick <- s[round(seq(1, n, length.out = K))]
one <- function(smp, feat) {
  t0 <- proc.time()[[3]]; ud <- unit_data(drop_sample(u, smp), layer, NULL)
  t1 <- proc.time()[[3]]; y <- as.integer(ud$m[, feat] > 0); dat <- data.frame(y = y, g = ud$g)
  co <- summary(suppressWarnings(stats::glm(y ~ g, data = dat, family = stats::binomial())))$coefficients
  c(build = t1 - t0, fit = proc.time()[[3]] - t1)
}
x <- do.call(rbind, lapply(pick, function(smp) t(sapply(f[seq_len(L)], function(ft) one(smp, ft)))))
cat(sprintf("%d samples, %d features: %d refits timed\n", n, p, nrow(x)))
tot <- colSums(x); cat(sprintf("matrix rebuild (unit_data): %.1f s, %.1f ms per refit, %.0f%%\nmodel fit and summary: %.1f s, %.1f ms per refit, %.0f%%\n",
  tot[1], 1000 * tot[1] / nrow(x), 100 * tot[1] / sum(tot), tot[2], 1000 * tot[2] / nrow(x), 100 * tot[2] / sum(tot)))
Rprof(pf <- tempfile()); for (smp in pick) for (ft in f[seq_len(L)]) one(smp, ft); Rprof(NULL)
by <- summaryRprof(pf)$by.total
print(by[intersect(c('"one"', '"unit_data"', '"wide"', '"sort"', '"unique"', '"match"', '"%in%"', '"[.data.frame"', '"stats::glm"', '"glm.fit"', '"summary"'), rownames(by)), c("total.time", "total.pct")])
