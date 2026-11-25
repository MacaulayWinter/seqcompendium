# V-E7b's comparison script (CLAUDE.md D52): two flaws found on ArcticFireSoils,
# each with its regression test. Hand-made tables only, never real data. Run from
# the repository root: Rscript -e 'testthat::test_dir("validation/tests")'
here <- if (dir.exists("validation/R")) "validation/R" else "../R"
source(file.path(here, "ve7b_bits.R"))

test_that("V-E7b: LEfSe's 'flagged nothing' row (feature NA) is not counted as a feature", {
  nothing <- data.frame(unit = "u", method_id = "D19", feature = NA_character_, lda_score = NA_real_, note = "LEfSe flagged no feature", role = "describe_only")
  failed <- transform(nothing, note = "LEfSe did not run: some error")
  expect_identical(ve7b_engine_count("D19", NULL, nothing), 0L)      # the flaw counted 1 here
  expect_true(is.na(ve7b_engine_count("D19", NULL, failed)))        # LEfSe did not run: failed, not 0 (D55)
  expect_match(ve7b_engine_failure("D19", NULL, failed), "LEfSe did not run: some error")
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

test_that("V-E7b: a method that failed inside the engine is reported as failed (NA, with its error), never 0 (D55)", {
  # As on the cluster: ALDEx2 failed in q4_agreement, every D04 row has p = NA.
  ag <- data.frame(method_id = c(rep("D04", 3), rep("D17", 3)), feature = rep(c("a", "b", "c"), 2), p = c(NA, NA, NA, 0.001, 0.2, 0.5),
                   note = c(rep("the method failed to fit: cannot allocate vector of size 2.1 Gb", 3), rep("", 3)))
  expect_true(is.na(ve7b_engine_count("D04", ag, NULL)))             # the old script gave 0 here
  expect_match(ve7b_engine_failure("D04", ag, NULL), "cannot allocate vector")
  expect_identical(ve7b_engine_count("D17", ag, NULL), 1L)
  expect_identical(ve7b_engine_failure("D17", ag, NULL), "")
  old_note <- transform(ag, note = ifelse(method_id == "D04", "the method failed to fit", ""))   # engine before D55: no message
  expect_true(is.na(ve7b_engine_count("D04", old_note, NULL)))
  no_p <- transform(ag, note = "")                                   # no note, but no p-value either
  expect_true(is.na(ve7b_engine_count("D04", no_p, NULL)))
  expect_true(is.na(ve7b_engine_count("D04", NULL, NULL)))
})

test_that("V-E7b: the engine's tables, notes and report are kept before the compendium is deleted", {
  o <- tempfile("out"); k <- tempfile("keep")
  for (f in c("04_agreement/Q4.csv", "04_agreement/Q4_describe_only.csv", "report/compendium_report.md", "05_leads/leads.csv",
              "02_method_choice/override.csv", "02_method_choice/simulation/calibration.csv")) {
    dir.create(dirname(file.path(o, f)), recursive = TRUE, showWarnings = FALSE); writeLines(f, file.path(o, f))
  }
  kept <- ve7b_keep_engine_files(o, k)
  expect_setequal(kept, c("04_agreement__Q4.csv", "04_agreement__Q4_describe_only.csv", "report__compendium_report.md",
                          "02_method_choice__override.csv", "02_method_choice__simulation__calibration.csv"))
  expect_identical(readLines(file.path(k, "04_agreement__Q4_describe_only.csv")), "04_agreement/Q4_describe_only.csv")
  unlink(o, recursive = TRUE)                                          # the compendium goes; the copies stay
  expect_true(all(file.exists(file.path(k, kept))))
  unlink(k, recursive = TRUE)
})

# V-E7(c) scorer rule (PREREGISTRATION section 9, Part B; the default's rows are in the default table).
# Hand-made tables only, never real data. `df` is the default table (results.csv), `ag` the alternatives (Q4.csv).
test_that("V-E7(c) scorer: a method only in the default table is counted from it", {
  df <- data.frame(method_id = "D04", feature = c("a", "b", "c"), p = c(0.001, 0.01, 0.9))   # BH: 0.003, 0.015, 0.9 -> 2
  ag <- data.frame(method_id = "D17", feature = c("a", "b"), p = c(0.001, 0.5))
  expect_identical(ve7b_count_source("D04", ag, NULL, df), "default")
  expect_identical(ve7b_engine_count("D04", ag, NULL, df), 2L)
  expect_identical(ve7b_engine_failure("D04", ag, NULL, df), "")
})

test_that("V-E7(c) scorer: a method only in the alternatives table is counted as before", {
  df <- data.frame(method_id = "D04", feature = c("a", "b"), p = c(0.001, 0.9))
  ag <- data.frame(method_id = "D17", feature = c("a", "b", "c"), p = c(0.001, 0.002, 0.8))  # BH: 0.003, 0.003, 0.8 -> 2
  expect_identical(ve7b_count_source("D17", ag, NULL, df), "alternatives")
  expect_identical(ve7b_engine_count("D17", ag, NULL, df), 2L)
})

test_that("V-E7(c) scorer: a method in both tables uses the default's rows", {
  df <- data.frame(method_id = "D04", feature = c("a", "b", "c"), p = c(0.001, 0.002, 0.003))   # 3
  ag <- data.frame(method_id = "D04", feature = c("a", "b", "c"), p = c(0.9, 0.9, 0.9))         # 0
  expect_identical(ve7b_count_source("D04", ag, NULL, df), "default")
  expect_identical(ve7b_engine_count("D04", ag, NULL, df), 3L)
})

test_that("V-E7(c) scorer: a method in neither table is NA and failed, as before", {
  df <- data.frame(method_id = "D04", feature = "a", p = 0.001)
  ag <- data.frame(method_id = "D17", feature = "a", p = 0.001)
  expect_true(is.na(ve7b_engine_count("D06", ag, NULL, df)))
  expect_match(ve7b_engine_failure("D06", ag, NULL, df), "no rows")
})

test_that("V-E7(c) scorer: a q exactly at 0.05 is not counted, one just below is", {
  # One feature: BH q equals p. 0.05 is not < 0.05; 0.0499 is.
  expect_identical(ve7b_engine_count("D04", NULL, NULL, data.frame(method_id = "D04", feature = "a", p = 0.05)), 0L)
  expect_identical(ve7b_engine_count("D04", NULL, NULL, data.frame(method_id = "D04", feature = "a", p = 0.0499)), 1L)
})

test_that("V-E7(c) scorer: a default method with no p-value is NA, with the old reason", {
  df <- data.frame(method_id = "D04", feature = c("a", "b"), p = c(NA_real_, NA_real_))
  expect_true(is.na(ve7b_engine_count("D04", NULL, NULL, df)))
  expect_match(ve7b_engine_failure("D04", NULL, NULL, df), "gave no p-value")
})

test_that("V-E7(c) scorer: a default method that failed keeps its error message", {
  df <- data.frame(method_id = "D04", feature = c("a", "b"), p = c(NA_real_, NA_real_),
                   note = "the method failed to fit: out of memory")
  expect_true(is.na(ve7b_engine_count("D04", NULL, NULL, df)))
  expect_match(ve7b_engine_failure("D04", NULL, NULL, df), "out of memory")
})

test_that("V-E7(c) scorer: without the default table the old behaviour is unchanged (V-E7(b) scoring)", {
  ag <- data.frame(method_id = "D04", feature = c("a", "b"), p = c(0.001, 0.9))
  expect_identical(ve7b_engine_count("D04", ag, NULL), 1L)
  expect_identical(ve7b_count_source("D04", ag, NULL), "alternatives")
})

# ---- D66 and D68 (after the V-E7b ArcticFreshwaters rerun) --------------------------------------------------------------
test_that("D68: a method the override made the primary is counted from the default table when the harness passes it", {
  set.seed(1); n <- 100
  tab <- function(id, k) data.frame(method_id = id, feature = paste0("f", 1:n), p = c(runif(k, 1e-12, 1e-6), runif(n - k)), note = "", stringsAsFactors = FALSE)
  primary <- tab("D04", 30); ag <- rbind(tab("D06", 40), tab("D17", 55))
  expect_true(is.na(ve7b_engine_count("D04", ag, NULL)))                     # as the rerun printed: "no rows"
  expect_match(ve7b_engine_failure("D04", ag, NULL), "no rows")
  expect_gte(ve7b_engine_count("D04", ag, NULL, primary), 30)                # found in the default table
  expect_identical(ve7b_engine_count("D06", ag, NULL, primary), ve7b_engine_count("D06", ag, NULL))   # other methods unchanged
  bad <- primary; bad$p <- NA_real_; bad$note <- "the method failed to fit: boom"
  expect_true(is.na(ve7b_engine_count("D04", ag, NULL, bad)))                # a failed primary is still NA, never 0
})

test_that("D66: the optional all-samples prevalence filter changes the feature set as planned and is off by default", {
  skip_if_not_installed("data.table")
  # 100 samples in the table, the first 60 analysed. f1: in 30 analysed samples (kept either way). f2: in 7 analysed samples only
  # (11.7% of the analysed, 7% of all: kept by the analysed-samples filter, dropped by the all-samples one). f3: in 20 of the other 40
  # samples only (20% of all, absent from the analysed: kept by the all-samples filter as an all-zero row). f4: nowhere.
  samp <- paste0("s", 1:100); an <- samp[1:60]
  m <- matrix(0, 4, 100, dimnames = list(paste0("f", 1:4), samp))
  m["f1", 1:30] <- 3; m["f2", 1:7] <- 2; m["f3", 61:80] <- 4
  f <- tempfile(fileext = ".tsv"); writeLines("# Constructed", f)
  suppressWarnings(utils::write.table(cbind(`#OTU ID` = rownames(m), m), f, sep = "\t", quote = FALSE, row.names = FALSE, append = TRUE, col.names = TRUE))
  d <- read_asvs(f, an)
  expect_identical(d, read_asvs(f, an, "analysed"))                      # off by default: identical
  expect_identical(rownames(d), c("f1", "f2"))
  a <- read_asvs(f, an, "all_samples")
  expect_identical(rownames(a), c("f1", "f3")); expect_identical(colnames(a), an)
  expect_error(ve7b_write_bundle(tempdir(), "ArcticFireSoils", VE7B_SETS$ArcticFireSoils, tempfile(), "all_samples"), "ArcticFreshwaters only")
})
