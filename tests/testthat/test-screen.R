# The prevalence screen (CLAUDE.md D70; design note criteria 1 to 10). Toy tables with a known answer only.
sc <- function(name) get(name, envir = asNamespace("seqcompendium"))

# A layer, a design and a comparison built by hand: n_ref + n_lvl analysed samples and n_other samples that are in the table but not in the comparison.
# `rare`: features present (value 5) in exactly `rare_in` of the analysed samples, nowhere else. `common`: features present in every sample.
toy_screen <- function(n_ref = 20, n_lvl = 20, n_other = 60, common = 10, rare = 20, rare_in = 5, near_empty = 0) {
  an <- c(sprintf("a%02d", seq_len(n_ref)), sprintf("b%02d", seq_len(n_lvl))); ot <- if (n_other) sprintf("c%02d", seq_len(n_other)) else character(0); all_s <- c(an, ot)
  d <- expand.grid(sample = all_s, feature = c(sprintf("com%02d", seq_len(common)), if (rare) sprintf("rare%02d", seq_len(rare))), stringsAsFactors = FALSE)
  d$value <- ifelse(startsWith(d$feature, "com"), 20, 0)
  if (rare) for (k in seq_len(rare)) d$value[d$feature == sprintf("rare%02d", k) & d$sample %in% an[((k - 1) + seq_len(rare_in) - 1) %% length(an) + 1]] <- 5
  if (near_empty) { low <- all_s[seq_len(near_empty)]; d$value[d$sample %in% low] <- ifelse(d$feature[d$sample %in% low] == "com01", 3, 0) }
  L <- list(data = d, spec = list(unit = "count"))
  des <- list(study = data.frame(sample = all_s))
  u <- list(layer = "L", predictor = "g", contrast = "b vs a", timepoint = "all", block = "all", reference = "a", level = "b",
            ref_samples = an[seq_len(n_ref)], level_samples = an[n_ref + seq_len(n_lvl)], testable = TRUE)
  list(L = L, des = des, u = u, units = list(u), layers = list(L = L))
}
cell <- function(x, item, cut = NA) { r <- x$rows; v <- r$value[r$item == item & (is.na(cut) | (!is.na(r$cut) & abs(r$cut - cut) < 1e-9))]; if (length(v) == 1) v else v }

test_that("D70 (1-4): the sample set the cut is counted over changes the kept set, and the screen says by how much", {
  t <- toy_screen(); x <- sc("screen_unit")(t$u, t$L, t$des, "default")
  expect_identical(cell(x, "kept_P_pooled_analysed", 0.10), "30")                 # 10 common + 20 rare (5 of 40 analysed samples = 12.5%)
  expect_identical(cell(x, "kept_S_pooled_all_study_samples", 0.10), "10")        # the rare ones are in 5 of 100 samples = 5%
  expect_identical(cell(x, "features_differing_between_P_and_S", 0.10), "20")
  expect_identical(cell(x, "ratio_larger_over_smaller_of_P_and_S", 0.10), "3")
  expect_identical(cell(x, "sample_set_sensitivity_flagged", 0.10), "TRUE")
  expect_identical(cell(x, "sample_set_sensitivity_flagged", 0.05), "FALSE")        # at 5% both bases keep the rare features (5/100 = 5%)
  expect_identical(cell(x, "share_of_features_present_in_fewer_than", 0.10), "0")        # the rare features are in 12.5% of the 40 analysed samples: none is under 10%
  expect_identical(cell(x, "share_of_features_present_in_fewer_than", 0.20), "0.6667")   # but 20 of the 30 are under 20%
})

test_that("D70 (5): when the sets agree the screen proposes nothing and says so", {
  t <- toy_screen(n_other = 0, rare = 0); x <- sc("screen_unit")(t$u, t$L, t$des, "default")      # every feature is in every sample: nothing to say
  expect_identical(cell(x, "sample_set_sensitivity_flagged", 0.10), "FALSE")
  expect_match(x$decision$proposal, "no change proposed"); expect_false(x$decision$applied); expect_null(x$drop)
  r <- toy_screen(n_other = 0); y <- sc("screen_unit")(r$u, r$L, r$des, "default")                  # rare features, but the same set under every basis: the sparse tail is named, nothing is applied
  expect_match(y$decision$proposal, "present in fewer than 20%"); expect_false(y$decision$applied)
})

