# V-E7(c) G4 re-run on Zhou 2022: the plan, written before any G4 run (2026-11-18)

Ground: G4 of section 9.2 (reproduce the paper's own step, then re-run with the original kept). The coordinator relayed the user's go for Zhou only.

## Why
The first Zhou run (frozen, PR 11) fed the engine the raw tables with only all-zero features dropped. Zhou's own script
(`realdata/code_result/runfun.R`, `preprocess.fun`) does three things first, in this order: (1) drop samples with fewer than 1000 reads;
(2) drop features nonzero in fewer than 10% of the kept samples; (3) winsorise each feature's proportions at quantile 0.97. The coordinator's
message named (1) and (2); step (3) is in the same function, so it is stated here rather than left out. Its design also adjusts IBD for
Antibiotic and SMOKE for Sex plus a subject random effect.

## What is run (two G4 variants, both reported, plus the original which stays as it is)
- `g4f`: steps (1) and (2) only; no covariate. The part the coordinator named.
- `g4`: steps (1), (2), (3) and the paper's covariates: IBD Antibiotic and SMOKE Sex, carried as the engine's `batch` role (the engine's way to
  adjust; whether it adjusts is the engine's own rule R-SPP, recorded in `*_meta.csv`). SMOKE's subject random effect is not expressed: the
  engine's Q4 has no random effect. Recorded, not worked around.
- After the paper's filter every kept feature already meets the engine's own rule (present in 10% of all samples implies 10% of at least one group), so the feature set is the paper's.
- Same engine, same methods (D09, D06, D04, D17, D19), same seeds. Data sets CDI, IBD, RA, SMOKE. Feature tables and group labels only; no reference result file is opened.

## How it is scored
Exactly the frozen rules of 9.5 and the already-pushed `SCORING_MAPPING.md`: same count allowances, same BH q < 0.05 over Zhou's deposited p-values,
same column map. No tolerance, mapping or definition changes. The reference counts are the ones already read in the first scoring; they are not
re-derived. Zhou's group authored LinDA, so G4 alone cannot make Zhou a pass (9.7); the original result stays recorded as not congruent and
is not rescued. If G4 differs it is reported as a finding, both runs side by side.
