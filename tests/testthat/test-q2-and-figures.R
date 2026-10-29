# E1-M7: Q2 behaves on fixtures whose answer is known. E1-M10: figures read CSVs only.

test_that("E1-M7: identical groups give no_evidence on every Q2 row", {
  l <- run_compendium(toy("copy_null"), out_dir())
  q2 <- l[l$question == "Q2", ]
  expect_equal(nrow(q2), 6L)
  expect_true(all(q2$status == "no_evidence"))
})

test_that("E1-M7: a planted large diversity difference is a lead at q = 1 and q = 2", {
  l <- run_compendium(toy("planted"), out_dir())
  q2 <- l[l$question == "Q2" & grepl("q = [12]$", l$feature), ]
  expect_equal(nrow(q2), 4L)
  expect_true(all(q2$status == "lead"))
  expect_false(any(l$timepoint %in% "all"))
})

test_that("E1-M10: figures are drawn in a fresh R process from the CSVs alone", {
  b <- toy(); o <- out_dir(); run_compendium(b, o)
  copy <- tempfile("copy"); dir.create(copy)
  file.copy(o, copy, recursive = TRUE); unlink(b, recursive = TRUE); unlink(o, recursive = TRUE)
  target <- file.path(copy, basename(o)); unlink(file.path(target, "figures"), recursive = TRUE)
  root <- normalizePath(test_path("..", ".."), mustWork = FALSE)
  code <- sprintf("if (!requireNamespace('seqcompendium', quietly = TRUE) || !nzchar(system.file(package = 'seqcompendium'))) pkgload::load_all('%s', quiet = TRUE) else library(seqcompendium); draw_figures('%s')", root, target)
  st <- system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)), stdout = TRUE, stderr = TRUE)
  expect_null(attr(st, "status"), info = paste(st, collapse = "\n"))
  idx <- rd(file.path(target, "figures", "figures_index.csv"))
  expect_equal(nrow(idx), 1L)
  expect_true(file.exists(file.path(target, idx$figure)))
  expect_equal(idx$source_csv, "03_results/Q2_alpha/per_sample.csv")
  expect_true(grepl(idx$source_csv, idx$caption, fixed = TRUE))
})
