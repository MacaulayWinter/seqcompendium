# V-E7b's comparison script (CLAUDE.md D52): two flaws found on ArcticFireSoils,
# each with its regression test. Hand-made tables only, never real data. Run from
# the repository root: Rscript -e 'testthat::test_dir("validation/tests")'
here <- if (dir.exists("validation/R")) "validation/R" else "../R"
source(file.path(here, "ve7b_bits.R"))

test_that("V-E7b: LEfSe's 'flagged nothing' row (feature NA) is not counted as a feature", {
  nothing <- data.frame(unit = "u", method_id = "D19", feature = NA_character_, lda_score = NA_real_, note = "LEfSe flagged no feature", role = "describe_only")
  failed <- transform(nothing, note = "LEfSe did not run: some error")
  expect_identical(ve7b_engine_count("D19", NULL, nothing), 0L)      # the flaw counted 1 here
  expect_identical(ve7b_engine_count("D19", NULL, failed), 0L)
  two <- data.frame(unit = "u", method_id = "D19", feature = c("asv1", "asv2", "asv2"), lda_score = c(3, 2.5, 2.5), note = NA, role = "describe_only")
  expect_identical(ve7b_engine_count("D19", NULL, two), 2L)          # a feature listed twice counts once
  expect_true(is.na(ve7b_engine_count("D19", NULL, NULL)))           # no LEfSe table at all: unknown, not 0
})

test_that("V-E7b: other methods are counted as BH q < 0.05 over finite p-values, by method", {
  ag <- data.frame(method_id = c(rep("D04", 4), rep("D17", 3)), feature = c("a", "b", "c", "d", "a", "b", "c"),
                   p = c(0.001, 0.01, 0.04, NA, 0.2, 0.001, 0.5))
  # D04: BH over the 3 finite p-values: 0.003, 0.015, 0.04 -> all 3 below 0.05.
  expect_identical(ve7b_engine_count("D04", ag, NULL), 3L)
  # D17: 0.6, 0.003, 0.5 -> 1.
  expect_identical(ve7b_engine_count("D17", ag, NULL), 1L)
})

test_that("V-E7b: the engine's tables, notes and report are kept before the compendium is deleted", {
  o <- tempfile("out"); k <- tempfile("keep")
  for (f in c("04_agreement/Q4.csv", "04_agreement/Q4_describe_only.csv", "report/compendium_report.md", "05_leads/leads.csv")) {
    dir.create(dirname(file.path(o, f)), recursive = TRUE, showWarnings = FALSE); writeLines(f, file.path(o, f))
  }
  kept <- ve7b_keep_engine_files(o, k)
  expect_setequal(kept, c("04_agreement__Q4.csv", "04_agreement__Q4_describe_only.csv", "report__compendium_report.md"))
  expect_identical(readLines(file.path(k, "04_agreement__Q4_describe_only.csv")), "04_agreement/Q4_describe_only.csv")
  unlink(o, recursive = TRUE)                                          # the compendium goes; the copies stay
  expect_true(all(file.exists(file.path(k, kept))))
  unlink(k, recursive = TRUE)
})
