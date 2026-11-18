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

## 9. Reference marks for the differential-abundance claim (Q4): V-E7(c)

Added 2026-11-16, after the V-E7(b) result on ArcticFireSoils and **before any reference named below has
been run or its numbers opened.** Sections 1-8 are unchanged. V-E7(b) stays in §5 and its result stays on
record. Decisions: see `CLAUDE.md` (D58, the principle; and the entry for this section).

### 9.1 Why

A published number is not infallible. A mark that compares the engine with one paper can fail because the paper
is wrong, and can pass because the paper shares the engine's mistake. This section judges the Q4 claim against
**at least three independent references**, chosen blind to their numbers.

### 9.2 Grounds for reasonable doubt about a reference (the only four)

A failed comparison is **never** by itself a ground. Doubt about a reference is accepted only on these grounds,
each checkable by someone who does not know our result:

- **G1 Old or unavailable software:** the paper's tool or versions cannot be installed any more, or are years
  older than anything the engine can run; evidence: the paper's methods name versions that no longer install, or
  the repository is gone.
- **G2 Underspecified methods:** the paper does not say how its number was computed, so it cannot be repeated;
  evidence: a count has more than one reasonable definition, the paper gives none, and the paper's value is reached
  by none of the reasonable ways.
- **G3 Self-inconsistent counts:** the paper's own numbers contradict each other (a count above the number of
  features tested; text and supplement differ).
- **G4 A documented pre-processing difference that moves our number across the paper's:** reproducing the
  paper's step (not just arguing it) and re-running crosses the paper's number; the repeat run is kept.

Not grounds: "the engine disagrees", "the paper is old", "other papers disagree with it".

### 9.3 How references are chosen

A reference is **independent** if it is a different paper, with different data, and not by the same group or the
authors of a method it tests. Several data sets from one paper are **one** reference. Rules, applied in order
before any reference's numbers are opened:

