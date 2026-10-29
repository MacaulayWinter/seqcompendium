# E1-M2, E1-M3, E1-M13: what stops the run, what must not, and a negative control.

test_that("E1-M2: every broken bundle stops, naming its problem (16 cases)", {
  expect_length(STOP_CASES, 16)
  for (n in names(STOP_CASES)) {
    b <- STOP_CASES[[n]]$edit(toy())
    expect_error(run_compendium(b, out_dir()), STOP_CASES[[n]]$pattern, class = "seqcompendium_stop", info = n)
  }
})

test_that("E1-M2: with no guide, a draft guide with facts only is written first", {
  b <- STOP_CASES$no_guide$edit(toy()); o <- out_dir()
  expect_error(run_compendium(b, o), class = "seqcompendium_stop")
  d <- rd(file.path(o, "00_input_check", "column_guide_draft.csv"))
  expect_setequal(d$column, c("subject", "group", "day", "run", "kind"))
  expect_true(all(d$role == "" & d$type == ""))
})

test_that("E1-M3: these must not stop (5 cases, plus missing_codes none)", {
  ok <- function(b) expect_no_error(run_compendium(b, out_dir()))
  ok(toy())
  b <- toy(); for (f in c(META, GUIDE)) { p <- file.path(b, f); writeLines(paste0(readLines(p), "\r"), p, sep = "\n") }; ok(b)   # CRLF
  ok(add_column(toy(), "notes", c("fine", "check later", ""), "ignore", "text"))
  ok(toy("no_controls"))
  ok(add_column(toy(), "cage", c("A1", "A2", "A3"), "block", "categorical"))
  # missing_codes none confirms 99 is a real value (seq-triage reads it as empty: CLAUDE.md D6).
  ok(add_column(toy(), "weight", c("20.1", "99", "21.0"), "outcome", "continuous", missing_codes = "none"))
})

test_that("E1-M13: with the one-keystroke check off, exactly its case fails", {
  old <- options(seqcompendium.disable_one_keystroke = TRUE); on.exit(options(old))
  res <- vapply(STOP_CASES, stops_as_expected, TRUE)
  expect_equal(names(res)[!res], "one_keystroke_typo")
})
