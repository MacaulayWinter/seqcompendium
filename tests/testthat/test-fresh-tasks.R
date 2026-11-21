# The fresh-template task list (V-E7(c) planted truth, PREREGISTRATION.md 9.4): 39 scenarios, 200 runs each,
# 2 runs per task on shotgun templates and 1 run per task on 16S templates. The ordinary list must not change.
vroot <- test_path("..", "..", "validation")
skip_if_not(file.exists(file.path(vroot, "R", "tasks.R")), "validation folder not in this build")
source(file.path(vroot, "R", "scenarios.R")); source(file.path(vroot, "R", "tasks.R"))
sc <- scenarios()

test_that("the ordinary list is exactly what it was before (7,360 tasks, same bytes)", {
  t <- make_task_table(sc, per = 2L)
  expect_equal(nrow(t), 7360L)
  f <- tempfile(); utils::write.table(t, f, sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
  expect_equal(unname(tools::md5sum(f)), "27633b1aedc04d1861511e9f7eb5c5bb")
})

test_that("the fresh list holds the 39 approved scenarios, in two blocks: shotgun first, then 16S3", {
  t <- make_task_table(sc, per = 2L, fresh = TRUE)
  expect_setequal(unique(t$scenario), c(12:35, 48:59, 72, 73, 75))
  expect_equal(length(unique(t$scenario)), 39L)
  expect_equal(nrow(t), 5200L)
  tmpl <- sc$template[match(t$scenario, sc$scenario)]
  is16 <- tmpl == "16S1"
  expect_true(all(!is16[seq_len(2600)])); expect_true(all(is16[2601:5200]))   # one contiguous range per memory class
  expect_equal(sum(!is16), 2600L); expect_equal(sum(is16), 2600L)
})

test_that("every scenario covers runs 1-200 exactly once; 16S3 tasks are 1 run, shotgun tasks are 2", {
  t <- make_task_table(sc, per = 2L, fresh = TRUE)
  for (s in unique(t$scenario)) {
    x <- t[t$scenario == s, ]; runs <- unlist(mapply(seq, x$first, x$last, SIMPLIFY = FALSE))
    expect_equal(sort(runs), 1:200, info = paste("scenario", s))
    w <- x$last - x$first + 1L
    expect_true(all(w == if (sc$template[sc$scenario == s] == "16S1") 1L else 2L), info = paste("scenario", s))
  }
})

test_that("no V-E1, V-E2b, V-E5, shotgun3 or 16S2 scenario is in the fresh list", {
  t <- make_task_table(sc, per = 2L, fresh = TRUE)
  m <- sc[match(unique(t$scenario), sc$scenario), ]
  expect_true(all(m$mark %in% c("V-E3", "V-E4"))); expect_false(any(m$template %in% c("shotgun3", "16S2")))
})