test_that("D70 (6-7): the narrow default-apply fires, leaves out exactly the features it should, and only in default mode", {
  t <- toy_screen(); on <- sc("screen_unit")(t$u, t$L, t$des, "default"); off <- sc("screen_unit")(t$u, t$L, t$des, "report")
  expect_true(on$decision$applied); expect_identical(sort(on$drop), sprintf("rare%02d", 1:20)); expect_identical(nrow(on$removed), 20L)
  expect_match(on$decision$proposal, "propose counting the 10% prevalence cut over all 100 study samples")
  expect_false(off$decision$applied); expect_null(off$drop); expect_match(off$decision$why, "report mode")
})

test_that("D70 (6): it cannot fire when most study samples are analysed, even if the two counts differ by a factor of 2 or more", {
  t <- toy_screen(n_other = 30, rare_in = 5)              # 40 of 70 samples analysed = 57%: fires; the guard is checked next with 40 of 55 = 73%
  expect_true(sc("screen_unit")(t$u, t$L, t$des, "default")$decision$applied)
  g <- toy_screen(n_other = 15, rare_in = 5)              # 40 of 55 analysed (73%), rare features in 5/40 = 12.5% of analysed, 5/55 = 9.1% of all
  x <- sc("screen_unit")(g$u, g$L, g$des, "default")
  expect_identical(cell(x, "sample_set_sensitivity_flagged", 0.10), "TRUE")
  expect_false(x$decision$applied); expect_match(x$decision$why, "60%")
})

test_that("D70 (6): a two-group design in which every study sample is analysed cannot fire", {
  t <- toy_screen(n_other = 0, rare_in = 5); x <- sc("screen_unit")(t$u, t$L, t$des, "default")
  expect_false(x$decision$applied)
})

test_that("D70 (7): it never leaves fewer features than a model can use", {
  t <- toy_screen(common = 1, rare = 20); x <- sc("screen_unit")(t$u, t$L, t$des, "default")   # only one feature would remain
  expect_identical(cell(x, "sample_set_sensitivity_flagged", 0.10), "TRUE"); expect_false(x$decision$applied); expect_match(x$decision$why, "fewer than the smallest set")
})

test_that("D70 (2): near-empty samples are counted and named", {
  t <- toy_screen(near_empty = 3); d <- sc("screen_depth")(t$L, t$des)
  expect_identical(d$value[d$item == "near_empty_samples"], "3"); expect_match(d$note[d$item == "near_empty_samples"], "a01, a02, a03")
  expect_identical(d$value[d$item == "library_size_min"], "3")
})

test_that("D70 (9): a table the harness has already filtered (the rare features are not in the bundle) is not flagged", {
  t <- toy_screen(rare = 0); x <- sc("screen_unit")(t$u, t$L, t$des, "default")      # the D66 filter removed them before the engine saw the table
  expect_identical(cell(x, "sample_set_sensitivity_flagged", 0.10), "FALSE"); expect_false(x$decision$applied)
})

test_that("D70: a feature the engine's own rule (R-PREV) already excludes is never in the removed list, and R-PREV still applies after the screen", {
  t <- toy_screen(); on <- sc("screen_unit")(t$u, t$L, t$des, "default")
  ud <- sc("unit_data")(t$u, t$L, NULL); prev <- sc("prevalent")(ud$m, ud$g)
  expect_true(all(on$removed$feature %in% prev))                                          # they pass R-PREV; the screen only takes away from that set
  expect_identical(setdiff(prev, on$drop), sprintf("com%02d", 1:10))                    # what Q4 tests after the screen: R-PREV's set minus the screen's
})

options_fast <- function() { o <- options(seqcompendium.simrep = 2L); function() options(o) }   # the override check's simulation at 2 repeats: a test hook (R/override.R)

test_that("D70 (8): run_compendium on a two-group toy: the screen writes its files, leaves nothing out, and screen = 'off' writes none and changes no other file", {
  reset <- options_fast(); on.exit(reset(), add = TRUE)
  b <- toy("calib"); o1 <- out_dir(); o2 <- out_dir(); o3 <- out_dir()
  run_compendium(b, o1); run_compendium(b, o2, screen = "off"); run_compendium(b, o3, screen = "report")
  expect_true(file.exists(file.path(o1, "01_profile", "prevalence_screen.csv"))); expect_true(file.exists(file.path(o1, "01_profile", "prevalence_screen_decision.csv")))
  expect_false(file.exists(file.path(o1, "01_profile", "prevalence_screen_removed.csv"))); expect_false(any(utils::read.csv(file.path(o1, "01_profile", "prevalence_screen_decision.csv"))$applied))
  expect_false(file.exists(file.path(o2, "01_profile", "prevalence_screen.csv")))
  csvs <- function(o) sort(list.files(o, pattern = "\\.csv$", recursive = TRUE)); screen_files <- function(v) v[!grepl("prevalence_screen", v)]
  expect_identical(csvs(o2), screen_files(csvs(o1))); expect_identical(csvs(o2), screen_files(csvs(o3)))
  md5 <- function(o, f) unname(tools::md5sum(file.path(o, f)))
  for (f in csvs(o2)) { expect_identical(md5(o2, f), md5(o1, f), info = f); expect_identical(md5(o2, f), md5(o3, f), info = f) }
  t <- utils::read.delim(file.path(o1, "provenance", "step_timings.tsv")); expect_true(any(t$step == "prevalence screen"))
  expect_false(any(utils::read.delim(file.path(o2, "provenance", "step_timings.tsv"))$step == "prevalence screen"))
  expect_equal(yaml::read_yaml(file.path(o2, "provenance", "run_settings.yaml"))$screen, "off")
})

