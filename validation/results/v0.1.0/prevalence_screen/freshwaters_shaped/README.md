# The prevalence screen on a real table: a Freshwaters-shaped bundle (screen only)

Run 2026-11-25 with merged main 19acb72 (rules 2026-11-24.1), Mac container, 8 GB, 1 core, 60 s, sampled container memory up to 5.9 GiB. **Screen only: no Q-question was run, nothing was scored, no mark or recorded result changed.** The data and the full screen outputs (with sample and feature names) stay outside the repository; the files here hold counts only. The script is `screen_real.R`.

## How the bundle was made, and what is artificial in it
- Nearing 2022's ArcticFreshwaters table. Features: present in at least 10% of the **936 analysed samples** (the harness's default; the optional all-samples filter D66 is **off**): 1,069 features.
- **Every sample of the table is in the bundle as a study sample.** The 936 keep their Location level (Lake, Watershed); **every other sample is labelled `unused`, an artificial level made up for this demonstration**, so that the screen can see samples that are in the table but in no real comparison. The second comparison it creates, "unused vs Lake", is an artefact of that and means nothing about the data.
- 2,440 samples have data over those features (28 have none and are left out of the layer, as the engine does).

## What the screen saw (`screen_counts.csv`, `screen_decisions.csv`)
**Watershed vs Lake** (934 analysed samples, 38% of the study samples):

| cut | engine's rule (G) | pooled analysed (P) | pooled all study samples (S) | ratio P/S | flagged |
|---|---|---|---|---|---|
| 5% | 1069 | 1069 | 816 | 1.31 | no |
| 10% | 1069 | 1069 | 317 | 3.37 | **yes** |
| 20% | 744 | 386 | 69 | 5.59 | yes |

- `screen = "report"`: nothing left out; it proposes counting the 10% cut over all study samples (317 features instead of 1,069).
- `screen = "default"`: the narrow default-apply fires and would leave **752** of 1,069 features out of this comparison's Q4 tests (`left_out_summary.csv`: they are present in 10 to 26% of the analysed samples and 4 to 10% of all study samples).
- "unused vs Lake" (81% of study samples analysed, ratio 1.49 at 10%): not flagged, nothing applied; it only names a 20% cut as an option.

## Why 317 and not the paper-style 346, said plainly
The paper's filtered table has about 344 features; the 10% counted over all 2,468 samples of the table gives 346. The screen reports 317, for two reasons checked on the table (host count, counts only): **33 of those 346 features are not in the bundle at all**, because the harness's analysed-samples filter removed them before the engine saw the table; and the screen counts its share over the 2,440 samples with data (not 2,468), which makes 317 of the bundle's features pass (313 of them are among the 346). **The screen can only take features away from what is in the bundle; it can never add back what an upstream filter removed.** So the Freshwaters comparison with the paper stays the harness filter's job (D66); what the screen does here is show the user that the sample set changes the tested family by a factor of more than three.

## Limits
One data set, an artificial level, one run. The near-empty samples reported (520, 21% under 50 reads) are mostly the non-analysed low-depth samples put into this bundle. Whether leaving the 752 features out would change any result of a real analysis was not looked at.
