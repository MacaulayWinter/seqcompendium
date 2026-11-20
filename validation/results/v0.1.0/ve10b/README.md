# V-E10b marks 1-3: identical results at different core counts

Run 2026-11-19 to 2026-11-20 from commit 855f387 (V-E10b code, PR 14), one Docker container per run, 8 GB, 4 CPUs.
Bundles: the main toy and V-E1 scenarios s001-s004 (shotgun1 two_group, blocks, paired, paired_blocks; n = 10).

| Mark | Runs compared | Result |
|---|---|---|
| V-E10b-1 | cores 1 vs 2 (a vs b), and 1 vs 4 (a vs c) | pass: 5 of 5 bundles, every CSV byte-identical |
| V-E10b-2 | cores 1 vs 4 with dispatch order shuffled, seed 7 (a vs d) | pass: 5 of 5 identical |
| V-E10b-3 | cores 4, repeated (c vs e) | pass: 5 of 5 identical |

Same file set in every comparison; 0 files differing (`provenance/run_settings.yaml` is the only file allowed to differ and is not a CSV).

## What "4 cores" really was (read this before citing the result)

The worker rule (pre-registration 10.1) sizes workers down when memory is short. `settings/` holds each run's `run_settings.yaml`:

- s001 (has an override check): 1 core asked -> 1 worker; 2 asked -> 2 workers; **4 asked -> 2 workers**.
- s002: **1 worker whatever was asked** (about 5 GB free, about 3.4 GB per worker).
- Toy, s003, s004: no override loop, so no workers at all.

So identity is shown for 1 vs 2 real workers. **It is not shown for 4 real workers**, and "cores 4" above means "4 asked".
Four real workers need more memory than the 8 GB Mac rule allows; that is V-E10b-6 (cluster, optional).
V-E10b-4 and -5 are covered by the unit tests in PR 14, not by this folder.

## Files
`ve10b_<a>_<b>.csv` per-bundle comparison; `*_mark.csv` the mark row; `md5_<run>.txt` md5 of every CSV in each run;
`settings/<run>/<bundle>.yaml` workers used; `marks.log` run times. No data files.
