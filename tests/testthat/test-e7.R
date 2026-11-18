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

test_that("a method that stops keeps its own error message in the agreement note (V-E7b, D55)", {
  ud <- list(m = matrix(1:20, 4, dimnames = list(paste0("s", 1:4), paste0("f", 1:5))), g = factor(c("A", "A", "B", "B")))
  a <- seqcompendium:::q4_agreement(ud, colnames(ud$m), "NOT_A_METHOD")   # FITS has no such method, so the call errors
  expect_true(all(is.na(a$p)))
  expect_true(all(grepl("^the method failed to fit: .+", a$note)))
  expect_false(any(a$note == "the method failed to fit"))                 # the old note, with no reason
  n <- seqcompendium:::fit_failed_note(c("line one\n  line two", "x"))
  expect_identical(n, "the method failed to fit: line one line two x")
  expect_lte(nchar(seqcompendium:::fit_failed_note(strrep("a", 1000))), 330)
  expect_identical(seqcompendium:::fit_failed_note(""), "the method failed to fit: no error message")
})

test_that("LEfSe runs on rare features: input per million, not 0-1 (V-E7b, D55)", {
  # 10 v 10 samples of 1e6 reads; f_rare differs (about 5 v 2000 reads), so its
  # proportions (5e-6 v 2e-3) vary far less than MASS::lda's tolerance on a 0-1
  # scale, which made lefser stop with "variables ... appear to be constant within groups".
  # 2000, not a smaller difference: lefser lists features with LDA score >= 2 (its
  # default, which the engine keeps); in the check of 2026-11-12, B means of 60, 500
  # and 2000 reads gave f_rare scores 1.75, 2.66 and 3.21, and the old scale stopped in all three.
  set.seed(1)
  n <- 20; g <- factor(rep(c("A", "B"), each = n / 2))
  rare <- ifelse(g == "A", rpois(n, 5), rpois(n, 2000)); other <- matrix(rpois(n * 6, 50), n)
  m <- cbind(f_rare = rare, other, f_big = 1e6 - rare - rowSums(other))
  colnames(m)[2:7] <- paste0("f", 1:6); rownames(m) <- paste0("s", seq_len(n))
  r <- seqcompendium:::describe_lefse(list(m = m, g = g, samples = rownames(m)), colnames(m))
  expect_false(any(grepl("did not run", r$note)), info = paste(unique(r$note), collapse = " | "))
  expect_true("f_rare" %in% r$feature)
  # The old 0-1 scale on the same data: lefser stops (kept as the record of the defect).
  rel <- t(m / rowSums(m))
  se <- SummarizedExperiment::SummarizedExperiment(assays = list(rel = rel), colData = S4Vectors::DataFrame(g = g, row.names = rownames(m)))
  old <- tryCatch(suppressMessages(suppressWarnings(lefser::lefser(se, classCol = "g", assay = "rel"))), error = function(e) conditionMessage(e))
  expect_true(is.character(old) && grepl("constant within groups", old))
})
