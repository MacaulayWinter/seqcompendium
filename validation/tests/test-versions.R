# The environment's version check (validation/grid/versions.R; CLAUDE.md D46).
source(if (file.exists("validation/grid/versions.R")) "validation/grid/versions.R" else "../grid/versions.R")

test_that("a hyphenated locked version equals its dotted form (D46)", {
  want <- c(BH = "1.90.0-1", DEoptimR = "1.2-2", MASS = "7.3-66", stringi = "1.8.7")
  got <- c(BH = "1.90.0.1", DEoptimR = "1.2.2", MASS = "7.3.66", stringi = "1.8.7")
  expect_identical(versions_differ(want, got), character(0))
})

test_that("a real difference, or a missing package, is still caught (D46)", {
  want <- c(a = "1.2-2", b = "2.0.0", c = "0.5")
  got <- c(a = "1.2.3", b = "missing", c = "0.5")
  expect_identical(versions_differ(want, got), c("a", "b"))
})
