# CLAUDE.md: seqcompendium

> **What this file is:** the public development log of seqcompendium, kept as it is
> built with Claude Code (an AI coding assistant). Claude reads it at the start of every
> session; people can read it to see why each design choice was made. The **decisions
> log** records every decision with its reason; pass marks are written here **before**
> the code or data they judge. The **CI fix log** records every CI failure and how it was
> fixed. It names the HPC cluster validation runs on only by name: no accounts,
> usernames or paths.

## Project

seqcompendium is the **compendium engine**: one R package that every pipeline in the
seq- family (seq-resistome, seq-activity, seq-isolates, and adapters for nf-core
outputs) ends with. It takes a samples × features table (or one of the other shapes),
the study metadata and the user's column guide; profiles the data's shape; keeps only
suitable methods; fits a fixed default per shape; checks residuals; runs alternatives
and reports whether they agreed; and ends in a ranked leads table in which negative
results are always shown.

**The approved design is the source of truth:**
`../compendium_engine_design.md` (approved 2026-10-29; all 24 choices accepted as
recommended). D1 below records it. Section numbers (§) in this file refer to that
document.

## Hard rules

- **No research data in the repository, ever.** Test data are invented by scripts with
  fixed seeds, or public data referenced by URL.
- **Nothing about a metadata column is guessed** (seq-triage D95). Roles and types come
  only from the column guide; doubt stops the run, naming the problem.
- **Never pool timepoints** (X0124). **Models write CSVs; figures only read them**
  (X0124).
- **Never choose a method by the real data's p-values** (F4).
- **Negative results are always reported.**
- **Pass marks are written in this file before the code or data they judge.** A failed
  mark blocks: fix it, check nothing else broke, confirm on fresh data. A mark changed
  after it is written, or still failing after one fix-and-reconfirm, goes to the user.
- **Pin every version; every version at least two weeks old when pinned.**
- **Never act on ISCA.** Prepare scripts the user runs there with `sbatchm`.
- **No auto-merge.** Merging needs the user's go-ahead.

## Who decides what

As agreed for seq-resistome (plan §5). Claude decides and logs: code, tests, CI,
versions within the two-week rule, invented test data, bug and CI fixes (each explained
in plain language). Claude stops and asks about: design changes; a pass mark changed
after it was written, or still failing after one fix; publishing (including creating
the GitHub repository); data or licence doubts; changes to seq-triage; money or
credentials.

## Milestones (§12)

