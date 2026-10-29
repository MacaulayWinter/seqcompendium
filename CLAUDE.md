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
| E1 | Repository and walking skeleton | in progress |
| E2 | Pre-registration of the engine's validation (`validation/PREREGISTRATION.md`) | — |
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
