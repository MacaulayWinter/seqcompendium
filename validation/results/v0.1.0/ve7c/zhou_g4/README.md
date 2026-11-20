# Zhou 2022 G4 re-run: result (scored once, 2026-11-18)

Plan: `G4_PLAN.md` (pushed before any run). Engine tables: `ve7c_zhou_<set>_<mode>_*.csv` (frozen and pushed before scoring). Scorer: `validation/ve7c_run_score_g4.R`
(same judge, allowances and column map as the first scoring; no change). Original run (raw tables) stays as recorded in `../scoring/`: not congruent. It is not replaced.

**Result: the G4 re-run is also not congruent, in both variants.** The feature set now equals Zhou's own: 100% of each deposited matrix's rows are in the engine's table
(CDI 123, IBD 579, RA 438, SMOKE 209 features). Engine count vs Zhou's count, allowance in brackets; LinDA is the authors' own line and is not counted:

| Set | Method | Original | G4 filter only | G4 full (filter + winsor + covariate) | Zhou |
|---|---|---|---|---|---|
| CDI | ANCOM-BC2 | 69 | 49 | 35 | 3 (0.15) |
| CDI | Wilcoxon on CLR | 16 | 13 | 13 | 3 (0.15) |
| CDI | ALDEx2 | 1 | 1 | 1 | 2 (2) pass |
| IBD | ANCOM-BC2 | 96 | 91 | 20 | 27 (1.35) |
| IBD | Wilcoxon on CLR | 208 | 113 | 132 | 47 (2.35) |
| IBD | ALDEx2 | 1 | 2 | 1 | 1 (2) pass |
| RA | ANCOM-BC2 | 275 | 192 | 176 | 43 (2.15) |
| RA | Wilcoxon on CLR | 2 | 2 | 2 | 19 (0.95) |
| RA | ALDEx2 | 1 | 1 | 1 | 0 (2) pass |
| (LinDA, own line) CDI / IBD / RA / SMOKE | | 3/33/24/37 | 3/42/44/32 | 3/26/46/29 | 3/23/44/11 |

ALDEx2 meets the count rule on all three sets in every run (it is a method that returns almost nothing here). Of the other methods only LinDA on CDI and RA meet it.
LinDA on IBD and SMOKE do not (26 vs 23, allowance 1.15; 29 vs 11). The pre-processing closed some of the gap (CDI ANCOM-BC2 69 to 35; IBD Wilcoxon 208 to 113) but no method that failed in the original run passes now.

Limits, stated plainly. (1) SMOKE's subject random effect is not expressed (the engine's Q4 has no random effect); SMOKE has only LinDA columns in Zhou's deposit, so it is
on LinDA's own line either way. (2) The covariates were carried as the engine's `batch` role: IBD was adjusted for Antibiotic, SMOKE for Sex (see the meta files); the engine's Wilcoxon on CLR cannot adjust
(it is recorded as not adjusted). (3) ANCOM-BC 1.0.5 in the paper vs ANCOM-BC2 in the engine is not removed by G4;
Zhou's winsorising and the engine's own methods are different procedures. (4) Zhou's group authored LinDA, so under 9.7 G4 alone could not give a pass; none is claimed.
