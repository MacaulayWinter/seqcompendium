# V-E7(b) rerun with the fixed engine (ISCA job 2799565): FireSoils scored, Freshwaters pending

Status (2026-11-16): **task 1 (ArcticFireSoils) is scored; task 2 (ArcticFreshwaters) is still running.**
V-E7(b) as a whole is **not scored**: the mark names two data sets and has one row per method
and data set. Nothing here changes a mark or the scorer's rules. Engine: 55013ec (D55 fixes),
run at commit 7874e13; 147 samples, 3,656 features after the 10% filter; one core
(task 1 elapsed 2 d 3 h 21 m).

Mark (PREREGISTRATION §5, V-E7(b)): number of significant features per shared method equal to the
paper's "within the published rounding"; a difference explained only by a package version is
reported, not passed.

| Method | Engine (scorer) | Paper | Equal | Note |
|---|---|---|---|---|
| ALDEx2 | NA (scorer: "no rows in the engine's table") | 525 | no | see below: the engine's ALDEx2 count is 288 |
| Wilcoxon (CLR) | 2252 | 2101 | no | same as the Mac interim count |
| LEfSe (lefser) | 436 | 1978 | no | same as the Mac interim count |

**On FireSoils the mark fails: 0 of 3 method counts equal the paper's.** (A count of 288 for
ALDEx2 does not equal 525 either, so the fail does not depend on how ALDEx2 is read.)

**The ALDEx2 row is a scoring artefact, not an ALDEx2 failure.** The engine's override check (Q4
bundle report: default's false discovery rate 0.34 against a limit of 0.20 on 100 simulated
data sets) moved the default from LinDA to ALDEx2 (method D04). The default sits in
`03_results/Q4_differential/results.csv`, not in the agreement table `04_agreement/Q4.csv`,
which lists only the alternatives (D06, D09, D17). The scorer reads only the agreement table,
so it saw no ALDEx2 rows. D56 named this risk. From the engine's own default table: 288
features with BH q < 0.05, identical to the interim Mac count (288). The scorer is not changed
here; whether to count from the default table is for the user (it would change a scoring rule).

Interim Mac counts (D56) match the cluster result exactly for all three methods
(288 / 2252 / 436), so the cluster run adds no new number; it confirms the interim ones.

Cause (a reading, not a proven one; nothing is fixed):
- **LEfSe 436 vs 1978:** lefser 1.22 against the paper's Python LEfSe (D55, diagnosis).
- **Wilcoxon 2252 vs 2101:** a 7% gap; the engine's CLR pseudocount is 0.5 (R-PSEUDO), 2286
  at pseudocount 1, so the choice of pseudocount and the paper's own pre-processing move it, not
  the test. 
- **ALDEx2 288 vs 525:** ALDEx2 1.44 against the paper's R 4.0-era version with Monte Carlo
  draws, and the paper's pre-processing; the choice of test statistic moves it (322 or 403
  in the diagnosis), but none reaches 525.
All three are differences in packages and pre-processing, not engine defects. None is "explained
only by a package version" in the pre-registered sense, which needs evidence for each, so they
are reported, not passed.

Files here: `ve7b_ArcticFireSoils.csv` (scorer output), the bundle check, provenance, LEfSe
table (`04_agreement__Q4_describe_only.csv`) and the task log. The larger engine tables
(`Q4.csv` 2.4 MB, results table 1.9 MB, report 1.6 MB) stay in the work folder
`results_ve7b_fixed/ve7b_ArcticFireSoils_engine/`.
