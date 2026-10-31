# The validation machinery's own marks (CLAUDE.md D33: E7-M1 to E7-M5), on an
# invented template (never real data). Run from the repository root:
#   Rscript -e 'testthat::test_dir("validation/tests")'
here <- if (dir.exists("validation/R")) "validation/R" else "../R"
for (f in c("scenarios.R", "simulate.R", "score.R", "templates.R", "engine_bits.R")) source(file.path(here, f))

invented_template <- function(seed = 1, n = 40, p = 120) {
  set.seed(seed)
  mu <- exp(stats::rnorm(p, 2.5, 1.6))
  m <- t(vapply(seq_len(n), function(i) stats::rnbinom(p, mu = mu * stats::runif(1, 0.5, 2), size = 0.8), numeric(p)))
  dimnames(m) <- list(sprintf("t%02d", seq_len(n)), sprintf("taxon%03d", seq_len(p)))
  m
}
FIT <- local({ m <- invented_template(); fit_template(m, reads = stats::setNames(rowSums(m) * 3, rownames(m))) })

m1_ratio <- function(fit, fc, draws = 200, n = 50) {
  # The ratio of mean absolute abundances, pooled over the draws (a mean of
  # per-draw ratios is biased upward by heavy-tailed counts; CLAUDE.md D35).
  smp <- design_samples("two_group", n); pl <- fit$common[1:6]
  tr <- 0; ct <- 0
  for (i in seq_len(draws)) {
    sim <- simulate_counts(fit, smp, plant = list(features = pl, fc = fc, in_group = "treated", at_time = NULL))
    rel <- sim$m / rowSums(sim$m)
    abs <- rel / rowSums(rel[, setdiff(colnames(rel), pl), drop = FALSE])   # absolute scale: the unplanted total is unchanged
    tr <- tr + colSums(abs[smp$group == "treated", ]); ct <- ct + colSums(abs[smp$group == "control", ])
  }
  list(r = tr / ct, pl = pl)
}

test_that("E7-M1: planted features shift by the fold change on the absolute scale; others do not", {
  for (seed in c(1, 2, 3)) {   # seeds 2 and 3: fresh-data confirmation (D35)
    fit <- if (seed == 1) FIT else local({ m <- invented_template(seed); fit_template(m) })
    x <- m1_ratio(fit, fc = 2)
    expect_true(all(abs(x$r[x$pl] / 2 - 1) <= 0.10), info = paste(seed, paste(round(x$r[x$pl], 3), collapse = " ")))
    u <- setdiff(fit$common, x$pl)
    expect_true(all(abs(x$r[u] - 1) <= 0.10), info = paste(seed, paste(round(range(x$r[u]), 3), collapse = " ")))
  }
})

test_that("E7-M1: planted features are common; controls and truth are as pre-registered", {
  b <- tempfile("b"); tr <- simulate_bundle(FIT, list(design = "two_group", n = 10, fc = 2, plant_share = 0.1), seed = 11, b, scenario = "test")
  expect_true(file.exists(file.path(b, "truth.yaml")))
  m <- FIT$counts
  expect_true(all(colMeans(m[, tr$planted] > 0) >= 0.5))
  expect_equal(length(tr$planted), round(0.1 * ncol(m)))
  md <- utils::read.delim(file.path(b, "metadata/study_metadata.tsv"))
  long <- utils::read.delim(file.path(b, "layers/sim_counts.tsv"))
  expect_equal(sort(md$sample[md$kind == "negative_extraction"]), c("BLANK1", "BLANK2"))
  for (bl in c("BLANK1", "BLANK2")) expect_equal(sort(long$feature[long$sample == bl & long$value > 0]), sort(tr$contaminants))
  mk <- long[long$sample == "MOCK1" & long$value > 0, ]
  expect_equal(nrow(mk), 8); expect_equal(length(unique(mk$value)), 1)
  comp <- utils::read.delim(file.path(b, "layers/mock_composition.tsv"))
  expect_equal(sort(comp$feature), sort(tr$mock_members)); expect_equal(comp$proportion, rep(1 / 8, 8))
})

