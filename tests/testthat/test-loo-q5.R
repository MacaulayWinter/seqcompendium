# Leave-one-out Q5 builds the comparison's data once per left-out sample and
# shares it between the leads (CLAUDE.md D71). Its verdicts must be those of
# the loop it replaced, which rebuilt the data for every lead; that loop is
# written out here as the reference. Invented data only.

ns <- asNamespace("seqcompendium")

loo_q5_reference <- function(r, units, layers, des) {
  r$loo_stable <- "not needed (not a lead)"
  worst <- family_worst(r, c("layer", "predictor", "contrast", "timepoint", "block"))
  for (i in which(r$status == "lead")) {
    x <- r[i, ]; u <- find_unit(units, x)
    rows <- do.call(rbind, lapply(c(u$ref_samples, u$level_samples), function(s) {
      ud <- unit_data(drop_sample(u, s), layers[[u$layer]], des); y <- as.integer(ud$m[, x$feature] > 0)
      dat <- if (is.null(ud$cov)) data.frame(y = y, g = ud$g) else data.frame(y = y, ud$cov, g = ud$g)
      fml <- stats::as.formula(paste("y ~", cov_terms(ud$cov), "g")); k <- paste0("g", u$level)
      if (length(unique(y)) < 2) return(data.frame(sample = s, effect = NA, p = NA))
      if (x$method_id == "G06") { j <- which(colnames(stats::model.matrix(fml, dat)) == k); f <- logistf::logistf(fml, data = dat, plconf = j)
        return(data.frame(sample = s, effect = unname(f$coefficients[j]), p = unname(f$prob[j]))) }
      co <- summary(suppressWarnings(stats::glm(fml, data = dat, family = stats::binomial())))$coefficients
      data.frame(sample = s, effect = co[k, 1], p = co[k, 4])
    }))
    r$loo_stable[i] <- loo_verdict(x$effect, x$p, worst[i], rows)
  }
  r
}
environment(loo_q5_reference) <- ns                          # it uses the engine's internal helpers

# Three groups, so two comparisons. Features: some differing, one present only
# in group c (Firth), one present in a single sample (its presence stops
# varying when that sample is left out).
q5_toy <- function(seed = 20261125L) {
  set.seed(seed)
  s <- sprintf("s%02d", 1:36); g <- rep(c("a", "b", "c"), each = 12); f <- sprintf("f%d", 1:8)
  prob <- cbind(c(a = .1, b = .9, c = .5), c(.9, .1, .5), c(.5, .5, .5), c(.3, .7, .9), c(.6, .6, .6), c(.2, .5, .8))
  m <- matrix(0, 36, 8, dimnames = list(s, f))
  for (j in 1:6) m[, j] <- stats::rbinom(36, 1, prob[g, j]) * (1 + stats::rpois(36, 20))
  m[g == "c", 7] <- 5; m["s13", 8] <- 7
  layer <- list(spec = list(unit = "count"), data = data.frame(sample = rep(s, 8), feature = rep(f, each = 36), value = as.vector(m)))
  unit <- function(lv) list(layer = "x", predictor = "group", reference = "a", level = lv, contrast = paste(lv, "vs a"),
                            timepoint = "none", block = "none", ref_samples = s[g == "a"], level_samples = s[g == lv], testable = TRUE)
  list(units = list(unit("b"), unit("c")), layers = list(x = layer))
}

test_that("leave-one-out Q5 gives the reference loop's verdicts and builds each left-out sample's data once", {
  t <- q5_toy()
  r <- ns$q5_presence(t$units, t$layers)$results
  expect_true(all(c("G06", "R01") %in% r$method_id))
  r$status <- "lead"; r$status[2] <- "no_evidence"          # every result but one is refitted
  r <- r[sample(nrow(r)), ]                                  # leads of a comparison need not be next to each other
  expected <- suppressWarnings(loo_q5_reference(r, t$units, t$layers, NULL))
  expect_gt(length(unique(expected$loo_stable)), 2)          # not vacuous: stable and unstable leads
  builds <- 0
  real <- ns$unit_data
  testthat::local_mocked_bindings(unit_data = function(...) { builds <<- builds + 1; real(...) }, .package = "seqcompendium")
  got <- suppressWarnings(ns$loo_q5(r, t$units, t$layers, NULL))
  expect_identical(got, expected)
  expect_equal(builds, 2 * 24)                               # 2 comparisons x 24 samples, whatever the number of leads
})
