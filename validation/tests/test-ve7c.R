# V-E7(c)'s scorer (PREREGISTRATION.md section 9): hand-made tables only, never real data, written BEFORE the scorer.
# Run from the repository root: Rscript -e 'testthat::test_dir("validation/tests")'
here <- if (dir.exists("validation/R")) "validation/R" else "../R"
source(file.path(here, "ve7c_score.R"))

test_that("9.5 rule 1: the allowance is max(t_rel x reference count, t_abs), per method, and never below twice a reading error", {
  expect_equal(ve7c_allowance("D09", 100), 5)          # LinDA 5%, 0
  expect_equal(ve7c_allowance("D06", 367), 18.35)      # ANCOM-BC2 5%
  expect_equal(ve7c_allowance("D17", 54), 2.7)         # Wilcoxon 5%
  expect_equal(ve7c_allowance("D19", 60), 3)           # LEfSe 5%
  expect_equal(ve7c_allowance("D04", 100), 8)          # ALDEx2: 8% of 100 = 8 > 2
  expect_equal(ve7c_allowance("D04", 3), 2)            # ALDEx2: 8% of 3 = 0.24 < t_abs = 2
  expect_equal(ve7c_allowance("D09", 10, reading_error = 4), 8)   # 5% of 10 = 0.5; twice a reading error of 4 = 8
  expect_equal(ve7c_allowance("D09", 100, reading_error = 1), 5)  # twice 1 = 2 < 5
  expect_error(ve7c_allowance("D99", 10), "no allowance")
})

test_that("9.5 rule 1: a count exactly at the allowance agrees; one past it does not", {
  expect_true(ve7c_count_ok("D09", 100, 105))     # difference 5 = allowance 5
  expect_false(ve7c_count_ok("D09", 100, 106))
  expect_true(ve7c_count_ok("D09", 100, 95))
  expect_false(ve7c_count_ok("D09", 100, 94))
  expect_true(ve7c_count_ok("D04", 3, 5))          # 2 = t_abs
  expect_false(ve7c_count_ok("D04", 3, 6))
  expect_true(ve7c_count_ok("D17", 0, 0))
  expect_false(ve7c_count_ok("D17", 0, 1))         # 5% of 0 = 0: a version-only difference does not pass
  expect_false(ve7c_count_ok("D09", 100, NA))      # a method that did not run is never agreement
})

feat <- function(f, e, q) data.frame(feature = f, effect = e, q = q, stringsAsFactors = FALSE)

test_that("9.5 rule 2: sign agreement among features significant in both, at least 95%", {
  eng <- feat(letters[1:20], rep(1, 20), rep(0.01, 20)); ref <- feat(letters[1:20], c(rep(1, 19), -1), rep(0.01, 20))
  expect_equal(ve7c_sign_agreement(eng, ref), 0.95)            # exactly at the threshold
  expect_true(ve7c_rule2(eng, ref))
  ref2 <- feat(letters[1:20], c(rep(1, 18), -1, -1), rep(0.01, 20))
  expect_equal(ve7c_sign_agreement(eng, ref2), 0.90)
  expect_false(ve7c_rule2(eng, ref2))
  # only features significant in BOTH count (q < 0.05 each side); a feature significant on one side is ignored
  ref3 <- feat(letters[1:4], c(1, 1, -1, -1), c(0.01, 0.01, 0.5, 0.01)); eng3 <- feat(letters[1:4], rep(1, 4), c(0.01, 0.01, 0.01, 0.5))
  expect_equal(ve7c_sign_agreement(eng3, ref3), 1)
  # the reference's sign convention can be the opposite of the engine's (flip = TRUE)
  expect_equal(ve7c_sign_agreement(eng, ref, flip = TRUE), 0.05)
})

test_that("9.5 rule 2 edge cases the section does not spell out: nothing significant in both", {
  none <- feat(c("a", "b"), c(1, 1), c(0.5, 0.5))
  expect_true(is.na(ve7c_sign_agreement(none, none)))
  expect_true(ve7c_rule2(none, none))                          # both sides have nothing: nothing to disagree about
  one <- feat(c("a", "b"), c(1, 1), c(0.01, 0.5))
  expect_false(ve7c_rule2(one, feat(c("a", "b"), c(1, 1), c(0.5, 0.01))))   # features on each side, none shared: the rule is not met
})

