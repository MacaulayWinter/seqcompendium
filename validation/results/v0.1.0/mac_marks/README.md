# Mac marks, v0.1.0 (simulated data only)

`first_run/`: V-E1 (scenarios 1–6, run 1), V-E2b (1)–(4) and V-E10, run on the Mac on
2026-11-11/12 with `validation/mac_marks.sh` (one container, 6 GB).
V-E2b passes on all four parts. **V-E10 fails** (0.6 against = 1): only Q2's DivNet rows
differ between the two runs. The cause is an unseeded first DivNet call (CLAUDE.md D53).
These files stay as the record of the failed run. The confirmation run with the fix
is in `confirmation/`. V-E1 and V-E8 are scored from `rows/` by
`validation/collect.R`.

`confirmation/`: V-E10 rerun with the fix (engine 55013ec), runs c and d in fresh
containers (6 GB, 1 core), 2026-11-12/13. **V-E10 passes**: every CSV of the main toy
and s001 to s004 is byte-identical between the two runs (5 of 5; number 1 against = 1).
`ve10_c_d.csv` lists each bundle, `ve10_c_d_mark.csv` is the mark row, and
`ve10_confirm.log` is the runner's log. The runs were slow because the Mac slept on
battery; that changes the timing only.
