# V-E10 regression repeat on commit 7fc67ff: identical results from two runs

Run 2026-11-26 on a Mac, from commit 7fc67ff (main after PR 23), engine 0.0.0.9005, rules 2026-11-24.1, R 4.6.1,
one Docker container per run (image `seqcompendium-validation:e7`), 8 GB, 1 CPU. Inputs are byte-identical copies of those of the earlier V-E10b runs.
Bundles: the main toy and V-E1 scenarios s001-s004. A regression repeat: no mark, rule, input or code changed, and earlier results stay as they are.

| Mark | Runs compared | Result |
|---|---|---|
| V-E10 | c vs d | pass: 5 of 5 bundles, same file set, every CSV byte-identical (120 files) |

The 120 checksums were recomputed on the host after the run and agree.
The mark row says "fixed engine": that wording is fixed text in `validation/mac_marks.R`.

## Time and memory (`run_times_memory.csv`)
The runs took 3 h 35 min and 3 h 36 min. Highest sampled container memory: 3,975 MiB (c) and 3,546 MiB (d) of 8 GB.
Memory was sampled about every 5 to 14 s, so a brief peak can be missed. No memory kill. At least 32 GB of disk stayed free.

## Files
`ve10_c_d.csv` per-bundle comparison; `ve10_c_d_mark.csv` the mark row; `md5_<run>.txt` md5 of every CSV;
`settings/<run>/<bundle>.yaml` workers used; `marks.log` start and end times. No data files.
