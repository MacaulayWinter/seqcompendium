# E1-M1, M4, M5, M6, M8, M9, M11: the main toy bundle from end to end.

b <- toy(); o <- out_dir()
leads <- run_compendium(b, o)
f <- function(...) file.path(o, ...)

test_that("E1-M1: every E1 file in the §9 layout is written", {
  expected <- c("README.txt", "report/compendium_report.md", "00_input_check/bundle_check.csv", "00_input_check/column_guide_used.csv",
                "00_input_check/design_reading.txt", "00_input_check/controls.csv", "01_profile/shape_profile.csv",
                "03_results/Q1_describe/results.csv", "03_results/Q2_alpha/results.csv", "03_results/Q2_alpha/per_sample.csv",
                "03_results/Q2_alpha/diagnostics.csv", "03_results/Q2_alpha/model_info.csv", "05_leads/leads.csv",
                "figures/figures_index.csv", "provenance/session_info.txt", "provenance/engine.yaml", "provenance/inputs.sha256")
  expect_true(all(file.exists(f(expected))), info = paste(expected[!file.exists(f(expected))], collapse = ", "))
  if (rmarkdown::pandoc_available()) expect_true(file.exists(f("report", "compendium_report.html")))
})

test_that("E1-M4: controls never enter a result, and every control is listed", {
  ctl <- c("BLANK1", "BLANK2", "MOCK1")
  ps <- rd(f("03_results/Q2_alpha/per_sample.csv"))
  expect_false(any(ps$sample %in% ctl))
  q1 <- rd(f("03_results/Q1_describe/results.csv"))
  expect_equal(sum(as.integer(q1$n_samples[q1$feature == "toyG01"])), 24L)
  pr <- rd(f("01_profile/shape_profile.csv"))
  expect_equal(pr$value[pr$property == "n_study_samples"], "24")
  ct <- rd(f("00_input_check/controls.csv"))
  expect_equal(ct$sample, ctl); expect_equal(ct$kind, c("negative_extraction", "negative_extraction", "positive_mock"))
})

test_that("E1-M4: a design with no controls warns, and flags every lead", {
  o2 <- out_dir(); l2 <- run_compendium(toy("no_controls"), o2)
  expect_true(all(l2$flags == "no_controls"))
  expect_true(any(grepl("Warning: this design has no control samples", readLines(file.path(o2, "report", "compendium_report.md")))))
})

test_that("E1-M5: the profile matches an independent computation, with a source on every row", {
  pr <- rd(f("01_profile/shape_profile.csv"))
  expect_true(all(nzchar(pr$source)))
  x <- rd(file.path(b, LAYER)); x <- x[!x$sample %in% c("BLANK1", "BLANK2", "MOCK1"), ]; x$value <- as.numeric(x$value)
  lib <- tapply(x$value, x$sample, sum)
  v <- function(k) pr$value[pr$property == k]
  expect_equal(v("n_study_samples"), as.character(length(lib)))
  expect_equal(v("n_features"), as.character(length(unique(x$feature))))
  expect_equal(v("zeros_percent"), sprintf("%.1f", 100 * mean(x$value == 0)))
  expect_equal(as.numeric(c(v("library_size_min"), v("library_size_median"), v("library_size_max"))), c(min(lib), median(lib), max(lib)))
})

test_that("E1-M6: Q1 matches an independent computation", {
  q1 <- rd(f("03_results/Q1_describe/results.csv"))
  x <- rd(file.path(b, LAYER)); m <- rd(file.path(b, META))
  x <- merge(x, m, by = "sample"); x <- x[x$kind == "none", ]; x$value <- as.numeric(x$value)
  for (k in seq_len(nrow(q1))) {
    s <- x[x$feature == q1$feature[k] & x$group == q1$group[k] & x$day == q1$timepoint[k], ]
    expect_equal(as.numeric(q1$prevalence[k]), mean(s$value > 0))
    expect_equal(as.numeric(q1$median[k]), median(s$value))
  }
})

test_that("E1-M8: the leads table has every §8.1 column, every question, and BH within each cell", {
  l <- rd(f("05_leads/leads.csv"))
  expect_equal(names(l), c("lead_id", "tier", "rank", "status", "question", "layer", "feature", "contrast", "timepoint", "block",
                           "effect", "effect_unit", "ci_low", "ci_high", "p", "q", "p_floor", "n_per_group", "method", "method_role",
                           "agreement", "agreement_label", "loo_stable", "min_detectable_effect", "caveats", "flags", "result_file"))
  expect_true(all(sprintf("Q%d", 0:11) %in% l$question))
  r <- rd(f("03_results/Q2_alpha/results.csv"))
  for (k in unique(paste(r$contrast, r$timepoint, r$block))) {
    i <- paste(r$contrast, r$timepoint, r$block) == k
    expect_equal(as.numeric(r$q[i]), p.adjust(as.numeric(r$p[i]), "BH"))
  }
  expect_false(any(r$timepoint == "all"))
})

test_that("E1-M9: the report has its sections in order and Q2's five parts", {
  md <- readLines(f("report", "compendium_report.md"))
  heads <- c("Input check", "Controls", "Design as read", "Shape profile", "Q1.", "Q2.", "What was not found", "Leads")
  pos <- vapply(heads, function(h) grep(sprintf("^## [0-9]+\\. %s", gsub(".", "\\.", h, fixed = TRUE)), md)[1], 1L)
  expect_false(anyNA(pos)); expect_true(all(diff(pos) > 0))
  for (part in c("**What was asked.**", "**Why this method.**", "**What the checks showed.**", "**Limitations.**", "**Did the alternatives agree.**"))
    expect_true(any(startsWith(md, part)), info = part)
})

test_that("E1-M11: two runs give byte-identical CSVs", {
  o2 <- out_dir(); run_compendium(b, o2)
  csv <- list.files(o, pattern = "\\.csv$", recursive = TRUE)
  expect_gt(length(csv), 8)
  expect_equal(unname(tools::md5sum(file.path(o2, csv))), unname(tools::md5sum(file.path(o, csv))))
})
