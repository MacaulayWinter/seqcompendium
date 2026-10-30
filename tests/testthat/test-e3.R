# E3 pass marks (CLAUDE.md D12). Fixtures from make_toy_bundle(); answers known.

test_that("E3-M1: the catalogue has every row, a role for each, and F1/F3/C5 as decided", {
  cat <- seqcompendium:::catalogue()
  expect_equal(nrow(cat), 115L)
  expect_true(all(c("role", "question", "needs_unit", "needs", "handles_repeated", "min_group", "priority") %in% names(cat)))
  expect_true(all(nzchar(cat$role)))
  expect_setequal(cat$id[cat$role == "describe_only"], c("B09", "B17", "D19"))
  gh <- c("N08", "D12", "D16", "L06", "L07", "C04", "G04", "T02")
  expect_true(all(cat$role[cat$id %in% gh] == "excluded" & grepl("GitHub-only, not on the F3 list", cat$engine_note[cat$id %in% gh])))
  c5 <- c("M01", "M02", "M03", "C01", "C02", "C03", "X05", "X06")
  expect_true(all(cat$role[cat$id %in% c5] == "excluded" & grepl("not in v1 \\(C5", cat$engine_note[cat$id %in% c5])))
})

test_that("E3-M2: the filter lists every method with its reason", {
  mc <- res_csv(run_fixture("main"), "02_method_choice/methods_considered.csv")
  expect_equal(nrow(mc), 115L)
  expect_true(all(mc$eligible %in% c("yes", "no")))
  expect_true(all(nzchar(mc$reason[mc$eligible == "no"])))
  cat <- seqcompendium:::catalogue()
  tree <- cat$id[cat$needs == "tree" & cat$role != "excluded"]
  expect_true(all(grepl("needs tree", mc$reason[mc$id %in% tree]) | grepl("needs unit", mc$reason[mc$id %in% tree])))
  mp <- res_csv(run_fixture("proportions"), "02_method_choice/methods_considered.csv")
  count_only <- cat$id[cat$needs_unit == "count" & cat$role != "excluded"]
  expect_true(all(mp$eligible[mp$id %in% count_only] == "no" & grepl("needs unit count", mp$reason[mp$id %in% count_only])))
})

test_that("E3-M3: the Q4 default follows the denominator", {
  # A snapshot fixture: E3's defaults are the snapshot path (main is longitudinal since E5, D26).
  ch <- res_csv(run_fixture("planted_da"), "02_method_choice/choices.csv")
  expect_equal(ch$default_id[ch$question == "Q4"], "D01"); expect_match(ch$rests_on[ch$question == "Q4"], "has a denominator")
  ch <- res_csv(run_fixture("no_denominator"), "02_method_choice/choices.csv")
  expect_equal(ch$default_id[ch$question == "Q4"], "D09"); expect_match(ch$rests_on[ch$question == "Q4"], "no denominator")
})

test_that("E3-M4: contaminants flagged, kept, never tier 1; no negatives gives not_testable", {
  x <- run_fixture("main")
  q0 <- res_csv(x, "03_results/Q0_contaminants/results.csv")
  expect_gte(sum(q0$possible_contaminant[q0$feature %in% sprintf("toyG%02d", 26:30)]), 4)
  flagged <- q0$feature[q0$possible_contaminant]
  q4 <- res_csv(x, "03_results/Q4_differential/results.csv")
  expect_true(all(flagged[flagged %in% q4$feature] %in% q4$feature))
  l <- x$l
  fl <- l[l$question %in% c("Q4", "Q5") & l$feature %in% flagged, ]
  expect_true(nrow(fl) > 0)
  expect_true(all(grepl("possible_contaminant", fl$flags)))
  expect_false(any(l$tier %in% 1L))
  l2 <- run_fixture("no_controls")$l
  expect_equal(l2$status[l2$question == "Q0"], "not_testable")
})

test_that("E3-M5: PERMANOVA with betadisper; planted shift is a lead; copy is not; spread hands over to mvabund", {
  q3 <- res_csv(run_fixture("main"), "03_results/Q3_composition/results.csv")
  expect_true(all(is.finite(q3$permanova_p) & is.finite(q3$betadisper_p)))
  expect_true(all(run_fixture("planted")$l$status[run_fixture("planted")$l$question == "Q3"] == "lead"))
  expect_true(all(run_fixture("copy_null")$l$status[run_fixture("copy_null")$l$question == "Q3"] == "no_evidence"))
  sp <- res_csv(run_fixture("spread"), "03_results/Q3_composition/results.csv")
  hit <- sp$spread_differs & sp$unbalanced
  expect_true(any(hit))
  expect_true(all(sp$primary[hit] == "B14 mvabund" & grepl("location and spread cannot be separated", sp$caveat[hit])))
})

