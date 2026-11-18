# V-E7(c) engine-side tables (frozen before any reference file was opened)

Quick counts (no override check) of the engine's Q4 methods on each reference's feature table, from `validation/ve7c_quick.R` at commit 06aba15
(engine unchanged from main at the merge of PR 10), in one container (8 GB for Wallen, 4 GB for Zhou, 1 core). Only feature tables and group labels were read.
**No reference count or result file was on disk when these were made.** `SHA256SUMS` in each folder is the freeze: the scorer runs only after this commit.

`zhou/` (frozen 2026-11-18): CDI, IBD, RA, SMOKE from Zhou 2022's deposited inputs. Engine counts at BH q < 0.05 (D09 LinDA, D06 ANCOM-BC2, D04 ALDEx2, D17 Wilcoxon on CLR, D19 LEfSe):
CDI 3 / 69 / 1 / 16 / 29; IBD 33 / 96 / 1 / 208 / 116; RA 24 / 275 / 1 / 2 / 76; SMOKE 37 / 94 / 2 / 40 / 56 (order D09 / D06 / D04 / D17 / D19).
Zhou 2022 is a method-author reference (LinDA's authors): LinDA is on its own line (section 9.4). Effect = second group level versus first (`*_meta.csv`).
