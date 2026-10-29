# Pre-registration: how the compendium engine is validated

Written 2026-10-29 (milestone E2), **before any simulation code, simulated data or
validation data exist.** The commit that adds this file is the proof of the date.
Source: design §10 (`compendium_engine_design.md`, approved 2026-10-29), with the pass
marks the user accepted as choice C19, unchanged. This file makes each one operational:
what is simulated, how often, how the number is computed, and the threshold as a number.

**This file is frozen.** `validation/PREREGISTRATION.sha256` holds its checksum, and CI
fails if the file changes without the checksum changing too, so any change shows in a
pull request. A mark is never changed after this commit without the user's approval,
logged in `CLAUDE.md`.

## 1. Words used below

- **Run**: one simulated bundle passed through `run_compendium()`.
- **Scenario**: one combination of template, design and group size; it has many runs.
- **Lead**: a leads-table row with status `lead` (tier 1 or 2; q ≤ R-FDR = 0.10).
- **Monte Carlo SE** (MC SE) of a rate with nominal value p over n runs:
  √(p(1 − p)/n). Thresholds below are written out with it already added.
- **Release**: the engine version a milestone ends with: E7 → v0.1.0, E8 → v0.2.0,
  E9 → v0.3.0, E10 → v0.4.0. Each release is judged only on the shapes it adds or
  changes, plus every mark again for shapes already released (regression).

## 2. The data-choice rule (the templates)

Simulators are fitted to real public data ("templates") so the simulated data look like
real data. The templates are chosen by these steps, which leave no choice open. They are
downloaded when validation runs, on the machine that runs it, and **never committed**.

**Shotgun templates (3)**, from Bioconductor package `curatedMetagenomicData` 3.20.0
(Bioconductor 3.23):

1. Take the table `sampleMetadata`.
2. Keep rows with `body_site == "stool"`, `study_condition == "control"` and a
   non-missing `number_reads`.
3. Keep one row per `subject_id`: the smallest `days_from_first_collection` (missing
   counts as 0), ties broken by `sample_id` in C-locale alphabetical order.
4. Count rows per `study_name`; keep studies with at least 20.
5. Sort the remaining `study_name`s in C-locale alphabetical order; take the first 3.
6. Fetch them with `returnSamples(<rows>, "relative_abundance", counts = TRUE)`: species ×
   sample estimated read counts.

**16S templates (2)**, from Bioconductor package `MicrobiomeBenchmarkData` 1.14.0
(Bioconductor 3.23):

1. Take the package's list of datasets; keep those its documentation describes as 16S.
2. For each, take the group of samples, by the dataset's own grouping column as named in
   the package documentation, that has the most samples; keep the dataset if that group
   has at least 20.
3. Sort the dataset names in C-locale alphabetical order; take the first 2.

If either source cannot supply what a step needs (a column missing, fewer templates than
asked), that is a data doubt: it goes to the user before anything is run. It is never
patched by choosing other data.

**Shapes with no public template** are simulated from parametric models only: S2 when it
is not derived from a shotgun template (below), S3 (presence/absence on a tree), S4 (paired
RNA/DNA), S5 (pairs), S7 (layers built from the S1 and S2 templates on shared samples).

## 3. Simulators and how effects are planted

- **S1 counts.** MIDASim (CRAN 2.0) fitted to each template, simulating counts at the
  template's library sizes. **Planting**: a set of features is multiplied by the fold
  change in one group on the absolute scale before counts are drawn, so observed shares
  shift through renormalisation as they do in real data. Planted features are drawn at
  random from those present in at least 50% of the template's samples.
- **S2 proportions.** The S1 simulation divided by each sample's total.
- **S3.** A random tree (`ape::rtree`) of the stated size; gene presence evolves on the
  tree (Mk model, `ape::rTraitDisc`); a binary phenotype evolves on the same tree;
  planted genes change the phenotype's odds by a stated factor.
- **S4.** DNA counts as S1; RNA counts negative binomial with mean
  DNA × expression rate × library factor; planting changes the expression rate in one
  group, leaving DNA unchanged.
- **S5.** Pairs among simulated samples; shared/not shared drawn from a pair-level model
  with a random effect for each member of the pair; planting changes the odds for one
  pair-level covariate.
- **Controls (F8).** Two extraction blanks per bundle carrying 5 "contaminant" features at
  low counts; one mock per bundle with 8 features at equal known abundance.

## 4. Seeds

Master seed **20261029**. Scenarios are numbered in the order of the tables below
(template, then design, then group size, then repeat); run *k* of scenario *s* uses seed
`20261029 + 1000 × s + k`. Every run records its seed in `provenance/engine.yaml`.

## 5. The marks

