# Old (main) against new leave-one-out Q5 on invented tables, with covariates and Firth leads; then the speed-up.
# usage: Rscript identity_host.R <branch worktree> <main loo.R>
a <- commandArgs(TRUE); R <- file.path(a[1], "R")
for (f in c("utils.R", "profile.R", "adjust.R", "units.R", "questions.R", "loo.R")) source(file.path(R, f))
rl <- yaml::read_yaml(file.path(a[1], "inst", "rules", "rules.yaml")); rules <- function() rl
new <- loo_q5; old_env <- new.env(); sys.source(a[2], old_env, keep.source = FALSE)
old <- old_env$loo_q5; environment(old) <- globalenv()
toy <- function(n, p, seed, cov = FALSE, levels = c("a", "b", "c")) {
  set.seed(seed); s <- sprintf("s%04d", seq_len(n)); g <- rep(levels, length.out = n); f <- sprintf("f%04d", seq_len(p))
  run <- sample(c("r1", "r2"), n, TRUE); age <- round(runif(n, 20, 60))
  m <- matrix(0, n, p, dimnames = list(s, f))
  for (j in seq_len(p)) { pr <- runif(length(levels), .05, .95); names(pr) <- levels; m[, j] <- rbinom(n, 1, pr[g]) * (1 + rpois(n, 20)) }
  m[g == levels[2], 1] <- 3; m[g != levels[2], 1] <- 0; m[, 2] <- 0; m[s[2], 2] <- 4
  layer <- list(spec = list(unit = "count"), data = data.frame(sample = rep(s, p), feature = rep(f, each = n), value = as.vector(m)))
  unit <- function(lv) list(layer = "x", predictor = "group", reference = levels[1], level = lv, contrast = paste(lv, "vs", levels[1]),
    timepoint = "none", block = "none", ref_samples = s[g == levels[1]], level_samples = s[g == lv], testable = TRUE)
  des <- if (cov) list(study = data.frame(sample = s, group = g, run = run, age = age), batch = "run", grouping = "group", continuous = "age",
    types = list(run = "categorical", group = "categorical", age = "continuous"), levels_of = function(x) character(0))
  list(units = lapply(levels[-1], unit), layers = list(x = layer), des = des)
}
cat("== identity: identical() on the whole results table\n")
for (case in list(c(30, 20, 1, 0), c(45, 25, 2, 1), c(90, 40, 3, 0), c(90, 40, 4, 1))) {
  t <- toy(case[1], case[2], case[3], case[4] == 1)
  r <- suppressWarnings(q5_presence(t$units, t$layers, t$des))$results
  r$status <- "lead"; r$status[seq(5, nrow(r), 7)] <- "no_evidence"
  o <- suppressWarnings(old(r, t$units, t$layers, t$des)); nw <- suppressWarnings(new(r, t$units, t$layers, t$des))
  cat(sprintf("n=%d p=%d covariates=%s: leads %d (Firth %d), verdicts yes %d / no %d, adjusted '%s', identical %s\n", case[1], case[2], case[4] == 1,
    sum(r$status == "lead"), sum(r$status == "lead" & r$method_id == "G06"), sum(o$loo_stable == "yes"), sum(grepl("^no:", o$loo_stable)),
    r$adjusted_for[1], identical(o, nw)))
}
cat("== speed-up, one core, two groups\n")
for (case in list(c(100, 100, 20), c(300, 346, 20), c(936, 346, 20))) {
  t <- toy(case[1], case[2], 5, FALSE, c("a", "b"))
  r <- suppressWarnings(q5_presence(t$units, t$layers))$results
  r$status <- "no_evidence"; r$status[which(r$method_id == "R01")[seq_len(case[3])]] <- "lead"
  to <- system.time(o <- suppressWarnings(old(r, t$units, t$layers, NULL)))[[3]]
  tn <- system.time(nw <- suppressWarnings(new(r, t$units, t$layers, NULL)))[[3]]
  cat(sprintf("n=%d p=%d, %d logistic leads: main %.1f s, branch %.1f s, %.1f times faster, identical %s\n", case[1], case[2], case[3], to, tn, to / tn, identical(o, nw)))
}
cat("== one refit at 935 samples, 346 features\n")
t <- toy(936, 346, 6, FALSE, c("a", "b")); u <- drop_sample(t$units[[1]], "s0010")
b <- system.time(for (i in 1:20) ud <- unit_data(u, t$layers$x))[[3]] / 20
g1 <- system.time(for (i in 3:22) loo_q5_refit(ud, colnames(ud$m)[i], "R01", "b"))[[3]] / 20
f1 <- system.time(for (i in 1:20) suppressWarnings(loo_q5_refit(ud, "f0001", "G06", "b")))[[3]] / 20
cat(sprintf("data build %.1f ms, logistic refit %.1f ms, Firth refit %.1f ms\n", 1000 * b, 1000 * g1, 1000 * f1))
cat("END\n")