test_that("9.5 rule 3: Spearman of effects over features significant in either, at least 0.8; counts-only references skip it", {
  f <- paste0("f", 1:10)
  eng <- feat(f, 1:10, rep(0.01, 10)); ref <- feat(f, (1:10)^2, rep(0.01, 10))
  expect_equal(ve7c_spearman(eng, ref), 1)
  expect_true(ve7c_rule3(eng, ref))
  ref_bad <- feat(f, c(1, 2, 3, 4, 5, 10, 9, 8, 7, 6), rep(0.01, 10))
  expect_lt(ve7c_spearman(eng, ref_bad), 0.8)
  expect_false(ve7c_rule3(eng, ref_bad))
  # features significant in neither are left out; features present in one table only are left out
  eng2 <- rbind(eng, feat("z", -100, 0.9)); ref2 <- rbind(ref, feat("z", 100, 0.9), feat("only_ref", 5, 0.001))
  expect_equal(ve7c_spearman(eng2, ref2), 1)
  # a reference that publishes counts only: rule 3 does not apply (NA), and the verdict must not fail on it
  expect_true(is.na(ve7c_rule3(eng, NULL)))
  expect_true(is.na(ve7c_spearman(eng, NULL)))
  # exactly at 0.8: effects giving rho = 0.8 pass
  r8 <- feat(letters[1:5], c(1, 2, 3, 5, 4), rep(0.01, 5)); e8 <- feat(letters[1:5], 1:5, rep(0.01, 5))
  expect_equal(ve7c_spearman(e8, r8), 0.9)
  expect_true(ve7c_rule3(e8, feat(letters[1:5], c(2, 1, 3, 5, 4), rep(0.01, 5))))   # rho = 0.8
})

test_that("a method line: all rules that apply must hold; NA (not applicable) is not a failure, a failed count is", {
  expect_true(ve7c_method_ok(count_ok = TRUE, rule2 = TRUE, rule3 = NA))
  expect_true(ve7c_method_ok(TRUE, TRUE, TRUE))
  expect_false(ve7c_method_ok(FALSE, TRUE, TRUE))
  expect_false(ve7c_method_ok(TRUE, FALSE, NA))
  expect_false(ve7c_method_ok(TRUE, TRUE, FALSE))
  expect_true(is.na(ve7c_method_ok(NA, TRUE, TRUE)))           # nothing could be compared: not confirmed, never a pass
})

test_that("a reference is congruent when every method other than LinDA meets its rules; LinDA counts only if the reference is not by LinDA's authors", {
  m <- data.frame(method_id = c("D09", "D06", "D04", "D17", "D19"), ok = c(FALSE, TRUE, TRUE, TRUE, TRUE), stringsAsFactors = FALSE)
  expect_true(ve7c_reference_congruent(m, linda_authors = TRUE))     # Zhou: LinDA on its own line, reported, not counted
  expect_false(ve7c_reference_congruent(m, linda_authors = FALSE))   # Wallen: LinDA counts
  m2 <- transform(m, ok = c(TRUE, TRUE, FALSE, TRUE, TRUE))
  expect_false(ve7c_reference_congruent(m2, linda_authors = TRUE))
  expect_true(is.na(ve7c_reference_congruent(transform(m, ok = c(TRUE, NA, TRUE, TRUE, TRUE)), linda_authors = TRUE)))  # a method not confirmed: not confirmed
  expect_error(ve7c_reference_congruent(m[0, ], linda_authors = TRUE), "no methods")
})

test_that("9.7 outcomes table", {
  refs <- function(planted, wallen, zhou) data.frame(reference = c("planted", "Wallen 2021", "Zhou 2022"), congruent = c(planted, wallen, zhou),
                                                      published = c(FALSE, TRUE, TRUE), author_free = c(FALSE, TRUE, FALSE), stringsAsFactors = FALSE)
  expect_match(ve7c_outcome(refs(TRUE, TRUE, TRUE)), "^Pass")
  expect_match(ve7c_outcome(refs(FALSE, TRUE, TRUE)), "^Fail")                  # planted fails: fail whatever the papers say
  expect_match(ve7c_outcome(refs(TRUE, TRUE, FALSE)), "^Unresolved")           # planted congruent, some published not
  expect_match(ve7c_outcome(refs(TRUE, FALSE, TRUE)), "^Unresolved")
  expect_match(ve7c_outcome(refs(TRUE, FALSE, FALSE)), "^Fail")                 # no published reference congruent
  expect_match(ve7c_outcome(refs(TRUE, TRUE, TRUE)[1:2, ]), "^Not confirmed")   # N < 3
  expect_match(ve7c_outcome(refs(TRUE, NA, TRUE)), "^Not confirmed")            # the method-author-free reference could not be run or scored
  expect_match(ve7c_outcome(refs(NA, TRUE, TRUE)), "^Not confirmed")            # planted truth not run
  # a pass needs the author-free reference: without one among the three, never a pass
  r <- refs(TRUE, TRUE, TRUE); r$author_free <- FALSE
  expect_match(ve7c_outcome(r), "^Not confirmed")
})
