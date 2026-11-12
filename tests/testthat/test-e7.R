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

test_that("a sample with no counts is left out of the layer with a note, and the run completes (D49)", {
  b <- toy("copy_null"); o <- out_dir()
  first <- rd(file.path(b, META))$sample[rd(file.path(b, META))$kind == "none"][1]
  edit(b, LAYER, function(x) { x$value[x$sample == first] <- "0"; x })
  run_compendium(b, o)
  chk <- rd(file.path(o, "00_input_check", "bundle_check.csv"))
  expect_true(any(grepl(sprintf("total of 0 in layer `toy_counts`.*%s", first), chk$message)))
  ps <- rd(file.path(o, "03_results", "Q2_alpha", "per_sample.csv"))
  expect_false(first %in% ps$sample)
  expect_gt(nrow(ps), 0)
})

test_that("not_estimable() names a feature with no counts in a cell, and only that one (D51)", {
  m <- cbind(a = c(0, 0, 3, 4), b = c(1, 0, 2, 5), c = c(2, 1, 0, 0))
  x <- seqcompendium:::not_estimable(m, factor(c("ctl", "ctl", "trt", "trt")))
  expect_equal(names(x), c("a", "c"))
  expect_match(x[["a"]], "no counts in ctl")
  expect_match(x[["c"]], "no counts in trt")
})

test_that("a longitudinal feature with no counts in a group at a timepoint is not fitted; its rows say why (D51)", {
  o <- out_dir(); run_compendium(toy(), o)          # the main toy: toyG28 and toyG29 have no counts in treated at T1
  q4 <- rd(file.path(o, "03_results", "Q4_differential", "results.csv"))
  r <- q4[q4$feature %in% c("toyG28", "toyG29"), ]
  expect_gt(nrow(r), 0)
  expect_true(all(r$method_role == "not estimable"))
  expect_true(all(r$effect %in% c("", "NA") & r$p %in% c("", "NA")))
  expect_true(all(grepl("no counts in treated at T1", r$caveat)))
  expect_true(any(q4$method_role == "default"))       # the other features are still fitted
})

test_that("a snapshot feature with no counts in one group is not fitted by DESeq2 (D51)", {
  b <- toy("calib"); md <- rd(file.path(b, META)); lv <- sort(unique(md$group[md$kind == "none"]))
  lvl <- md$sample[md$kind == "none" & md$group == lv[2]]
  edit(b, LAYER, function(x) { x$value[x$feature == "toyG01" & x$sample %in% lvl] <- "0"; x })
  o <- out_dir(); run_compendium(b, o)
  q4 <- rd(file.path(o, "03_results", "Q4_differential", "results.csv"))
  r <- q4[q4$feature == "toyG01", ]
  expect_equal(unique(r$method_role), "not estimable")
  expect_match(r$caveat[1], sprintf("no counts in %s", lv[2]))
})

test_that("in the zero-inflated fixture, a feature emptied in one group x timepoint cell is reported not estimable (D51; the old E3-M9 data's case)", {
  b <- toy("zeroinfl_many"); md <- rd(file.path(b, META))
  cell <- md$sample[md$kind == "none" & md$group == "treated" & md$day == "T1"]
  edit(b, LAYER, function(x) { x$value[x$feature == "toyG09" & x$sample %in% cell] <- "0"; x })
  o <- out_dir(); run_compendium(b, o)
  q4 <- rd(file.path(o, "03_results", "Q4_differential", "results.csv"))
  r <- q4[q4$feature == "toyG09" & q4$timepoint == "T1", ]   # this fixture is compared at each timepoint separately
  expect_equal(nrow(r), 1L)
  expect_true(r$method_role == "not estimable" && grepl("no counts in treated", r$caveat))
  expect_false(any(q4$method_role[q4$feature == "toyG09" & q4$timepoint == "T0"] == "not estimable"))
})

test_that("Q2's DivNet gives the same result on the first call of an R session as on later ones (V-E10, D53)", {
  # snow draws random numbers when it loads, and DivNet loads it on its first call
  # even with ncores = 1; the engine loads it before setting the seed. Checked in a
  # fresh R process, because this one may have loaded snow already.
  skip_if(!nzchar(system.file(package = "seqcompendium")), "needs the installed package")
  f <- tempfile(fileext = ".R"); o <- tempfile(fileext = ".rds")
  writeLines(c("suppressPackageStartupMessages(library(seqcompendium)); e <- asNamespace('seqcompendium')",
               "b <- file.path(tempdir(), 'toy'); make_toy_bundle(b)",
               "bb <- e$read_bundle(b); g0 <- e$check_guide(bb$md, bb$guide); lc <- e$check_layers(bb$layers, g0$md)",
               "des <- e$read_design(g0$md, bb$guide, g0$info); un <- e$contrast_units(lc$layers, des, e$design_cells(des))",
               "first <- !'snow' %in% loadedNamespaces()",
               "r1 <- e$q2_agreement(un, lc$layers, des); r2 <- e$q2_agreement(un, lc$layers, des)",
               sprintf("saveRDS(list(first = first, r1 = r1, r2 = r2), '%s')", o)), f)
  status <- system2(file.path(R.home("bin"), "Rscript"), f, stdout = FALSE, stderr = FALSE)
  expect_identical(status, 0L)
  x <- readRDS(o)
  expect_true(x$first)                                     # the first call really was the session's first
  a1 <- x$r1[x$r1$method_id == "A04", ]; a2 <- x$r2[x$r2$method_id == "A04", ]
  expect_gt(sum(is.finite(as.numeric(a1$p))), 0)
  expect_identical(a1, a2)
})

test_that("loading snow draws random numbers, which is why it is loaded before the seed (D53)", {
  skip_if_not_installed("snow")
  # A fresh R process, so snow is not loaded yet.
  out <- system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote("set.seed(1); a <- runif(1); set.seed(1); invisible(loadNamespace('snow')); cat(identical(a, runif(1)))")), stdout = TRUE, stderr = FALSE)
  expect_identical(utils::tail(out, 1), "FALSE")
})
