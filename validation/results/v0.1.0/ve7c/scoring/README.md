# V-E7(c) scoring, run once on 2026-11-18 (`validation/ve7c_run_score.R`, mapping in `../SCORING_MAPPING.md`, written and pushed before any value was read)

`ve7c_method_lines.csv` one row per reference, data set and method: engine count, reference count, allowance (9.5 rule 1), count_ok, sign agreement, Spearman, ok.
`ve7c_references.csv` per reference: congruent or not. `ve7c_outcome.txt` the 9.7 outcome with what has been run. `ve7c_zhou_matrix_match.txt` which Zhou matrix is which data set (by row names).
Reference files' checksums: `reference_files_*_SHA256SUMS`. Planted truth (V-E3 and V-E4 on the fresh templates) is **not yet run**, so the outcome reads "Not confirmed".

**Result, plainly:** neither published reference is congruent. Wallen 2021: of 8 method lines (4 methods x 2 data sets) only Wilcoxon on CLR on data set 2 meets the count rule (42 against 41). Zhou 2022: of the 12 lines other than LinDA, only ALDEx2 on CDI and on IBD meet it; LinDA's own lines meet it on CDI only. No tolerance, mapping or definition was changed after the numbers were seen.
