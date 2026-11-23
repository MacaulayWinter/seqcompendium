# Tests for the four changes made after the V-E7b ArcticFreshwaters rerun (CLAUDE.md D66 to D69).
# Toy tables with a known answer only.

# The bar used below (at least 5 of 10 planted effects found, at most 1 false positive) is taken from the floor sweep
# (validation/results/v0.1.0/ve7b_fixes/ve7b_linda_floor_sweep_summary.csv), not from a test result: in the sweep's medium design (100 per group,
# effects of log2 1.5) LinDA found about 60% of the planted effects with about 1 false positive per run; this toy has 60 per group and larger effects (log2 2.5),
# so at least half is the least that should be expected, and about 1 false positive in 90 null features is what a q < 0.05 test gives.
linda_toy <- function(n = 60, p = 100, planted = 10, tiny = integer(0), seed = 20261124) {
  set.seed(seed); g <- factor(rep(c("A", "B"), each = n)); mu <- exp(rnorm(p, 1.5, 1.3)); truth <- seq_len(p) <= planted
  lfc <- ifelse(truth, sample(c(-2.5, 2.5), p, TRUE), 0); depth <- rlnorm(2 * n, 0, 0.6)
  m <- sapply(seq_len(p), function(j) rnbinom(2 * n, mu = mu[j] * depth * ifelse(g == "B", 2^lfc[j], 1), size = 1))
  colnames(m) <- paste0("f", seq_len(p)); rownames(m) <- paste0("s", seq_len(2 * n))
  for (i in tiny) { m[i, ] <- 0L; m[i, sample(p, 3)] <- 1L }          # samples with a total of 3 reads
  list(ud = list(m = m, g = g, samples = rownames(m), cov = NULL), truth = setNames(truth, colnames(m)))
}
found <- function(r, truth) { q <- p.adjust(r$p, "BH") < 0.05; c(tp = sum(q & truth[r$feature]), fp = sum(q & !truth[r$feature])) }

test_that("D67: LinDA stops on a table with almost-empty samples; it is retried once without them, the answer is right and the result says so", {
  skip_if_not_installed("MicrobiomeStat")
  x <- linda_toy(tiny = c(3, 50, 70))
  feats <- colnames(x$ud$m)
  first <- tryCatch(seqcompendium:::fit_linda_once(x$ud, feats), error = function(e) e)
  skip_if(!inherits(first, "error"), "this MicrobiomeStat version does not stop on the toy; the retry has nothing to do")
  expect_match(conditionMessage(first), "NA/NaN/Inf")
  r <- seqcompendium:::fit_linda(x$ud, feats)
  note <- attr(r, "linda_note")
  expect_match(note, "R-LINDAFLOOR"); expect_match(note, "3 of 120 samples"); expect_false(grepl("failed to fit|did not run", note))
  fd <- found(r, x$truth); expect_gte(fd[["tp"]], 5); expect_lte(fd[["fp"]], 1)       # 10 planted effects, no false-positive flood
})

test_that("D67: where LinDA works, the retry never fires and the result is exactly what it was", {
  skip_if_not_installed("MicrobiomeStat")
  x <- linda_toy(); feats <- colnames(x$ud$m)
  a <- seqcompendium:::fit_linda(x$ud, feats); b <- seqcompendium:::fit_linda_once(x$ud, feats)
  expect_identical(a, b); expect_null(attr(a, "linda_note"))
  expect_gte(found(a, x$truth)[["tp"]], 5)
})

test_that("D67: if LinDA stops and nothing can be left out, or it stops again, the failure stays loud", {
  skip_if_not_installed("MicrobiomeStat")
  x <- linda_toy(); feats <- colnames(x$ud$m)
  one_group <- x$ud; one_group$g <- factor(rep("A", length(one_group$g)))            # nothing to compare: LinDA stops, and no sample is below the floor
  expect_error(seqcompendium:::fit_linda(one_group, feats))
  # every sample of group B is almost empty: the first run stops, the retry leaves group B with no samples and stops again, and says so
  y <- linda_toy(tiny = 61:120)
  first <- tryCatch(seqcompendium:::fit_linda_once(y$ud, colnames(y$ud$m)), error = function(e) e)
  skip_if(!inherits(first, "error"), "this MicrobiomeStat version does not stop on this toy")
  expect_error(seqcompendium:::fit_linda(y$ud, colnames(y$ud$m)), "stopped again")
})

test_that("D67: a LinDA agreement row carries the note, and the note does not read as a failed fit", {
  skip_if_not_installed("MicrobiomeStat")
  x <- linda_toy(tiny = c(3, 50, 70)); feats <- colnames(x$ud$m)
  skip_if(!inherits(tryCatch(seqcompendium:::fit_linda_once(x$ud, feats), error = function(e) e), "error"), "the toy does not make LinDA stop here")
  ag <- seqcompendium:::q4_agreement(x$ud, feats, "D09")
  expect_true(all(grepl("R-LINDAFLOOR", ag$note))); expect_true(all(is.finite(ag$p)))
  expect_false(any(grepl("failed to fit|did not run", ag$note)))
})

test_that("D69: a run writes provenance/step_timings.tsv (a .tsv, so the compared CSVs are untouched) with the stages and the leave-one-out stages", {
  b <- toy("main"); o <- out_dir(); run_compendium(b, o)
  f <- file.path(o, "provenance", "step_timings.tsv"); expect_true(file.exists(f))
  t <- utils::read.delim(f, check.names = FALSE)
  expect_identical(names(t), c("step", "seconds", "peak_memory_mb", "finished_at"))
  expect_true(all(is.finite(t$seconds)) && all(t$seconds >= 0))
  for (s in c("Q3 composition", "override check", "leave-one-out Q4", "leave-one-out Q3", "report")) expect_true(any(grepl(s, t$step, fixed = TRUE)), info = s)
  expect_false(any(grepl("step_timings", list.files(o, pattern = "\\.csv$", recursive = TRUE))))
})

test_that("D69: with SEQCOMPENDIUM_TIMING_LOG=1 each stage is also printed, for a cluster log", {
  b <- toy("main"); o <- out_dir()
  old <- Sys.getenv("SEQCOMPENDIUM_TIMING_LOG"); Sys.setenv(SEQCOMPENDIUM_TIMING_LOG = "1"); on.exit(Sys.setenv(SEQCOMPENDIUM_TIMING_LOG = old), add = TRUE)
  txt <- utils::capture.output(run_compendium(b, o))
  expect_true(any(grepl("^\\[seqcompendium step\\] leave-one-out Q4", txt)))
})

test_that("D67: the rules file has the floor, a whole number between 50 and 200, and a new rules version", {
  f <- seqcompendium:::rule("R-LINDAFLOOR"); expect_true(f >= 50 && f <= 200 && f == round(f))
  expect_false(identical(seqcompendium:::rules()$rules_version, "2026-11-06.1"))
})
