# V-E10b marks 1-3, regression repeat on commit 7fc67ff

Run 2026-11-26 to 2026-11-27 on a Mac, from commit 7fc67ff (main after PR 23), engine 0.0.0.9005, rules 2026-11-24.1, R 4.6.1,
one Docker container per run (image `seqcompendium-validation:e7`), 8 GB, 4 CPUs. Inputs are byte-identical copies of those of the earlier runs (`../ve10b/`).
Bundles: the main toy and V-E1 scenarios s001-s004 (shotgun1 two_group, blocks, paired, paired_blocks; n = 10).
A regression repeat: no mark, rule, input or code changed, and the earlier results stay as they are.

| Mark | Runs compared | Result |
|---|---|---|
| V-E10b-1 | cores 1 vs 2 (a vs b), and 1 vs 4 (a vs c) | pass: 5 of 5 bundles, every CSV byte-identical |
| V-E10b-2 | cores 1 vs 4 with dispatch order shuffled, seed 7 (a vs d) | pass: 5 of 5 identical |
| V-E10b-3 | cores 4, repeated (c vs e) | pass: 5 of 5 identical |

Same file set in every comparison, 120 CSV files per run. The checksums were recomputed on the host after the runs and agree.
Run a also matches both V-E10 repeat runs (`../ve10_7fc67ff/`) in all 120 files; that comparison is not a pre-registered mark.

## What "4 cores" really was (read this before citing the result)
As in the earlier run, the worker rule (pre-registration 10.1) sized workers down for lack of memory (`settings/`):
- s001: 1 asked -> 1 worker; 2 asked -> 2; **4 asked -> 2**.
- s002: **1 worker whatever was asked**.
- Toy, s003, s004: no override loop, so no workers.

So identity is shown for 1 vs 2 real workers, **not for 4 real workers**. That remains V-E10b-6, which has not been run.
V-E10b-4 and -5 are unit tests and are not part of this folder.

## Time and memory (`run_times_memory.csv`)
Each run took between 3 h 28 min and 3 h 40 min. Highest sampled container memory, of 8 GB: a (1 core) 3,564 MiB; b 6,457; c 6,252; d 6,210; e 6,261 MiB.
Memory was sampled about every 5 to 14 s, so a brief peak can be missed. No memory kill. At least 31 GB of disk stayed free.

## Against the earlier run on commit 855f387 (descriptive, not a mark)
Of its 114 CSV files, 106 are byte-identical here and 8 differ; 6 files are new.
- New: `prevalence_screen.csv` and `prevalence_screen_decision.csv` in the toy, s001 and s002.
- `ordination.csv` (toy, s001, s002): three columns added; the shared columns are identical.
- `figures_index.csv` (toy and s001-s004): only caption text differs; the figure and source_csv columns are identical.

## Files
`ve10b_<a>_<b>.csv` per-bundle comparison; `*_mark.csv` the mark row; `md5_<run>.txt` md5 of every CSV;
`settings/<run>/<bundle>.yaml` workers used; `marks.log` start and end times. No data files.
