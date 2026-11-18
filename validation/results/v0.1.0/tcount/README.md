# T_count measurement (PREREGISTRATION section 9.5), 2026-11-16

The engine's Q4 methods repeated on the feature tables of Wallen 2021 (two Parkinson's disease cohorts), with the engine's own
seeds (rep 0) and 10 shifted seed sets (reps 1-10; the seed shift is added to `seed_for()` by the harness, not an engine change).
The paper's counts were never read. 8 GB container, 1 core, engine code identical to 55013ec (commit 761f7b9 tree).

Files: `tcount_dataset1.csv`, `tcount_dataset2.csv` (ANCOM-BC2 D06, Wilcoxon on CLR D17, ALDEx2 D04, LEfSe D19);
`tcount_dataset1_default.csv`, `tcount_dataset2_default.csv` (LinDA D09, the default for a layer without a denominator;
run separately because the agreement table does not hold the default); `wallen_tcount.R` is the harness
(the second run used the same script with the method list and file tag passed as arguments).

Counts over the 11 runs: LinDA 43 / 104; ANCOM-BC2 139 / 367; Wilcoxon 14 / 54; LEfSe 64 / 60 (no variation);
ALDEx2 1-3 / 13-14 (table 1 / table 2). Tables: dataset 1 = 333 samples (201 Case, 132 Control), dataset 2 = 507 samples (323 Case, 184 Control).
The feature tables were downloaded from the authors' repository (two files, 1,052,159 and 2,016,358 bytes) and are not committed.

## Approval and what the tolerances mean

**Approved by the user 2026-11-17** (relayed by the coordinating session: "Go with option A"): the allowances of section 9.5 as written,
including ALDEx2's absolute 2 features (8% plus 2 features) and 5% for LinDA, ANCOM-BC2, Wilcoxon on CLR and LEfSe.
Not yet pushed; the branch waits for E7 to merge.

**What 5% means on small counts, stated plainly.** For the four methods that showed no spread (LinDA, ANCOM-BC2, Wilcoxon on CLR, LEfSe) the
allowance is 5% of the reference's count. On a small count that is **effectively an exact match**: 5% of 14 is 0.7 of a feature, so a
reference count of 14 allows no difference at all, and one of 54 allows 2. A difference of one or two features that comes only from a package
version can therefore **fail** the count rule. That is deliberate: the allowance is not widened to fit versions. The outcomes rule of
section 9.7 already covers this: a difference explained only by a package version is **reported, not passed**, so such a case is recorded as
"reported (version difference)", never silently counted as a pass.
