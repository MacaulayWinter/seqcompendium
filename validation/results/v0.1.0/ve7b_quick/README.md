# V-E7b interim counts on the Mac (CLAUDE.md D56): not the final result

Run with `validation/ve7b_quick.R` on engine 55013ec (the D55 fixes), 2026-11-12/13,
one container (8 GB for ALDEx2, 6 GB otherwise; 1 core). It runs the three counted
methods the way the engine's Q4 does, but skips the rest of the run (including the
override check). **The full engine run on ISCA (job submitted 2026-11-12) is final.**
ALDEx2 on ArcticFireSoils is not here: it needs more memory than the Mac allows and
comes from the ISCA run.

| Data set | Method | Engine (interim) | Paper |
|---|---|---|---|
| ArcticFireSoils | Wilcoxon (CLR) | 2252 | 2101 |
| ArcticFireSoils | LEfSe | 436 | 1978 |
| ArcticFreshwaters | ALDEx2 | 667 | 184 |
| ArcticFreshwaters | Wilcoxon (CLR) | 958 | 255 |
| ArcticFreshwaters | LEfSe | 710 | 239 |

No count equals the paper's, so on these numbers V-E7b (PREREGISTRATION §5, "equal
within the published rounding") would fail. Every method ran (`method_failed` is FALSE).
ArcticFreshwaters reached the test with 934 samples (Lake 471, Watershed 463).
