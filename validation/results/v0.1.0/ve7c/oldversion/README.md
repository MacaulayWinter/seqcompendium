# V-E7(c) section 11: older-version tests on Wallen 2021 (a post-result diagnostic)

**This is a post-result diagnostic. It changed no 9.5 result and no 9.7 outcome.** Section 11 was written after the Wallen counts had been read (section 11.6 says so),
approved by the user on 2026-11-21 and merged before any run here. Run 2026-11-21 on the Mac, one container, 8 GB, 1 core, engine source `main` at 39556c6.

## Result, plainly: no method is version-explained

Counts of features at BH q < 0.05, 10% prevalence tables. "Allowance" is the 9.5 rule-1 allowance (the section 11 test; no new tolerance).

| Method (old version) | Data set | Old version | Paper | Current engine | Allowance | Version-explained? |
|---|---|---|---|---|---|---|
| ALDEx2 1.22.0 | 1 | 1 | 11 | 1 | 2 | **No** |
| ALDEx2 1.22.0 | 2 | 13 | 30 | 13 | 2.4 | **No** |
| ANCOM-BC 1.0.5 | 1 | 45 | 31 | 139 (ANCOM-BC2) | 1.55 | **No** |
| ANCOM-BC 1.0.5 | 2 | 161 | 81 | 371 (ANCOM-BC2) | 4.05 | **No** |

- ALDEx2: the old version gives exactly the current engine's counts, so the package version does not explain the gap to the paper.
- ANCOM-BC 1.0.5: far closer to the paper than ANCOM-BC2, and rule 2 (sign agreement 100%) and rule 3 (Spearman 0.92 and 0.87; threshold 0.8) are met on both data sets, but the counts are still outside the allowance, so the label is not earned (11.3).
- Every method line of V-E7(c) stays **not congruent**; nothing is re-scored.

## Not testable (said plainly)
- **LEfSe 1.0.8: not testable.** The paper used the Huttenhower LEfSe tool; only version 1.1.2 is on PyPI, and the container has no conda. The engine uses the R package lefser, a different tool.
- **Wilcoxon on CLR: not testable.** It has no package version (base R).

## Caveat on ANCOM-BC 1.0.5
The call mirrors the engine's own D06 settings (no prevalence or library cut, BH, alpha 0.05, one group term); **the paper's own call was not read.** A remaining gap could still be a difference in settings, not in the version.

## Files
`ve7c_oldversion_lines.csv` the 9.5 judgement lines; `aldex_1.22.0/`, `ancombc_1.0.5/` the quick-count tables of each run (results, not data; each run also re-ran the engine's other methods, whose counts equal the frozen ones);
`install_results.txt` which old versions installed; `run_times.log`; `scripts/` the install script, the wrapper that swaps one method for its old version (the unchanged `ve7c_quick.R` does the rest) and the scorer.