| Mark | What is simulated | Number computed | Pass |
|---|---|---|---|
| **V-E1 Triage** | One bundle for every combination of shape (S1–S7) × design class (snapshot-independent, snapshot-paired, longitudinal) × blocks (none, one block column): 42 bundles, each with its true design written by the generator before the run | Share of bundles where `shape_profile.csv` (shape, unit, design class, predictors, blocks, timepoints, subjects) equals the generator's truth | **100%** |
| **V-E2 Guide obedience** | (a) For each role, a bundle where one column's role is changed in the guide; (b) a column with role `ignore`, and a column absent from the guide; (c) a bundle with no guide; (d) every stop and must-not-stop case in seq-triage's `tests/study_metadata` test set, rebuilt as bundles | (a) the analysis changes as the new role says; (b) the column appears in no model formula or result; (c) the run stops and writes the draft; (d) every case stops or runs as it does in seq-triage, with the same message, except where `CLAUDE.md` D6 records a deliberate difference | **100%** |
| **V-E2b Controls (F8)** | The V-E1 bundles with their controls; the same with one control value changed to an unknown value and to a one-keystroke typo; the same with no controls; 100 S1 bundles with 5 planted contaminants present in the blanks | No control sample in any Q1–Q11 result; the stop names the value; every control in `controls.csv`; the no-controls warning written; share of planted contaminants flagged by Q0 | First four **100%**; contaminants flagged **≥ 80%** (rule of thumb, unverified) |
| **V-E3 Null calibration** | Every template × design (2-group snapshot, 3-group snapshot, 2 groups × 2 timepoints longitudinal, 2 groups × 2 blocks) × n per group (5, 10, 20), with **no planted effect**; **200 runs** per scenario | For each scenario and question family (Q2, Q3, Q4, Q5, Q7, and Q6 where longitudinal), the share of runs with **any** lead | **≤ 0.142** in every scenario and family (0.10 + 2 MC SE at n = 200) |
| **V-E4 Recovery** | Every template; 2-group snapshot; **10 per group**; 10% of features planted at **fold change 2**, chosen among features present in ≥ 50% of samples; **200 runs** per template | Planted features reported as Q4 leads (by the method the engine used, after any override), divided by planted features, pooled over the 200 runs | **≥ 0.80** per template (rule of thumb, unverified) |
| **V-E5 Override** | Per template, n = 10 per group, **100 runs** of each: (i) well-behaved: MIDASim null with no change to the template; (ii) known-miscalibrated: a strong compositional shift (3 dominant features × 10 in one group, nothing else changed); (iii) heavy zero inflation (50% of each feature's non-zero values set to zero). A scenario counts as "default miscalibrated" when the default Q4 method's FDR, measured on 200 separate runs of that scenario with known truth, exceeds R-CAL × R-FDR = 0.20 | Share of runs in which the override rule (design §5.3) switches away from the default | Where the default is miscalibrated: switches **≥ 90%**. Where it is not: keeps the default **≥ 90%** |
| **V-E6 Diagnostics** | Per model family (NB GLM, linear model on Hill numbers, PERMANOVA, logistic GLM): 100 datasets with a planted violation (overdispersion beyond the model; 50% structural zeros; unequal group spread with unbalanced groups; separation) and 100 clean datasets drawn from the model's own family | Share of violated features (or tests) flagged by the residual checks; share of clean ones flagged | Flagged **≥ 90%**; clean flagged **≤ 10%** |
| **V-E7 Reference results** | (a) Every R_Bible worked example for a method that is an engine default in the release (located by the catalogue's `r_bible_section`); (b) two datasets from Nearing 2022 (doi:10.1038/s41467-022-28034-z): the first two in C-locale alphabetical order whose data are public, for every method the engine shares with that paper | (a) the engine's estimates vs the R_Bible's; (b) the number of significant features per method vs the paper's supplementary table | (a) equal to **1e-6** (same code path); (b) equal **within the published rounding**; a difference explained only by a package version is reported, not passed |
| **V-E8 Honesty** | Every V-E1 and V-E3 run | Every asked question has a leads row; every p-value floor equals 2/choose(2n, n) recomputed for its smallest group; `draw_figures()` succeeds on a copy of the output with the bundle deleted; no result row has timepoint `all` except Q6 | **100%** |
| **V-E9 Pairwise** (E9) | S5 bundles, 50 and 200 pairs, no planted effect, **200 runs** each | Share of runs where the pair-level test gives p < 0.05 for the null covariate | **≤ 0.081** (0.05 + 2 MC SE at n = 200). The `thin_evidence` flag stays on every pairwise result regardless |
| **V-E10 Reproducibility** | 5 bundles (the main toy and 4 V-E1 bundles, the first 4 in table order) | Run twice with the same engine version and container | **Byte-identical** CSVs |

## 6. Which marks judge which release

| Release | Shapes added | Marks run |
|---|---|---|
| E7, v0.1.0 | S1 (snapshot, longitudinal, blocks) | V-E1 (S1 rows), V-E2, V-E2b, V-E3, V-E4, V-E5, V-E6, V-E7, V-E8, V-E10 |
| E8, v0.2.0 | S2, S4 | the same marks for S2 and S4 rows (S4 gets V-E3/V-E4 with RNA as the response); all v0.1.0 marks again |
| E9, v0.3.0 | S3, S5, external results | V-E1, V-E3 (S3: Q8), V-E4 (S3: planted genes, odds ratio 4, 100 isolates), V-E8, V-E9, V-E10; all earlier marks again |
| E10, v0.4.0 | S7, adapters | V-E1 (S7 rows), V-E3 (Q11), V-E8, V-E10; adapters: each adapter's bundle equals one written by hand from the same input; all earlier marks again |

## 7. Where it runs

- **On the Mac**: V-E1, V-E2, V-E2b (first four parts), V-E7, V-E8 on the V-E1 bundles,
  V-E10.
- **On ISCA**: the grids of V-E2b (contaminants), V-E3, V-E4, V-E5, V-E6 and V-E9. Claude
  writes them as array-job scripts under `validation/isca/`, submitted by the user with
  `sbatchm`, and never acts on ISCA itself. The scripts contain no email address.
- Results are written as one table per release, `validation/results/<release>/marks.csv`
  (mark, scenario, number, threshold, pass), with the seeds and the container digest.

## 8. When a mark fails

1. The release stops. Nothing that depends on it moves on.
2. The cause is found and fixed once. Every other mark is run again (regression check).
3. The failed mark is confirmed on **fresh data**: new seeds (`+ 500000`), and for
   template-based marks the next templates in the data-choice order (the 4th and 5th
   shotgun, the 3rd 16S).
4. If it still fails, or the fix would need a mark or a decided design choice changed,
   it goes to the user. A mark is never quietly loosened.