test_that("E7-M2: seeds follow the pre-registered formula; the same seed gives a byte-identical bundle", {
  expect_equal(run_seed(7, 3), 20261029L + 7000L + 3L)
  expect_equal(run_seed(7, 3, fresh = TRUE), 20261029L + 7000L + 3L + 500000L)
  b1 <- tempfile("b"); b2 <- tempfile("b")
  simulate_bundle(FIT, list(design = "longitudinal", n = 5), seed = run_seed(7, 3), b1, scenario = "x")
  simulate_bundle(FIT, list(design = "longitudinal", n = 5), seed = run_seed(7, 3), b2, scenario = "x")
  f <- list.files(b1, recursive = TRUE)
  expect_equal(unname(tools::md5sum(file.path(b1, f))), unname(tools::md5sum(file.path(b2, f))))
  mf <- yaml::read_yaml(file.path(b1, "manifest.yaml"))
  expect_equal(mf$produced_by$seed, run_seed(7, 3))
})

test_that("E7-M3: the data-choice rule picks the known answer and stops on a doubt", {
  sm <- do.call(rbind, lapply(c("ZetaStudy", "AlphaStudy", "betaStudy", "BetaStudy", "SmallStudy"), function(st) {
    n <- if (st == "SmallStudy") 19 else 25
    data.frame(study_name = st, subject_id = rep(sprintf("p%02d", seq_len(n)), each = 2), sample_id = sprintf("%s_%03d", st, seq_len(2 * n)),
               days_from_first_collection = rep(c(NA, 30), n), body_site = "stool", study_condition = "control", number_reads = 1e6, stringsAsFactors = FALSE)
  }))
  sm <- rbind(sm, transform(sm[1:30, ], study_condition = "CRC", sample_id = paste0(sm$sample_id[1:30], "x")))
  x <- choose_shotgun(sm)
  # C-locale order: upper case before lower case.
  expect_equal(unique(x$study_name), c("AlphaStudy", "BetaStudy", "ZetaStudy"))
  expect_equal(nrow(x), 75)
  expect_true(all(is.na(x$days_from_first_collection)))   # missing counts as 0, so the first visit is kept
  expect_equal(unique(choose_shotgun(sm, how_many = 1, skip = 3)$study_name), "betaStudy")
  expect_error(choose_shotgun(sm, how_many = 3, skip = 2), "Data doubt.*step 5", class = "data_doubt")
  expect_error(choose_shotgun(sm[, names(sm) != "number_reads"]), "number_reads", class = "data_doubt")
  ds <- data.frame(dataset = c("B_16S", "A_16S", "C_WMS", "D_16S"), is_16S = c(TRUE, TRUE, FALSE, TRUE), grouping = c("site", "condition", "site", "condition"))
  smp <- rbind(data.frame(dataset = "B_16S", sample = sprintf("b%02d", 1:50), site = rep(c("gum", "tongue"), c(30, 20)), condition = NA),
               data.frame(dataset = "A_16S", sample = sprintf("a%02d", 1:30), site = NA, condition = rep(c("x", "y"), c(15, 15))),
               data.frame(dataset = "D_16S", sample = sprintf("d%02d", 1:40), site = NA, condition = rep(c("x", "y"), c(22, 18))),
               data.frame(dataset = "C_WMS", sample = sprintf("c%02d", 1:90), site = "gum", condition = NA))
  y <- choose_16s(ds, smp)
  expect_equal(names(y), c("B_16S", "D_16S"))     # A_16S's largest group has 15
  expect_equal(nrow(y$B_16S), 30); expect_equal(unique(y$B_16S$site), "gum")
  expect_error(choose_16s(ds, smp, how_many = 3), "Data doubt", class = "data_doubt")
  expect_error(choose_16s(transform(ds, grouping = c("site", "nope", "site", "condition")), smp), "nope", class = "data_doubt")
})

