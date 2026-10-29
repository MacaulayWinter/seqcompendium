# seqcompendium

**The compendium engine** for the seq- family of pipelines (seq-resistome, seq-activity,
seq-isolates, and adapters for nf-core outputs). Every pipeline in the family ends by
calling it.

You give it a **bundle**: a samples × features table, your study metadata, and your
**column guide** (one row per metadata column, saying what it is). It writes a
**compendium**: a folder of CSV results, figures drawn only from those CSVs, a
plain-language report, and a ranked **leads table** of things worth a closer look, in
which negative results are always shown.

> **Status: milestone E3.** For count tables at a single timepoint (each timepoint and
> block compared on its own) it asks Q0 (likely contaminants, from your negative
> controls), Q1 (what is there), Q2 (alpha diversity), Q3 (composition), Q4 (differential
> abundance), Q5 (differential presence) and Q7 (feature sets). Each has a fixed default
> method, residual checks with written-down fallbacks, and alternative methods whose
> agreement is reported. Longitudinal models, the simulation check of the default, and
> the other data shapes come in later milestones; every question not built yet appears
> in the leads table with the milestone that adds it. Not validated yet (that is E7): not
> for real analyses.

## Rules it never breaks

- **Nothing about a metadata column is guessed.** Roles and types come only from your
  column guide. If the guide and the data disagree, or a value looks like a typo, the
  run stops and names the problem.
- **Control samples** (blanks, mock communities) are declared in the guide (role
  `sample_control`) and never analysed as biology.
- **Timepoints are never pooled.** Every comparison is made within each timepoint and
  block.
- **Models write CSVs; figures only read them.**
- **No method is chosen by looking at your data's p-values.**

## Try it

In the container (recommended; R 4.6.1, every version pinned):

```bash
docker build -t seqcompendium .
```

```bash
docker run --rm -v "$PWD/demo":/work seqcompendium Rscript /opt/seqcompendium/inst/scripts/check_toy_end_to_end.R /work
```

The report is then `demo/compendium/report/compendium_report.html`. The toy data are
invented by `make_toy_bundle()`; they are not from any study.

From R:

```r
library(seqcompendium)
make_toy_bundle("toy")            # an invented bundle
run_compendium("toy", "compendium")
```

## The bundle

```
bundle/
  manifest.yaml               what each file is (written by the pipeline)
  metadata/
    study_metadata.tsv        one row per sample; first column `sample`
    column_guide.csv          your guide (seq-triage's format)
  layers/
    <layer>.tsv               long format: sample, feature, value; zeros written out
    <layer>_features.tsv      feature annotation
    <layer>_denominators.tsv  optional: per-sample denominators, never pre-divided
```

Column guide roles: `sample_id`, `subject_id`, `predictor`, `outcome`, `time`, `block`,
`batch`, `ignore`, `sample_control`. Types: `binary`, `categorical`, `ordinal`, `count`,
`continuous`, `proportion`, `date`, `text`. A `sample_control` column uses only `none`
(a study sample), `negative_extraction`, `negative_pcr`, `negative_other`,
`positive_mock`, `positive_other`, and lists the ones it uses in `levels`.

## Development

The design, every decision and every pass mark are in [CLAUDE.md](CLAUDE.md); pass marks
are written there before the code they judge. Licence: MIT.
