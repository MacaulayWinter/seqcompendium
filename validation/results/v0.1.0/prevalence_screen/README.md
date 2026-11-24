# Evidence for the prevalence screen (CLAUDE.md D70)

Toy tables with a known answer only; no research data and no real table was screened. Mac container, 8 GB, 1 core, 2026-11-24. The criteria were written down and accepted by the user before any code (design note, points 1 to 10).

## Identity with main (8f59b0d)
`identity/*.md5`: md5 of every CSV a toy bundle gives through main and through this branch with `screen = "off"` and with the default. **All four combinations are identical** (main toy: 32 existing CSV files; calib toy, where the override check runs: 31): every existing file is byte-identical, and with `screen = "off"` the screen writes none of its files. With the default the screen adds `01_profile/prevalence_screen*.csv` and nothing else changes (it did not fire on either bundle: all study samples are analysed).

## Test results, both runs, nothing hidden
**First run** (screen tests, then the full suite, harness tests and `R CMD check`): screen tests 12 with 1 failure; full package suite 96 tests with 2 failures and 2 errors; harness tests 31, 0 failed; `R CMD check --no-tests`: the same 3 NOTEs as main.
- **A real bug of mine, found by the existing suite:** when a bundle has no testable count comparison (the few-subjects fixture of `test-e5`, and the `cage` block case of `test-guide-stops`) the screen has no decision table and the report step stopped with "invalid argument type". Fixed by guarding the empty case (`screen_report_lines()`), with a regression test on the few-subjects bundle. This is why 2 existing tests failed.
- **A fault in my own test:** the four-arm end-to-end test compared row labels of the two-group result; the content was identical but the labels differ because the features the screen leaves out of the arm comparison shift the row positions. It now compares content (no random numbers involved, no seed or threshold changed).

**Second run** (the three affected files only): `test-screen.R` 13 tests, 0 failed; `test-e5.R` 8, 0 failed; `test-guide-stops.R` 4, 0 failed.

## What the screen does and does not show
- It reports, proposes in words, and leaves features out of a comparison's Q4 tests only in the narrow case of the design note (count layer; pooled analysed prevalence keeps at least 2x as many features as pooled all-study prevalence at 10%; the analysed samples are at most 60% of the study samples; at least 2 features remain). A two-group design analyses every study sample and cannot fire.
- **The Freshwaters trap stays a harness matter (D66).** The screen only sees samples that are in the bundle, so the paper-versus-analysed-samples gap that made the Freshwaters run test 1,069 features instead of 344 is handled by the harness filter `VE7B_FILTER=all_samples`. The screen guards the same trap inside a bundle: samples of other groups, timepoints or blocks that are in the table but not in a comparison.
- **R-SCREENMINKEEP = 2 is my addition beyond the ten accepted criteria** (the screen never leaves fewer than 2 features to test). It is flagged here and in D70 so the user can veto it.
- Nothing real was run; no mark changes; no pre-registration section is added.