test_that("E7-M4: each scorer gives the known number, at and just past its threshold", {
  mk <- function(lead) { r <- data.frame(mark = "V-E3", scenario = "s", k = seq_along(lead), error = NA)
    for (q in FAMILIES) { r[[paste0("asked_", q)]] <- q != "Q6"; r[[paste0("lead_", q)]] <- lead }; r }
  at <- score_ve3(mk(c(rep(TRUE, 71), rep(FALSE, 429))))           # 71/500 = 0.142 exactly
  expect_true(all(at$pass)); expect_equal(unique(at$number), 0.142)
  past <- score_ve3(mk(c(rep(TRUE, 72), rep(FALSE, 428))))
  expect_false(any(past$pass)); expect_false("s Q6" %in% at$scenario)
  r4 <- data.frame(scenario = "t", error = NA, planted_found = c(8, 8), planted_n = c(10, 10))
  expect_equal(score_ve4(r4)$number, 0.8); expect_true(score_ve4(r4)$pass)
  r4$planted_found[1] <- 7; expect_false(score_ve4(r4)$pass)
  r5 <- data.frame(scenario = "u", error = NA, override_units = 1, override_switched = c(rep(TRUE, 9), FALSE))
  expect_true(score_ve5(r5, data.frame(scenario = "u", fdr = 0.3, miscalibrated = TRUE))$pass)    # 0.90 switched
  expect_false(score_ve5(r5, data.frame(scenario = "u", fdr = 0.05, miscalibrated = FALSE))$pass) # 0.10 kept
  expect_equal(fdr_table(data.frame(mark = "V-E5 fdr", scenario = "u", error = NA, calls = c(0, 4, 2), false_calls = c(0, 1, 2)))$fdr, (0 + 0.25 + 1) / 3)
  d6 <- data.frame(family = "nb", kind = rep(c("violated", "clean"), each = 10), flagged = c(rep(1, 9), 0, 1, rep(0, 9)))
  expect_true(all(score_ve6(d6)$pass))
  d6$flagged[10] <- 0; d6$flagged[9] <- 0
  expect_equal(score_ve6(d6)$pass, c(FALSE, TRUE))
  expect_equal(score_ve2b_contaminants(data.frame(error = NA, contaminants_flagged = c(4, 4), contaminants_n = 5))$pass, TRUE)
  expect_equal(score_ve2b_contaminants(data.frame(error = NA, contaminants_flagged = c(4, 3), contaminants_n = 5))$pass, FALSE)
})

test_that("E7-M5: the V-E1 generator writes the 6 S1 bundles with their true profile", {
  sc <- scenarios(); v1 <- sc[sc$mark == "V-E1", ]
  expect_equal(nrow(v1), 6)
  truths <- lapply(seq_len(nrow(v1)), function(i) simulate_bundle(FIT, list(design = v1$design[i], n = 6), seed = run_seed(v1$scenario[i], 1), tempfile("v1"), scenario = v1$label[i]))
  cls <- vapply(truths, `[[`, "", "class"); blk <- vapply(truths, `[[`, "", "blocks")
  expect_equal(table(paste(cls, blk))[c("snapshot-independent none", "snapshot-independent site", "snapshot-paired none", "snapshot-paired site", "longitudinal none", "longitudinal site")],
               table(rep(c("snapshot-independent none", "snapshot-independent site", "snapshot-paired none", "snapshot-paired site", "longitudinal none", "longitudinal site"), 1)), ignore_attr = TRUE)
})

test_that("scenario numbering is fixed and complete for v0.1.0", {
  sc <- scenarios()
  expect_equal(sc$scenario, seq_len(nrow(sc)))
  expect_equal(table(sc$mark)[c("V-E1", "V-E2b", "V-E3", "V-E4", "V-E5")], c(`V-E1` = 6, `V-E2b` = 5, `V-E3` = 60, `V-E4` = 5, `V-E5` = 15), ignore_attr = TRUE)
})
