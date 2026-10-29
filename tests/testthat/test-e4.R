# E4 pass marks (CLAUDE.md D19): the override rule and the mock check.

test_that("E4-M2: too few reference samples keeps the default and says why", {
  x <- run_fixture("main")
  ov <- res_csv(x, "02_method_choice/override.csv")
  expect_true(all(ov$decision == "not run: reference group n = 6, fewer than 10 (rule R-MINSIM)" & ov$final_id == ov$default_id))
  ch <- res_csv(x, "02_method_choice/choices.csv")
  expect_match(ch$override[ch$question == "Q4"], "reference group n = 6, fewer than 10")
  md <- readLines(file.path(x$o, "report", "compendium_report.md"))
  expect_true(any(grepl("could not be checked on simulated data from your controls, because the control group has n = 6 \\(fewer than 10\\)", md)))
})

test_that("E4-M3: calibration for every eligible Q4 method, with seeds", {
  x <- run_fixture("calib")
  cal <- res_csv(x, "02_method_choice/simulation/calibration.csv")
  mc <- res_csv(x, "02_method_choice/methods_considered.csv")
  elig <- intersect(c("D01", "D09", "D06", "D04", "D17"), mc$id[mc$eligible == "yes"])
  expect_setequal(cal$method_id, elig)
  expect_true(all(cal$datasets == getOption("seqcompendium.simrep") & cal$failed_fits == 0 & is.finite(cal$fdr)))
  pr <- res_csv(x, "02_method_choice/simulation/per_dataset.csv")
  expect_true(all(is.finite(pr$seed)))
  expect_equal(sum(pr$planted) * 2, nrow(pr))
})

test_that("E4-M4: the decision rule, on given calibration tables (6 cases)", {
  d <- function(fdr, default = "D01", mock = character(0))
    seqcompendium:::decide_override(data.frame(method_id = names(fdr), fdr = unname(fdr)), default, mock)
  expect_equal(d(c(D01 = 0.10, D09 = 0.05))$decision, "kept")
  expect_equal(d(c(D01 = 0.40, D09 = 0.05, D06 = 0.01))$final, "D09")
  expect_equal(d(c(D01 = 0.40, D09 = 0.30, D06 = 0.10))$final, "D06")
  x <- d(c(D01 = 0.40, D09 = 0.30, D06 = 0.30, D04 = 0.50, D17 = 0.25))
  expect_equal(x$final, "D01"); expect_equal(x$caveat, "no method was calibrated on simulated data like yours")
  expect_equal(d(c(D01 = 0.40, D09 = 0.05, D06 = 0.10), mock = "D09")$final, "D06")
  expect_equal(d(c(D01 = NA, D09 = 0.05))$final, "D09")
})

test_that("E4-M4: 'none calibrated' puts its caveat on every Q4 result of that comparison", {
  b <- toy("main"); bb <- read_bundle(b); gc <- seqcompendium:::check_guide(bb$md, bb$guide); lc <- seqcompendium:::check_layers(bb$layers, gc$md)
  des <- seqcompendium:::read_design(gc$md, bb$guide, gc$info); units <- seqcompendium:::contrast_units(lc$layers, des, seqcompendium:::design_cells(des))
  mc <- seqcompendium:::filter_catalogue("toy_counts", lc$layers$toy_counts, des); ch <- seqcompendium:::choose_methods("toy_counts", lc$layers$toy_counts, mc)
  dec <- cbind(seqcompendium:::unit_key(units[[1]]), default_id = "D01", final_id = "D01", decision = "kept, none calibrated", n_reference = 10,
               default_fdr = 0.4, limit = 0.2, datasets = 6, caveat = "no method was calibrated on simulated data like yours")
  q4 <- seqcompendium:::q4_abundance(units[1], lc$layers, ch, dec)$results
  expect_true(all(grepl("no method was calibrated on simulated data like yours", q4$caveat)))
})

test_that("E4-M5: the decision never sees the non-reference samples' data", {
  b <- toy("calib")
  o1 <- out_dir(); run_compendium(b, o1)
  edit(b, LAYER, function(x) { t <- grepl("^S(1[1-9]|20)_", x$sample); x$value[t] <- as.character(as.numeric(x$value[t]) * 3 + 1); x })
  o2 <- out_dir(); run_compendium(b, o2)
  for (f in c("02_method_choice/simulation/calibration.csv", "02_method_choice/override.csv"))
    expect_equal(unname(tools::md5sum(file.path(o2, f))), unname(tools::md5sum(file.path(o1, f))), info = f)
  expect_false(identical(unname(tools::md5sum(file.path(o2, "03_results/Q4_differential/results.csv"))),
                         unname(tools::md5sum(file.path(o1, "03_results/Q4_differential/results.csv")))))
})

test_that("E4-M6: mock recovery with 2 mocks; the shuffled-label test needs 6", {
  x <- run_fixture("calib")
  rec <- res_csv(x, "00_input_check/mock_recovery.csv")
  expect_setequal(rec$sample, c("MOCK1", "MOCK2"))
  expect_true(all(rec$detected == 8 & is.finite(rec$unexpected_read_share) & is.finite(rec$largest_proportion_error)))
  mt <- res_csv(x, "02_method_choice/simulation/mock_test.csv")
  expect_match(mt$result, "not testable: 2 mocks")
  y <- run_fixture("calib_mocks6")
  mt6 <- res_csv(y, "02_method_choice/simulation/mock_test.csv")
  expect_setequal(mt6$method_id, c("D09", "D06", "D04", "D17"))
  expect_true(all(mt6$result %in% c("passes", "fails: reported differences between mock replicates")))
})

test_that("E4-M7: the report gives the simulation result and the full table; leads use the final method", {
  x <- run_fixture("calib")
  md <- readLines(file.path(x$o, "report", "compendium_report.md"))
  ov <- res_csv(x, "02_method_choice/override.csv")
  expect_true(any(grepl(sprintf("on %d simulated data sets made from your 10 control samples", getOption("seqcompendium.simrep")), md)))
  expect_true(any(grepl("The full simulation check", md)))
  q4 <- res_csv(x, "03_results/Q4_differential/results.csv")
  expect_true(all(q4$method_id[q4$rung == 0] == ov$final_id[1]))
})

test_that("Every alternative method actually runs on the standard fixtures (D20)", {
  for (v in c("main", "no_denominator", "calib")) {
    x <- run_fixture(v)
    for (f in c("04_agreement/Q4.csv", "04_agreement/Q2.csv")) {
      a <- res_csv(x, f)
      expect_false(any(grepl("failed to fit|did not fit", a$note)), info = paste(v, f, paste(unique(a$method_id[grepl("fit", a$note)]), collapse = ",")))
    }
  }
})

test_that("E4-M9: byte-identical CSVs with the simulation", {
  b <- toy("calib"); o1 <- out_dir(); o2 <- out_dir()
  run_compendium(b, o1); run_compendium(b, o2)
  csv <- list.files(o1, pattern = "\\.csv$", recursive = TRUE)
  expect_true("02_method_choice/simulation/calibration.csv" %in% csv)
  expect_equal(unname(tools::md5sum(file.path(o2, csv))), unname(tools::md5sum(file.path(o1, csv))))
})
