# V-E7(c) scoring map: written and pushed BEFORE any reference count or result value was opened (2026-11-18)

State when written: the engine's tables are frozen (`zhou/`, `wallen/`). The reference files were downloaded (names, sizes and SHA-256 recorded in the work folder, outside the repository) and **only their file lists, the Zhou matrices' dimensions and column names, and Zhou's R scripts were looked at**; no count, p-value, q-value or effect from any reference was read.
This file fixes the choices that the scorer must not make after seeing numbers. Nothing here changes a mark, a tolerance or section 9.

## What a reference "count" is
The number of features with BH-adjusted p < 0.05 (q < 0.05, as the engine's counts are) over the reference's own deposited per-feature p-values for that method, NA excluded. If a file carries its own adjusted-p column computed by BH, that column is used and checked to equal BH of the p column. The paper's text and figures are not used when a deposited file gives the value (9.6); no figure is read.

## Wallen 2021 (author-free reference; 10% variant, 9.4 (d))
Engine data sets 1 and 2 = `Dataset1_Output` and `Dataset2_Output` of the deposit.
| Engine method | Reference file (10% variant) | Note |
|---|---|---|
| D04 ALDEx2 | `ALDEx2_10%.txt` | |
| D06 ANCOM-BC2 | `ANCOM-BC_10%.txt` | the paper ran ANCOM-BC 1.0.5; a difference explained only by the version is **reported, not passed** (9.4 (a)) |
| D17 Wilcoxon on CLR | `KW_CLR_10%.txt` | Kruskal-Wallis on CLR; with two groups it is the same test as Wilcoxon rank-sum (the continuity correction can move a p-value slightly) |
| D19 LEfSe | `LEfSe_10%.txt` | the number of features LEfSe lists |
| D09 LinDA | none | not run by the paper: no line (the paper's methods are the reference's, 9.5) |
The supplementary tables (`MOESM3`-`MOESM6`, "Additional files 3-6") are opened only to cross-check counts (G3, self-consistency); they are not used in place of the files above.

## Zhou 2022 (LinDA's authors; LinDA on its own line, 9.4)
`realdata/code_result/pval.mat.list.rds`: four matrices of per-feature p-values, columns LinDA, ANCOM-BC, ALDEx2, DESeq2, EdgeR, MetagenomeSeq, MetagenomeSeq-2, Wilcoxon, Maaslin2.
- **Which matrix is which data set** is decided by the row names (feature identifiers) against the engine's frozen feature tables, never by position.
| Engine method | Zhou column |
|---|---|
| D09 LinDA | LinDA (its own line; reproduces the authors' code) |
| D06 ANCOM-BC2 | ANCOM-BC |
| D04 ALDEx2 | ALDEx2 |
| D17 Wilcoxon on CLR | Wilcoxon |
| D19 LEfSe | none: no line |
- Zhou's pipeline keeps features present in at least 10% of **all** samples and libraries of at least 1,000 reads (`preprocess.fun`), and for SMOKE uses a design with the covariate Sex and a subject random effect (LinDA-LMM; Left and Right sites separately); the engine's quick counts use the engine's rule (10% of one group) and a plain two-group contrast. These are known differences, written here before any number is seen. They are **not** grounds for doubt (9.2): only G4 can accept one, by reproducing the paper's step and re-running with the repeat kept.
- Feature-level effect sizes are not in `pval.mat.list.rds`: rule 3 (Spearman) is "not applicable" for Zhou unless another deposited file carries effects. Rule 2 (sign) likewise needs effects and is not applicable without them; the report says so (9.5).