1. Data are public and **actually deposited** (the deposit's file listing holds the feature tables).
2. The paper's counts of significant features, or effect sizes, for methods the engine shares are in **a table or
   a deposited results file**; a count that exists only in a figure is allowed only if the pre-registration says so
   below and names the reading error.
3. The software is installable (older versions allowed if each can be installed in a separate library).
4. Among papers that meet 1-3, **alphabetical order of first author** (C-locale) breaks ties.
5. A reference cannot be dropped after its numbers are seen. If it is dropped for a reason fixed here (its data
   prove unreadable), it is replaced by the next in order and the swap is reported.

**Planted-truth data** (the engine's own generator) counts as **one** of the three, not an extra.

### 9.4 The Q4 reference list (fixed; approved by the user 2026-11-16)

| # | Reference | What is compared | Limits (written here, before any run) |
|---|---|---|---|
| 1 | **Planted truth** | V-E3 and V-E4 on **fresh** templates (the 4th and 5th shotgun and the 3rd 16S in the §2 order), with new seeds (+ 500000, §8 step 3) | none beyond the marks' own |
| 2 | **Wallen 2021** (BMC Bioinformatics 22:265, doi 10.1186/s12859-021-04193-6; sole author, Univ. of Alabama at Birmingham) | Counts of features with q < 0.05 per method, on its two Parkinson's cohorts, from its supplementary Tables S3-S6 and the deposited per-method results (GitHub `zwallen/Wallen_DAMethodCompare_2021`, phyloseq objects `PhyloseqObjects/Dataset1` and `Dataset2`) | (a) **Older package versions** (R 4.0.5; ALDEx2 1.22.0, DESeq2 1.30.1, ANCOM-BC 1.0.5, edgeR 3.32.1, LEfSe 1.0.8); a difference explained only by a version is reported, not passed, and can be tested in a separate library. (b) **No raw-read accession**; only the phyloseq objects are deposited. (c) **One group, two cohorts: one reference.** (d) The paper has unfiltered and 10%-prevalence variants; **the 10% variant is compared** (the engine's R-PREV = 10%). (e) Author check, §9.9 |
| 3 | **Zhou 2022** (Genome Biology 23:95, the LinDA paper; Zhou and co-authors) | Counts of features per method across FDR levels on its four real data sets (CDI, IBD, RA, SMOKE), from the deposited scripts and outputs (Zenodo doi 10.5281/zenodo.6326019, 5.0 MB) and the paper's figures | (a) **Method-author reference, not neutral:** the authors developed LinDA, one of the engine's methods. (b) **LinDA is scored on its own line** (it reproduces its authors' own code); ALDEx2, Wilcoxon and the ANCOM-BC family count towards "congruent". (c) Counts that exist only in a figure are read with the reading error stated in 9.6 *before* the figure is read. (d) Package versions are mostly unstated (R 4.0.3 only) |
| optional 4th | **Pelto 2025** (Brief Bioinform; Univ. of Turku), the authors' script run by us | The 14 methods run with the authors' own `run_daa_methods.R` on their curated data, versus the engine's Q4 methods on the same data sets | **Not independent of Pelto's code; not a published count; cannot count towards the three.** Adds evidence beyond the minimum. Subset rule, 9.8 |

**What is counted.** For every published reference, the compared quantity is the **quick count**: the number of features with BH q < 0.05 from the
engine's own Q4 methods run on the reference's feature table with the engine's prevalence rule, **without the override check** (9.12). A
full-engine run is an extra report and is never the mark.

**The method-author rule.** At least **one** published reference must come from authors with no interest in an
engine method. Here that is Wallen 2021. A pass needs it. Zhou 2022 alone can never carry the verdict that a
different reference was poor. The report and the release notes name which references are by method authors.

### 9.5 What "congruent" means (frozen before any run)

For each published reference, **per method the engine shares with it** (LinDA scored on its own line):

1. **Count agreement.** The engine's count of features at BH q < 0.05 differs from the reference's by at most
   **max(t_rel x the reference's count, t_abs)** features, with t_rel and t_abs fixed per method by the repeat
   measurement of 2026-11-16 (below). For a count read from a figure, the allowance is also never less than
   **twice the reading error**, stated in 9.6.

   **How the allowance was measured (before any reference was run or opened).** The engine's Q4 methods were run on
   the feature tables of Wallen 2021 (two Parkinson's disease cohorts: 333 samples and 6,844 taxa; 507 samples and
   12,198 taxa), with the engine's own seeds and then 10 shifted seed sets (11 runs per method and table), at the
   10% prevalence filter. The paper's counts were not read. Spread of the counts over the 11 runs:

   | Method | Table 1 counts | Table 2 counts |
   |---|---|---|
   | LinDA (D09, the default here) | 43 in all runs | 104 in all runs |
   | ANCOM-BC2 (D06) | 139 in all runs | 367 in all runs |
   | Wilcoxon on CLR (D17) | 14 in all runs | 54 in all runs |
   | LEfSe (D19) | 64 in all runs | 60 in all runs |
   | ALDEx2 (D04) | 1 to 3 | 13 to 14 |

   **Rule for the allowance.** t_rel = the larger of 5% and the observed range as a share of the mean on the table
   where the method's mean count is larger; t_abs = the largest observed range in features over the two tables.
   Values: **LinDA, ANCOM-BC2, Wilcoxon on CLR and LEfSe: t_rel = 5%, t_abs = 0** (no variation was seen, so the
   5% floor applies; it stands for package-version and pseudocount differences, the pseudocount alone moving one
   count by 1.5% in the 2026-11-11 diagnosis). **ALDEx2: t_rel = 8%** (7.5% on table 2, rounded up) and
   **t_abs = 2 features** (the range on table 1; a relative allowance alone would be 88% there and mean nothing).
   Evidence: `validation/results/v0.1.0/tcount/`.
2. **Direction.** Of the features significant in both, at least **95%** have the same sign of effect.
3. **Ranking.** Where the reference publishes feature-level results, the Spearman correlation of effect sizes
   across features significant in either is at least **0.8**. If it publishes only counts, rule 3 does not apply
   to it, and the report says so.

The numbers 95% and 0.8 are fixed here. A reference is **congruent** if every method (other than
LinDA) meets all three rules that apply; LinDA's line is reported, and counts towards "congruent" only for
references that are not by LinDA's authors.

**Planted truth** is congruent when V-E3 (null calibration, ≤ 0.142) and V-E4 (recovery, ≥ 0.80) both pass on the
fresh templates.

A tolerance is never changed after a result is seen.

### 9.6 Reading counts from a figure

If a count exists only in a figure (parts of Zhou 2022; Weiss-type cases), a **reading error** is fixed first: a second independent reading is not available, so the error is taken as **half the smallest tick interval of the
axis**, written down before the figure is read, and the figure is read once. A deposited file that gives the
value replaces the reading.

### 9.7 Outcomes (fixed in advance)

N = the number of independent references actually run (counting planted truth).

| Result | Status of V-E7(c) | What is said |
|---|---|---|
| N ≥ 3 and every reference congruent, including the method-author-free one | **Pass.** The engine works on Q4; the first reference (Nearing 2022) was a poor reference for it | Each reference's numbers and its ground (9.2) are reported |
| Planted truth fails | **Fail**, whatever the papers say | The engine is wrong on known truth |
| Planted truth congruent, some published reference not | **Unresolved; not a pass** | Each failure reported by name; the mark stays failed until the user decides |
| Planted truth congruent, no published reference congruent | **Fail** | The engine agrees only with itself |
| N < 3, or the method-author-free reference cannot be run | **Not confirmed**, never a pass | Said plainly |

There is no selection to a pass: all references are run and reported; a pass needs all.

### 9.8 The optional fourth reference: dataset-subset rule (Pelto 2025)

Applies only if run; it never changes the outcome table above.
- From the **50 separate-study data sets** in the authors' curated data (the data `.rds`, not any result file),
  keep 16S data sets with **fewer than 150 samples**; sort by data-set name in **C-locale alphabetical order**; take
  the **first 5** (a size and Mac-time choice, written before any data set is opened).
- The authors' script is run **unchanged**, at the authors' defaults, in a separate library at its stated versions
  where installable; the engine's Q4 methods are run on the same 5 data sets.
- Congruence per method, as 9.5; because both sides are our runs, the allowance is the repeat variation measured on our own data for the same method and tables, with no reading-error term
  (no floor from a figure). LinDA on its own line.
- No result file in the deposit is opened before this section is merged.

### 9.9 The author check for Wallen 2021 (recorded 2026-11-16, read-only)

The sole listed author is Zachary D. Wallen (Department of Neurology, University of Alabama at Birmingham), from
PubMed. The engine's methods and their authors, to the best of my knowledge: ALDEx2 (Fernandes, Gloor and co-authors),
ANCOM and ANCOM-BC (Mandal, Lin, Peddada and co-authors), DESeq2 (Love, Huber, Anders), edgeR (Robinson, McCarthy,
Smyth), limma (Smyth and co-authors), metagenomeSeq (Paulson and co-authors), LEfSe (Segata and co-authors), LinDA
(Zhou and co-authors). No overlap with Wallen. His repository's own `DAreport` function is his own reporting code, not an
engine method. **Recorded as: no known stake in an engine method; the author-name comparison is from memory and a one-line
PubMed check, not an independent conflict-of-interest declaration.**

### 9.10 No rescuing

- **V-E7(b) on ArcticFireSoils stays a recorded fail** (engine 288 / 2252 / 436 against 525 / 2101 / 1978;
  `validation/results/v0.1.0/ve7b_fixed/`). It is not edited, softened or re-scored by this section.
- Nearing 2022 stays a recorded reference with its fail; it is not one of the three.
- This section applies to **V-E7(c)** and to marks written after it. It is not applied back to any earlier result.
- The ArcticFreshwaters task of the rerun is scored under V-E7(b) as pre-registered, as a second data point, and does
  not change the above.

### 9.11 The release (tag) rule

- v0.1.0 is tagged only when every pre-registered mark passes, **where V-E7(c) is the gate for the claim V-E7(b)
  tested** (the user's approval, 2026-11-16; the old V-E7(b) fail stays in the release notes beside it).
- Until V-E7(c) passes, no tag. Runs happen only after E7 has merged.

### 9.12 Where and when it runs

**V-E7(c)'s counts are quick counts for every published reference**: the engine's Q4 agreement and describe-only methods and the default's fit
(as `validation/ve7b_quick.R` does), with **no override check**. A full-engine run on a reference is an **extra report, never the mark**, so a
limit of the override check (for example, too few common features on a sparse table for its planted draw) cannot stop or change the mark.
The counts of each method do not depend on the override check, which only chooses the default. Quick counts run on the Mac for the small data
(Wallen's two tables are about 3 MB); anything too large for the Mac runs the same quick-count script on ISCA, by scripts Claude prepares and the
user submits (no email, account or path in them). The planted-truth marks run as V-E3 and V-E4 do. Results go to `validation/results/<release>/`
as small tables only.
