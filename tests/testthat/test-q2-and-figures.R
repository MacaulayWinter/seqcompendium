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
  expect_true("03_results/Q2_alpha/per_sample.csv" %in% idx$source_csv)
  expect_true(all(file.exists(file.path(target, idx$figure))))
  expect_true(all(mapply(function(s, c) grepl(s, c, fixed = TRUE), idx$source_csv, idx$caption)))
})

test_that("D50: each PCoA panel's shares are in (0, 1], axis 1 >= axis 2, and its title shows them", {
  o <- out_dir(); run_compendium(toy(), o)
  d <- rd(file.path(o, "03_results", "Q3_composition", "ordination.csv"))
  for (k in c("axis1_share", "axis2_share", "negative_eigen_share")) d[[k]] <- as.numeric(d[[k]])
  p <- unique(d[, c("layer", "predictor", "contrast", "timepoint", "block", "axis1_share", "axis2_share", "negative_eigen_share")])
  expect_equal(nrow(p), nrow(unique(p[, 1:5])))   # one value per panel
  expect_true(all(p$axis1_share > 0 & p$axis1_share <= 1 & p$axis2_share > 0 & p$axis2_share <= 1))
  expect_true(all(p$axis1_share >= p$axis2_share))
  expect_true(all(p$negative_eigen_share >= 0))
  x <- d[d$layer == d$layer[1] & d$predictor == d$predictor[1], , drop = FALSE]
  g <- seqcompendium:::q3_plot(x, x$predictor[1], x$layer[1], "src")$plot
  strips <- as.character(ggplot2::ggplot_build(g)$layout$layout$panel)
  px <- unique(x[, c("timepoint", "axis1_share", "axis2_share")])
  for (i in seq_len(nrow(px)))
    expect_true(any(grepl(sprintf("Axis 1: %.0f%%, Axis 2: %.0f%%", 100 * px$axis1_share[i], 100 * px$axis2_share[i]), strips, fixed = TRUE) &
                    grepl(px$timepoint[i], strips, fixed = TRUE)), info = paste(strips, collapse = " | "))
  idx <- rd(file.path(o, "figures", "figures_index.csv"))
  expect_true(any(grepl("not by eye", idx$caption[idx$source_csv == "03_results/Q3_composition/ordination.csv"])))
})
