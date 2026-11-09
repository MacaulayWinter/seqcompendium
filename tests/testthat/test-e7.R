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

test_that("DivNet is skipped, with a note, above R-DIVNETMAX features; A01 still runs (D42)", {
  ns <- asNamespace("seqcompendium"); cache <- get(".rules_cache", ns)
  seqcompendium:::rules(); old <- cache$r
  on.exit({ cache$r <- old; suppressMessages(untrace("q2_agreement", where = ns)) })
  low <- old; low$rules$`R-DIVNETMAX`$value <- 5; cache$r <- low   # the toy has more than 5 features
  got <- new.env()
  suppressMessages(trace("q2_agreement", where = ns, print = FALSE, exit = bquote(assign("a2", returnValue(), envir = .(got)))))
  run_compendium(toy("copy_null"), out_dir())
  a4 <- got$a2[got$a2$method_id == "A04", ]
  expect_gt(nrow(a4), 0)
  expect_true(all(grepl("^DivNet not run: [0-9]+ features, more than 5 \\(rule R-DIVNETMAX", a4$note)))
  expect_true(all(is.na(a4$p)))
  expect_true(all(is.finite(as.numeric(got$a2$p[got$a2$method_id == "A01"]))))
})