test_that("E3-M6: planted features are Q4 leads; the copy has none; agreement per feature; LEfSe describe-only", {
  x <- run_fixture("planted_da"); l <- x$l
  q4l <- l[l$question == "Q4" & l$status == "lead", ]
  expect_true(all(sprintf("toyG%02d", 6:8) %in% q4l$feature))
  # "By the default" includes its fallback ladder (CLAUDE.md D15): never an
  # agreement or comparison-only method, never "fit failed".
  expect_true(all(grepl("^(default|fallback rung [12])$", q4l$method_role[q4l$feature %in% sprintf("toyG%02d", 6:8)])))
  expect_false(any(run_fixture("copy_null")$l$question == "Q4" & run_fixture("copy_null")$l$status == "lead"))
  ag <- res_csv(x, "04_agreement/Q4.csv")
  q4 <- res_csv(x, "03_results/Q4_differential/results.csv")
  expect_true(all(table(paste(ag$timepoint, ag$feature)) == 3L))
  expect_setequal(unique(ag$method_id), c("D09", "D04", "D17"))
  ds <- res_csv(x, "04_agreement/Q4_describe_only.csv")
  expect_true(all(ds$method_id == "D19" & ds$role == "describe_only"))
  expect_false(any(grepl("LEfSe", l$method)))
})

test_that("E3-M7: a feature present only in treated samples is a Q5 lead by Firth, with Fisher alongside", {
  x <- run_fixture("presence")
  q5 <- res_csv(x, "03_results/Q5_presence/results.csv")
  g15 <- q5[q5$feature == "toyG15", ]
  expect_true(nrow(g15) >= 1 && all(g15$status == "lead" & g15$method_id == "G06"))
  ag <- res_csv(x, "04_agreement/Q5.csv")
  expect_true(all(ag$method_id[ag$feature == "toyG15"] == "K03"))
})

test_that("E3-M8: the planted set is a Q7 lead; no set is on the copy", {
  l <- run_fixture("planted_da")$l
  expect_true(any(l$question == "Q7" & l$status == "lead" & l$feature == "set toy_class = planted"))
  l0 <- run_fixture("copy_null")$l
  expect_false(any(l0$question == "Q7" & l0$status == "lead"))
})

test_that("E3-M9: zero-inflated features are flagged and refitted; over R-DIAG moves the whole question", {
  x <- run_fixture("zeroinfl_few")
  ch <- res_csv(x, "03_results/Q4_differential/diagnostics.csv")
  zf <- sprintf("toyG%02d", 9:11)
  expect_true(all(zf %in% ch$feature[ch$failed]))
  q4 <- res_csv(x, "03_results/Q4_differential/results.csv")
  moved <- q4[q4$feature %in% ch$feature[ch$failed] & paste(q4$timepoint, q4$feature) %in% paste(ch$timepoint, ch$feature)[ch$failed], ]
  expect_true(all(moved$rung >= 1 & grepl("rung", moved$caveat)))
  # The user asked that every move says it may be chance (CLAUDE.md D16).
  expect_true(all(grepl("may have moved by chance|clearly more than chance", moved$caveat)))
  y <- res_csv(run_fixture("zeroinfl_many"), "03_results/Q4_differential/results.csv")
  # Since D17 the whole comparison moves when failures clearly exceed chance.
  w <- y[y$excess_failures_p < 0.05, ]
  expect_true(nrow(w) > 0 && all(w$whole_question_moved & w$rung >= 1 & grepl("whole question moved", w$caveat)))
  expect_true(all(!y$whole_question_moved[y$excess_failures_p >= 0.05]))
  expect_true(all(y$status != "not_testable" | grepl("listed, not dropped", y$caveat)))
})

test_that("E3-M10: leads carry method, role, agreement; tier 2 needs q <= R-FDR; no tier 1", {
  l <- run_fixture("planted_da")$l
  t <- l[l$question %in% c("Q2", "Q3", "Q4", "Q5", "Q7") & l$status %in% c("lead", "no_evidence"), ]
  expect_true(all(!is.na(t$method) & !is.na(t$method_role) & grepl("^[0-9]+/[0-9]+$", t$agreement) &
                  t$agreement_label %in% c("agreed", "partly agreed", "disagreed", "not testable")))
  expect_true(all(l$q[l$tier %in% 1:2] <= 0.10))
  # Since E6 a lead can be tier 1, but only when leave-one-out says it is stable (D29b, D31).
  expect_true(all(l$loo_stable[l$tier %in% 1L] == "yes"))
  expect_true(any(l$question == "Q0"))
})

test_that("E3-M12: byte-identical CSVs, including the random steps", {
  b <- toy("planted_da"); o1 <- out_dir(); o2 <- out_dir()
  run_compendium(b, o1); run_compendium(b, o2)
  csv <- list.files(o1, pattern = "\\.csv$", recursive = TRUE)
  expect_gt(length(csv), 15)
  expect_equal(unname(tools::md5sum(file.path(o2, csv))), unname(tools::md5sum(file.path(o1, csv))))
})
