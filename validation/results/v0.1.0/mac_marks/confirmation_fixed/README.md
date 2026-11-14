# Mac marks rerun on the fixed engine (CLAUDE.md D53-D55)

Engine commit `55013ec` with D53 (DivNet seed fix) and D55 (LEfSe scale, error messages).
Rerun 2026-11-13/14 on the Mac, one container (8 GB, 1 core), from code checkout 9c71cd5.

## Results

All marks pass:

| Mark | Scenario | Result |
|---|---|---|
| V-E1 | S1: 6 designs, profile equals generator's truth | 1 = 1 ✓ |
| V-E8 | every_question | 1 = 1 ✓ |
| V-E8 | p_floor | 1 = 1 ✓ |
| V-E8 | no_pooling | 1 = 1 ✓ |
| V-E8 | figures_csv_only | 1 = 1 ✓ |
| V-E2b | (1) no control sample in Q1-Q11 | 1 = 1 ✓ |
| V-E2b | (2) control value changed: run stops naming it | 1 = 1 ✓ |
| V-E2b | (3) every control in controls.csv | 1 = 1 ✓ |
| V-E2b | (4) no-controls warning written | 1 = 1 ✓ |
| V-E10 | main toy and s001–s004 byte-identical on two runs | 1 = 1 ✓ |

## Comparison to first run

The first run (2026-11-11/12, before the fixes) had the same V-E1, V-E8 and V-E2b results (all pass), but V-E10 failed: 0.6 (only the main toy and s001 differed in Q2's DivNet rows). With the D53 seed fix, V-E10 now passes (5 of 5 bundles byte-identical).

Files:
- `mac_marks_fixed.csv`: mark rows (V-E2b and V-E10)
- `collect_marks_fixed.csv`: V-E1 and V-E8 scores (from `validation/collect.R`)
- `fixed_marks.log`: runner log
