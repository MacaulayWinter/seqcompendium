# V-E7b evidence: the engine against Nearing et al. 2022

## ArcticFireSoils: FAIL (2026-11-11)

`ve7b_ArcticFireSoils.csv` comes from the cluster task (1 d 16 h 40 min, peak memory 8.9 GB,
engine at commit 35e63e5), unchanged. It holds the counts of significant features, the
engine's against the paper's (Figure 1B, filtered table):

| Method | Engine | Paper |
|---|---|---|
| ALDEx2 | 0 | 525 |
| Wilcoxon (CLR) | 2252 | 2101 |
| LEfSe | 1 in the file, really 0 (see below) | 1978 |

By PREREGISTRATION §5, V-E7(b), this is a **fail**, and it stays on record as one. No mark has
been changed.

The file's LEfSe "1" is a flaw in the comparison script. LEfSe always writes one row, and with
no feature named that row means it flagged nothing or did not run; the script counted it. That
flaw, and the script deleting the engine's own tables, are fixed (CLAUDE.md D52). The cause of
the differences is being diagnosed with `validation/ve7b_direct.R`. The task is not re-scored
until the user has seen the diagnosis.

## ArcticFreshwaters

Still running on the cluster with the old script.

The counts are numbers derived from public data (figshare 14531724). No data are committed.
