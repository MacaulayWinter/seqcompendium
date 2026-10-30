# E6 pass marks (CLAUDE.md D29, D30): leave-one-out, tiers, minimum detectable
# effect, p-value floors, the report in full.

mde_num <- function(x) suppressWarnings(as.numeric(sub(" \\(log2 fold change\\)$", "", x)))

test_that("E6-M1: a lead one sample makes is unstable and tier 2; planted leads are stable", {
  l <- run_fixture("fragile")$l
  g <- l[l$feature == "toyG12" & l$question == "Q4" & l$status == "lead", ]
  expect_gte(nrow(g), 1)
  expect_true(all(grepl("^no: depends on sample S[0-9]+_T[01]", g$loo_stable) & g$tier == 2L))
  p <- run_fixture("planted_da")$l
  expect_true(all(p$loo_stable[p$question == "Q4" & p$status == "lead" & p$feature %in% sprintf("toyG%02d", 6:8)] == "yes"))
})

test_that("E6-M2: tiers follow the rule in every fixture", {
  for (v in c("planted_da", "fragile", "calib", "long_planted", "main")) {
    l <- run_fixture(v)$l
    lead <- l$status == "lead"
    clean <- lead & l$agreement_label == "agreed" & l$loo_stable == "yes" & l$method_role == "default" &
             !grepl("possible_contaminant|thin_evidence|no_benchmark", ifelse(is.na(l$flags), "", l$flags))
    expect_true(all(l$tier[clean] == 1L), info = v); expect_true(all(l$tier[lead & !clean] == 2L), info = v)
    ne <- l$status == "no_evidence"; m <- mde_num(l$min_detectable_effect)
    t3 <- ne & is.finite(m) & is.finite(l$effect) & abs(l$effect) >= m
    expect_true(all(l$tier[t3] == 3L), info = v); expect_true(all(l$tier[ne & !t3] == 4L), info = v)
    r <- l[!is.na(l$rank), ]; expect_false(is.unsorted(r$tier), info = v)
  }
  expect_true(any(run_fixture("planted_da")$l$tier %in% 1L))
})

test_that("E6-M3: the minimum detectable effect where the simulation ran, and a reason where not", {
  x <- run_fixture("calib")
  q4 <- x$l[x$l$question == "Q4" & x$l$status %in% c("lead", "no_evidence"), ]
  expect_true(all(is.finite(mde_num(q4$min_detectable_effect))))
  md <- readLines(file.path(x$o, "report", "compendium_report.md"))
  i <- grep("^## [0-9]+\\. What was not found", md); j <- grep("^## [0-9]+\\. Leads", md)
  expect_true(any(grepl("was found with 80% power", md[i:j])))
  p <- run_fixture("planted_da")$l
  expect_true(all(grepl("^not available", p$min_detectable_effect[p$question == "Q4" & p$status %in% c("lead", "no_evidence")])))
})

test_that("E6-M4: p-value floors match an independent computation; a floor above R-FDR is said", {
  seen <- 0
  for (v in c("planted_da", "zeroinfl_many", "no_denominator", "long_zeroinfl", "main")) {
    l <- run_fixture(v)$l
    n <- regmatches(l$n_per_group, gregexpr("[0-9]+", l$n_per_group))
    for (i in which(grepl("Wilcoxon|permutation", l$method) & !grepl("PERMANOVA", l$method) & l$status %in% c("lead", "no_evidence"))) {
      k <- as.numeric(n[[i]])
      want <- if (grepl("permutation", l$method[i])) 1 / 1000 else if (grepl("paired", l$method[i])) 2 / 2^k[1] else 2 / choose(sum(k), k[1])
      expect_equal(l$p_floor[i], want, info = paste(v, l$lead_id[i])); seen <- seen + 1
    }
  }
  expect_gt(seen, 0)
  expect_equal(seqcompendium:::p_floor_of("K02p", 3), 0.25)
  expect_match(seqcompendium:::floor_caveat(0.25), "this design cannot reach significance")
  expect_null(seqcompendium:::floor_caveat(0.001))
})

test_that("E6-M5: top leads per question, and every figure drawn from its CSV", {
  x <- run_fixture("planted_da"); md <- readLines(file.path(x$o, "report", "compendium_report.md"))
  expect_true(any(grepl("^Top Q4 leads", md))); expect_true(any(grepl("^Top Q3 leads", md)))
  idx <- res_csv(x, "figures/figures_index.csv")
  expect_true("03_results/Q4_differential/results.csv" %in% idx$source_csv)
  y <- run_fixture("long_planted"); i2 <- res_csv(y, "figures/figures_index.csv")
  expect_true("03_results/Q6_change/alpha.csv" %in% i2$source_csv)
  expect_true(all(file.exists(file.path(y$o, i2$figure))))
})

test_that("E6-M6: Q7 leave-one-out runs in snapshot designs and says why not in longitudinal ones", {
  p <- run_fixture("planted_da")$l
  s7 <- p$loo_stable[p$question == "Q7" & p$status == "lead"]
  expect_gte(length(s7), 1); expect_true(all(s7 == "yes" | grepl("^no: depends on sample", s7)))
  r <- data.frame(status = "lead", p = 0.001, effect = 2)
  out <- seqcompendium:::loo_q7(r, list(), list(), NULL, NULL, long = TRUE)
  expect_match(out$loo_stable, "^not run: in a longitudinal design")
})

test_that("A residual check that cannot run never stops the run (D32)", {
  # On this seed one feature's mixed model gives simulations DHARMa cannot use.
  b <- tempfile("bundle"); make_toy_bundle(b, "long_planted", seed = 20261029L + 500000L)
  expect_no_error(run_compendium(b, out_dir()))
})
