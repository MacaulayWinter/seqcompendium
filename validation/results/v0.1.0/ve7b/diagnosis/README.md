# V-E7b diagnosis, ArcticFireSoils (2026-11-11)

Minutes-long runs on the Mac (one container, 6 GB), with the engine's own functions on
the same 147-sample, 3,656-feature table as the cluster run (CLAUDE.md D52). The FAIL in
`../README.md` stands; no mark is changed and nothing here re-scores task 1.

| Method | Cluster run (V-E7b) | Direct run on the Mac | Paper |
|---|---|---|---|
| ALDEx2 | 0 | 288 (BH of we.ep, the engine's count); 322 (we.eBH); 403 (wi.eBH) | 525 |
| Wilcoxon (CLR) | 2252 | 2252 (pseudocount 0.5); 2286 (pseudocount 1) | 2101 |
| LEfSe | 1 (really 0: did not run) | did not run as the engine calls it; 436 with relative abundance scaled to 1e6; 369 if features constant within a group are also dropped | 1978 |

Reading:

- **ALDEx2, 0 on the cluster:** the engine's own ALDEx2 call gives 288 here, so the 0
  means ALDEx2 failed inside the cluster run. The engine's agreement step
  (`q4_agreement`) catches the error and writes "the method failed to fit" with no
  reason. The comparison script then counted no p-values as 0. Why it failed there
  is unknown, because the reason was discarded. ALDEx2 alone peaks near 5.6 GB on this
  table: a second call in the same 6 GB container was killed (`ve7b_direct2.log`). The
  cluster task had 32 GB, so memory is not shown to be the cause.
- **ALDEx2, 288–403 against 525, and Wilcoxon 2252 against 2101:** the engine runs these
  methods as designed. The gaps come from package versions (ALDEx2 1.44 against the
  paper's R 4.0-era version, with its Monte Carlo draws) and the paper's own
  preprocessing. These are genuine differences, not engine defects.
- **LEfSe:** an engine defect. The engine passes proportions between 0 and 1. lefser
  expects relative abundance scaled to a million (it warns "Convert counts to relative
  abundances with 'relativeAb()'"). On 0–1 values the within-group variances fall
  below MASS::lda's tolerance, so the LDA stops with "variables ... appear to be
  constant within groups". Scaled to 1e6 it runs and gives 436. The remaining gap to
  1978 is lefser 1.22 against the paper's Python LEfSe.

Files: `ve7b_direct.log` is the first pass; it stopped at the second lefser call after
printing its counts. `ve7b_direct2.log` is the ALDEx2 pass, killed at 6 GB after its first
count. `ve7b_direct2_lefse.log` and `ve7b_direct2_ArcticFireSoils_lefse.csv` hold the
LEfSe variants. The long lists of variable numbers in lefser's message are cut at 400
characters.
