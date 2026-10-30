# E5 pass marks (CLAUDE.md D25): longitudinal models, Q6, adjustment (D24).

test_that("E5-M1: longitudinal Q2 and Q4 come from mixed models, one contrast per timepoint", {
  x <- run_fixture("main")
  q2 <- res_csv(x, "03_results/Q2_alpha/results.csv"); q4 <- res_csv(x, "03_results/Q4_differential/results.csv")
  expect_true(all(q2$method_id %in% c("L01", "K02")) && any(q2$method_id == "L01"))
  expect_true(any(q4$method_id == "L02") && all(q4$method_id %in% c("L02", "R02mm", "K04")))
  expect_setequal(unique(q4$timepoint), c("T0", "T1")); expect_false(any(c(q2$timepoint, q4$timepoint) == "all"))
  l <- run_fixture("long_planted")$l
  p <- l[l$question == "Q4" & l$feature %in% sprintf("toyG%02d", 6:8), ]
  expect_true(all(p$status[p$timepoint == "T1"] == "lead")); expect_false(any(p$status[p$timepoint == "T0"] == "lead"))
})

test_that("E5-M2: Q6 finds the treated change and not the control one", {
  x <- run_fixture("long_planted")
  f <- res_csv(x, "03_results/Q6_change/features.csv"); f <- f[f$feature %in% sprintf("toyG%02d", 6:8), ]
  expect_true(all(f$status[f$group == "treated"] == "lead")); expect_false(any(f$status[f$group == "control"] == "lead"))
  cp <- res_csv(x, "03_results/Q6_change/composition.csv")
  expect_true(all(cp$method_id == "B06s")); expect_equal(cp$status[cp$group == "treated"], "lead"); expect_equal(cp$status[cp$group == "control"], "no_evidence")
  a <- res_csv(run_fixture("long_div"), "03_results/Q6_change/alpha.csv"); a <- a[a$q_order %in% 1:2, ]
  expect_true(all(a$status[a$group == "treated"] == "lead")); expect_false(any(a$status[a$group == "control"] == "lead"))
  l <- run_fixture("planted_da")$l
  expect_equal(l$status[l$question == "Q6"], "not_testable"); expect_match(l$caveats[l$question == "Q6"], "not longitudinal")
})

test_that("E5-M3: too few subjects gives per-timepoint analyses and says why Q6 is not testable", {
  x <- run_fixture("few_subjects"); l <- x$l
  expect_equal(l$status[l$question == "Q6"], "not_testable"); expect_match(l$caveats[l$question == "Q6"], "fewer than 5 \\(R-RE\\)")
  q2 <- l[l$question == "Q2", ]
  expect_false(any(grepl("mixed model", q2$method)))
})

test_that("E5-M4: adjustment removes an effect that belongs to another predictor", {
  x <- run_fixture("adjust"); q4 <- res_csv(x, "03_results/Q4_differential/results.csv")
  pf <- sprintf("toyG%02d", 6:8)
  expect_false(any(q4$status[q4$predictor == "group" & q4$feature %in% pf] == "lead"))
  expect_true(all(q4$status[q4$predictor == "diet" & q4$feature %in% pf] == "lead"))
  expect_true(all(grepl("adjusted for run, diet", q4$adjusted_for[q4$predictor == "group" & q4$method_id == "D01"])))
  b <- toy("adjust"); edit(b, GUIDE, function(g) { g$role[g$column == "diet"] <- "ignore"; g })
  o <- out_dir(); run_compendium(b, o); u <- res_csv(list(o = o), "03_results/Q4_differential/results.csv")
  expect_true(any(u$status[u$predictor == "group" & u$feature %in% pf] == "lead"))
})

test_that("E5-M5: the safeguard and confounding are stated", {
  q4 <- res_csv(run_fixture("main"), "03_results/Q4_differential/results.csv")
  expect_true(all(grepl("not adjusted: 24 samples for 5 parameters, fewer than 5 per parameter \\(R-SPP\\)|cannot adjust|per-timepoint|paired", q4$adjusted_for)))
  qc <- res_csv(run_fixture("confounded_batch"), "03_results/Q4_differential/results.csv")
  expect_true(all(grepl("left out: `run` \\(confounded with `group`", qc$adjusted_for[qc$method_id == "D01"])))
})

test_that("E5-M6: GEE with 40 subjects only; GAMM with 4 timepoints only; paired Wilcoxon for Q6", {
  expect_true(any(res_csv(run_fixture("long_zeroinfl"), "04_agreement/Q4.csv")$method_id == "L03"))
  x <- run_fixture("main")
  expect_false(any(res_csv(x, "04_agreement/Q4.csv")$method_id == "L03"))
  expect_true(any(grepl("GEE \\(L03\\), which runs only with at least 40 subjects \\(here 12\\)", readLines(file.path(x$o, "report", "compendium_report.md")))))
  expect_true(any(res_csv(run_fixture("long4tp"), "04_agreement/Q6_alpha.csv")$method_id == "L04"))
  a <- res_csv(x, "04_agreement/Q6_alpha.csv")
  expect_false(any(a$method_id == "L04")); expect_true(any(a$method_id == "K02p"))
})

test_that("E5-M7: mixed-model checks flag zero-heavy features, refit at rung 1, with the chance wording", {
  x <- run_fixture("long_zeroinfl")
  ch <- res_csv(x, "03_results/Q4_differential/diagnostics.csv"); q4 <- res_csv(x, "03_results/Q4_differential/results.csv")
  zf <- sprintf("toyG%02d", 9:23)
  expect_gt(sum(ch$failed[ch$feature %in% zf]), 0)
  expect_equal(sum(ch$failed[!ch$feature %in% zf & !ch$feature %in% sprintf("toyG%02d", 26:30)]), 0)
  moved <- q4[q4$feature %in% ch$feature[ch$failed], ]
  expect_true(all(moved$rung >= 1 & grepl("clearly more than chance|may have moved by chance", moved$caveat)))
  expect_true(all(is.finite(q4$excess_failures_p)))
})

test_that("E5-M8: byte-identical CSVs for a longitudinal run", {
  b <- toy("long_planted"); o1 <- out_dir(); o2 <- out_dir(); run_compendium(b, o1); run_compendium(b, o2)
  csv <- list.files(o1, pattern = "\\.csv$", recursive = TRUE)
  expect_true("03_results/Q6_change/features.csv" %in% csv)
  expect_equal(unname(tools::md5sum(file.path(o2, csv))), unname(tools::md5sum(file.path(o1, csv))))
})
