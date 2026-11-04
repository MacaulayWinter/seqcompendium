# E7 regressions (CLAUDE.md D38).

test_that("tables from two comparisons with different columns bind, missing columns NA (D38)", {
  a <- data.frame(contrast = "B vs A", feature = "f1", p = 0.1)
  b <- data.frame(contrast = "C vs A", feature = "f2", p = 0.2, rung = 2)
  x <- seqcompendium:::bind_rows(list(a, NULL, b))
  expect_equal(names(x), c("contrast", "feature", "p", "rung"))
  expect_equal(x$rung, c(NA, 2))
  expect_identical(seqcompendium:::bind_rows(list(a, a)), rbind(a, a))   # same columns: unchanged
  expect_null(seqcompendium:::bind_rows(list(NULL)))
})