| # | Milestone | State |
|---|---|---|
| E0 | Design approved | done 2026-10-29 |
| E1 | Repository and walking skeleton | done 2026-10-29: all 15 marks pass (M14: CI green on PR #1); merged |
| E2 | Pre-registration of the engine's validation (`validation/PREREGISTRATION.md`) | done 2026-10-29 (D11) |
| E3 | S1 counts, snapshot: Q0–Q5, Q7, catalogue filter, fallbacks | — |
| E4 | The override rule (mock check + MIDASim) | — |
| E5 | Longitudinal designs and blocks | — |
| E6 | Report and leads in full | — |
| E7 | Validation, engine v0.1.0; seq-resistome v0.2 calls it | — |
| E8–E10 | S2/S4, S3/S5/external, S7/adapters | — |

## Decisions log

| # | Decision | Reason |
|---|---|---|
| D1 | **The design is approved** (user, 2026-10-29: "Accept all 24"). Fixed inputs: F1–F7 (accepted 2026-10-28), F8 (`sample_control` as a ninth column-guide role, approved 2026-10-28), seq-triage D95, the X0124 rules. Choices C1–C24 taken as recommended, among them: C1 YAML manifest; C2 feature-annotation roles declared by the domain pipeline; C4 the engine carries its own copy of the D95 checks with a shared test set, moving them into the engine (a seq-triage change) proposed later; C6 the rules-file starting values; C7 the default method table (§5.2); C13 a method switch only when the default fails simulated calibration; C16 HTML report from R Markdown plus a Markdown copy; C18 FDR 0.10 for leads; C20 package name `seqcompendium`; C21 R 4.6 with Bioconductor 3.23; C23 mocks give a known-truth check, the simulator is fitted to reference-level study samples; C24 suspected contaminants flagged, never removed. | E0 says the answers become the first entry here. |
| D2 | **The four points left unchecked in the design (§13) were checked on 2026-10-29, all as assumed.** (1) MOFA2 1.22.1 (Bioconductor 3.23) imports basilisk and reticulate and lists Python and mofapy2 under SystemRequirements: it trains in Python, so C11 (leave it out of v1) stands. (2) `seqcompendium` and `compendium` are not on CRAN (crandb: not found; package page 404) or Bioconductor (404), and no GitHub repository is named `seqcompendium`. (3) Bioconductor 3.23 is the current release (2026-04-29, for R 4.6); 3.24 is still devel, so C21 stands. (4) MicrobiomeStat 1.4 (CRAN, 2026-03-03) imports lmerTest, which LinDA uses for random effects; to be confirmed against its help page when LinDA is built (E5). | The design said these would be checked first at E1, and any that failed would go back to the user. None did. |
| D3 | **E1 pins versions by date, not by lockfile.** The container is `rocker/r-ver:4.6.1` pinned by digest (`sha256:bafb3b9a…6a25ef`, pushed 2026-10-15). R 4.6.2 came out today (2026-10-29), so it is too new. CRAN packages come from the Posit Package Manager snapshot dated **2026-10-14**: every package version is whatever CRAN held that day, so every version is at least 15 days old. E1 needs only CRAN packages (yaml, iNEXT, ggplot2, rmarkdown, testthat); the installed versions are written to `provenance/session_info.txt` on every run. The `renv.lock` and the publication-date check script of §11.3 arrive at E3, with the first Bioconductor and GitHub packages, where a date snapshot no longer pins everything. | A dated snapshot pins every CRAN version with one line and makes the two-week rule automatic. A lockfile adds nothing until there are sources the date does not cover. |
| D4 | **Local development uses R 4.5.2 (the R_Bible baseline on this Mac) with a project-only library; the container (R 4.6.1) is the reference.** Packages E1 needs that are missing locally (iNEXT) are installed into a scratch library, never the user's own R library. Every pass mark below is judged in the container. pandoc is not installed on this Mac, so the HTML report is only rendered in the container; locally the Markdown copy is written and HTML is skipped with a message. | Keeps the user's R and R_Bible library untouched; the container is what pipelines will run. |

| D6 | **A seq-triage bug, handled differently here: `missing_codes = none` never takes effect in seq-triage.** Its `read_table()` turns any cell reading `none` into empty, and it reads the column guide with the same function, so the guide's `none` becomes empty and the 99 stop fires anyway, telling the user to write `none` (reproduced at seq-triage fbf74dd). The same rule would also blank F8's `sample_control` value `none`. The engine reads the guide and the metadata with `none` kept, then blanks `none` in every column except the `sample_control` one. Tested: 99 with `missing_codes = none` runs. seq-triage is not changed here (its fix needs the user's approval); the finding is in the shared notes for the session adding `sample_control` to seq-triage. | Found while porting the D95 checks (C4). Copying the bug would have broken F8. |
| D7 | **Small additions made while building E1, all within the design.** (a) Leads status `described` for Q1: mark E1-M8 needs a row for every question, and none of §8.1's four statuses fits a description. (b) Missing-value notes count study samples only: control samples have no design values by construction, so "missing for 3 of 27" was noise. (c) A Q2 cell where one subject has two samples is `not_testable` (the paired model is E5), never tested as if independent. (d) A grouping predictor without `levels` gets `not_testable` for Q2 ("no reference level declared"), not a guessed reference. (e) `run_compendium()` refuses an output folder that already has files, and with `overwrite = TRUE` replaces only a folder it wrote itself. (f) Mock recovery is reported as "not run (E4)": the bundle has no field yet for a mock's known composition; E4 adds one to the manifest. | (a) is a visible addition to the design's status list; the user can veto it. The others close gaps without guessing. |
| D8 | **E1 results (2026-10-29), judged in the container** (R 4.6.1, CRAN snapshot 2026-10-14, pandoc 3.12.1): M1 pass (all files, HTML report rendered); M2 16/16 stop with their problem named, plus the draft guide; M3 5/5 run (plus 99 with `missing_codes = none`); M4 pass; M5 exact; M6 exact (240 checks); M7 copy fixture 6/6 `no_evidence`, planted fixture 4/4 `lead`, 0 pooled rows; M8 pass; M9 pass; M10 pass (fresh R process, bundle deleted); M11 identical; M12 pass; M13 exactly `one_keystroke_typo` fails; M15 pass. **M14 open:** CI needs the GitHub repository, which the user creates. `R CMD check --no-manual`: Status OK. All marks also pass locally on R 4.5.2. No mark needed a fix after it was written. | The walking skeleton works end to end. |
| D9 | **The repository moved to `~/Projects/seqcompendium`** (user, 2026-10-29: "Yes, move them"), out of the iCloud-synced `~/Documents`. The design document stays in `~/Documents/Bioinformatics_pipelines`. | iCloud syncing can corrupt a git repository's internal files. |
| D10 | **E2 pass marks, written before the pre-registration file** (2026-10-29). E2 writes `validation/PREREGISTRATION.md`: the engine's validation, fixed before any simulated or real validation data exist (design §10). E2-M1: it states every mark of design §10 (V-E1 to V-E10 and F8's V-E2b) with the C19 numbers unchanged, each made operational: what is simulated, how many runs, how the number is computed, and the threshold written out as a number. E2-M2: it gives the data-choice rule as steps a script can follow with no choice left (sources, filters, order, how many). E2-M3: it says which marks judge which release (E7, E8, E9, E10), the seeds, where each part runs (Mac or ISCA with `sbatchm`), and what happens on a failure. E2-M4: when it is committed, the repository contains no simulation code and no validation data (`git ls-files validation/` lists only the pre-registration and its checksum). E2-M5: a CI guard fails if the file changes without its recorded checksum changing too, so any later change is visible in a pull request. | Pre-registration is only worth something if it is complete before the data exist and cannot change silently. |
| D11 | **E2 results (2026-10-29).** `validation/PREREGISTRATION.md` written and committed with its checksum. M1 pass: all 11 marks, C19 numbers unchanged, thresholds written out (V-E3 ≤ 0.142 and V-E9 ≤ 0.081 are 0.10 and 0.05 plus 2 Monte Carlo SE at 200 runs). Three places where C19 named something without saying how, now made concrete (the user can veto any): V-E4 counts planted features found by the method actually used after any override; V-E7's "two published analyses" are the first two public datasets of Nearing 2022, compared on the number of significant features per shared method; V-E2 includes rebuilding seq-triage's `tests/study_metadata` cases as bundles (the shared test set of C4). M2 pass: templates from curatedMetagenomicData 3.20.0 (3 shotgun) and MicrobiomeBenchmarkData 1.14.0 (2 16S), both in Bioconductor 3.23, chosen by fixed steps; a source that cannot supply a step goes to the user. M3 pass (§6–§8). M4 pass: `git ls-files validation/` lists only the file and its checksum. M5 pass: `tests/check_preregistration.sh` passes on the file and fails after a one-character change (tested), and runs in the CI guard job. | The engine's validation is fixed before any data exist. |

### D5: E1 pass marks, written before any engine code or test data (2026-10-29)

E1 is the walking skeleton (§12): the thinnest version that runs from end to end, so
every later milestone adds to something that already works. What E1 builds:
`run_compendium(bundle, out)` and `draw_figures(out)`; the bundle reader (§2); the
column-guide checks (a port of seq-triage's `bin/study_metadata.R` per-column checks,
same wording) plus F8's `sample_control`; control handling (§2.10); the shape profile
(§3.1); Q1 description; Q2 alpha diversity (Hill numbers at equal coverage, iNEXT, then
Welch tests per timepoint and block); the leads table; the report; one figure;
provenance; the container; a CI workflow.

What E1 does **not** build, and says so in its outputs (status `not_asked`, reason
"not built yet, milestone E…"): Q0 and Q3–Q11, the catalogue filter, agreement sets,
fallback ladders, the override rule, leave-one-out, tiers beyond what Q2 alone allows.

Toy data: invented by `inst/scripts/make_toy_bundle.R` with fixed seeds. It is not
research data and resembles no real study.

| Mark | What is tested | Pass |
|---|---|---|
| E1-M1 End to end | The main toy bundle (2 groups × 2 timepoints × 6 subjects, 30 toy features, 2 extraction blanks, 1 mock) runs through `run_compendium()` without error and writes every E1 file in the §9 layout | all files present |
| E1-M2 Guide stops | Each of these stops the run with a message naming the column or value: no guide (and `column_guide_draft.csv` written); a metadata column missing from the guide; a guide row for a column not in the data; unknown role; unknown type; a value outside `levels`; a value contradicting its type; one-keystroke typo pair in an unlevelled categorical column; conventional missing code (99) in a numeric column without `missing_codes`; an unknown `sample_control` value; a `sample_control` value that is a typo of a listed one; a column with role `sample_control` whose `levels` list a value outside the closed list; a layer declared `count` with a non-whole value; a missing sample × feature row (implicit zero); a layer sample not in the metadata; a manifest naming a missing file | 16 of 16 stop, each naming its problem |
| E1-M3 Must not stop | The main toy bundle; the same with CRLF line endings; with an extra `ignore` column; with no controls; with digit-only level series (A1/A2) | 5 of 5 run |
| E1-M4 Controls | No control sample appears in any Q1 or Q2 result or in the profile's study-sample counts; every control is in `00_input_check/controls.csv` with its kind; a design with no controls writes the no-controls warning in the report and `no_controls` on every lead | 100% |
| E1-M5 Profile | `shape_profile.csv` has a `source` for every row; n samples, n features, % zeros and library size min/median/max equal an independent computation in the test | exact |
| E1-M6 Q1 | Prevalence and median per feature per group × timepoint equal an independent computation | exact |
| E1-M7 Q2 behaves | On a fixture where group B is an exact relabelled copy of group A, every Q2 row is `no_evidence`; on a fixture with a planted large diversity difference (B's counts concentrated in 3 features), every q = 1 and q = 2 row is a `lead`. Contrasts are per timepoint: no Q2 row has timepoint `all` | both fixtures as stated; 0 pooled rows |
| E1-M8 Leads table | `leads.csv` has every §8.1 column (values not built yet are `NA` or `not run`, never absent); every question Q0–Q11 has at least one row; Q2's q-values are Benjamini–Hochberg within each contrast × timepoint × block | 100% |
| E1-M9 Report | HTML (container) and Markdown written; sections in order: input check, controls, design as read, profile, Q1, Q2 with the five parts of §7, "What was not found" **before** the leads | 100% |
| E1-M10 Figures read CSVs only | `draw_figures()` run in a fresh R process on a copy of the output folder with the bundle deleted draws the Q2 figure; its caption names its source CSV | passes |
| E1-M11 Reproducible | Two runs on the same bundle give byte-identical CSVs | identical |
| E1-M12 Container | `docker build` succeeds from the pinned base and the 2026-10-14 snapshot; the tests and M1 pass inside it, with the HTML report rendered | passes |
| E1-M13 Negative control | With the one-keystroke typo check switched off, exactly its M2 test fails | exactly one fails |
| E1-M14 CI | The GitHub Actions workflow runs the tests and the container end to end on a pull request, green | green (needs the GitHub repository, which the user creates) |
| E1-M15 No research data | The repository contains no data file other than those the toy script writes | none |

## CI fix log

(none yet)
