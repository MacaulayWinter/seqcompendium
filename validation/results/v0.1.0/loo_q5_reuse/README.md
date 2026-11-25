# Leave-one-out Q5: the comparison's data built once per left-out sample (CLAUDE.md D71)

Invented data only. No rule, mark or tolerance changed.

## Cause, measured before the change (`profile_q5.R`, `profile_main.txt`)

400 refits of the old loop's two parts, on a Mac, one core:

| Table | Building the data (`unit_data`) | Model fit and summary | Share spent building |
|---|---|---|---|
| 936 samples, 346 features | 31.9 ms per refit | 1.7 ms | 95% |
| 200 samples, 100 features | 1.9 ms | 0.8 ms | 70% |

The old loop built the whole count matrix once for **every lead and every left-out sample**. The matrix is the same for all leads of a comparison.

## The change (`R/loo.R`)

The loop now runs over comparisons, then left-out samples (data built once), then leads. The refit itself is the same code, moved into `loo_q5_refit`. Neither fit draws a random number.

## Same results (`identity_host.R`, `identity_host.txt`)

The old function (from main) and the new one, `identical()` on the whole results table, on invented tables with 33 to 66 leads (2 to 10 of them Firth), with and without covariates: identical in all four, and in the three timing tables.

## Speed, one core on a Mac (R 4.5.2), two groups, 20 logistic leads

| Table | Main | Branch | Times faster |
|---|---|---|---|
| 100 samples, 100 features | 4.0 s | 1.6 s | 2.5 |
| 300 samples, 346 features | 101.9 s | 10.5 s | 9.7 |
| 936 samples, 346 features | 884.0 s | 65.2 s | 13.5 |

Another job was running on the Mac during part of these timings, so take them as approximate. The gain grows with the number of leads, because the data are built once however many there are.

**The speed-up on a real run is not yet measured.** The last ArcticFreshwaters run spent 16,268 s in this stage (309 leads, on a cluster); nothing here shows what it would spend now.

## The whole engine, main against branch (`identity_engine.R`, `identity_engine.txt`, `container_summary.txt`)

Pinned container, 8 GB, 1 core. Every CSV file of a run on each of the 22 toy bundles is **byte-identical** to main (10 to 34 files per bundle).
Only four bundles have Q5 leads, so only these exercise the changed loop:

| Bundle | Q5 leads | Leave-one-out verdicts (stable / unstable) | Stage, main | Stage, branch |
|---|---|---|---|---|
| `planted` | 38 | 31 / 7 | 1.1 s | 0.7 s |
| `spread` | 19 | 4 / 15 | 0.6 s | 5.2 s (see below) |
| `long_div` (longitudinal) | 9 | 2 / 7 | 0.3 s | 0.2 s |
| `presence` | 2 | 2 / 0 | 0.1 s | 0.1 s |

**The 5.2 s on `spread`.** That run also slowed in later, unchanged stages ("build leads" 10.1 s against 0.1 s on main; figures 2.0 s against 1.3 s),
which points to a pause in the run; its cause is not established. Five repeats of the stage on the Mac, outside the container
(`spread_host.R`, `spread_host.txt`): branch 0.29 to 0.35 s, main 0.36 to 0.37 s after a first repeat of 2.73 s, identical results, and the same verdicts as the engine run.

Also in the same container: full package suite 98 tests, 0 failed, 0 errors; validation tests 31, 0 failed; `R CMD check` (tests skipped there) 3 NOTEs.
The new test errored in its first version, run on its own, because it called the engine's internal functions without naming the package.
The test file was corrected while the container ran, before the full suite copied the sources, and the corrected test passed as part of that suite.

## Not changed

Leave-one-out still runs on one core (parallel leave-one-out waits for V-E10b-6). Leave-one-out Q3 is untouched.