test_that("D70 (6-7): end to end, four arms, rare features: default leaves them out of Q4 with a caveat and a list; report mode leaves Q4 as it is", {
  reset <- options_fast(); on.exit(reset(), add = TRUE)
  b <- toy("calib"); m <- rd(file.path(b, META)); n <- nrow(m)
  add_column(b, "arm", c("a", "b", "c", "d"), "predictor", "categorical", levels = "a|b|c|d")
  arm <- rep_len(c("a", "b", "c", "d"), n); ab <- m$sample[arm %in% c("a", "b")]
  edit(b, LAYER, function(x) {
    for (k in 9:30) { f <- sprintf("toyG%02d", k); x$value[x$feature == f] <- "0"; x$value[x$feature == f & x$sample == ab[(k - 9) %% length(ab) + 1]] <- "9" }   # 22 features, each in exactly one sample of arm a or b
    x })
  o1 <- out_dir(); o2 <- out_dir(); run_compendium(b, o1); run_compendium(b, o2, screen = "report")
  dec <- utils::read.csv(file.path(o1, "01_profile", "prevalence_screen_decision.csv")); a <- dec[dec$predictor == "arm", ]
  expect_true(any(a$applied)); expect_true(file.exists(file.path(o1, "01_profile", "prevalence_screen_removed.csv")))
  rm <- utils::read.csv(file.path(o1, "01_profile", "prevalence_screen_removed.csv"))
  q1 <- utils::read.csv(file.path(o1, "03_results", "Q4_differential", "results.csv")); q2 <- utils::read.csv(file.path(o2, "03_results", "Q4_differential", "results.csv"))
  for (cn in unique(rm$contrast)) {
    gone <- rm$feature[rm$contrast == cn]; r1 <- q1[q1$predictor == "arm" & q1$contrast == cn, ]; r2 <- q2[q2$predictor == "arm" & q2$contrast == cn, ]
    expect_false(any(gone %in% r1$feature)); expect_true(all(gone %in% r2$feature))                    # left out with the screen, present without it
    expect_true(all(grepl("prevalence screen left", r1$caveat)))
  }
  expect_false(file.exists(file.path(o2, "01_profile", "prevalence_screen_removed.csv")))
  g1 <- q1[q1$predictor == "group", ]; g2 <- q2[q2$predictor == "group", ]; g1 <- g1[order(g1$feature), ]; g2 <- g2[order(g2$feature), ]; rownames(g1) <- NULL; rownames(g2) <- NULL; expect_identical(g1, g2)   # the two-group comparison is untouched
})

test_that("D70: the rules exist with the written values, and the rules version moved", {
  r <- sc("rule"); expect_identical(unlist(r("R-SCREENCUTS")), c(0.05, 0.10, 0.20)); expect_equal(r("R-SCREENSENS"), 2); expect_equal(r("R-SCREENAPPLYCUT"), 0.10)
  expect_equal(r("R-SCREENSHARE"), 0.60); expect_equal(r("R-SCREENMINKEEP"), 2); expect_identical(sc("rules")()$rules_version, "2026-11-24.1")
  expect_error(run_compendium(toy("calib"), out_dir(), screen = "maybe"))
})

test_that("D70: a bundle with no testable comparison (so no screen decision) still runs, and writes no screen files", {
  reset <- options_fast(); on.exit(reset(), add = TRUE)
  b <- toy("few_subjects"); o <- out_dir()
  expect_no_error(run_compendium(b, o))
  expect_false(file.exists(file.path(o, "01_profile", "prevalence_screen_decision.csv")) && !nrow(utils::read.csv(file.path(o, "01_profile", "prevalence_screen_decision.csv"))))   # never an empty decision file
  expect_no_error(seqcompendium:::screen_report_lines(list(decision = NULL, rows = NULL)))
  expect_identical(seqcompendium:::screen_report_lines(NULL), character(0))
})
