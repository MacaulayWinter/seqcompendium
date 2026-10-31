# scenarios.R: every scenario of v0.1.0, numbered once
# (validation/PREREGISTRATION.md §4: in the order of the marks' table, then
# template, design, group size; run k of scenario s uses seed
# 20261029 + 1000 s + k). CLAUDE.md D34 records the choices made here.

TEMPLATES <- c("shotgun1", "shotgun2", "shotgun3", "16S1", "16S2")

scenarios <- function() {
  s <- list()
  add <- function(mark, template, design, n, runs, ...) s[[length(s) + 1]] <<- c(list(mark = mark, template = template, design = design, n = n, runs = runs), list(...))
  # V-E1 (S1 rows): 3 design classes x blocks none/one; first shotgun template.
  for (d in c("two_group", "blocks", "paired", "paired_blocks", "longitudinal", "longitudinal_blocks")) add("V-E1", "shotgun1", d, 10, 1)
  # V-E2b contaminants: 100 bundles, 20 per template.
  for (t in TEMPLATES) add("V-E2b", t, "two_group", 10, 20, contaminants_in_study = TRUE)
  # V-E3 null calibration.
  for (t in TEMPLATES) for (d in c("two_group", "three_group", "longitudinal", "blocks")) for (n in c(5, 10, 20)) add("V-E3", t, d, n, 200)
  # V-E4 recovery: 10% planted at fold change 2.
  for (t in TEMPLATES) add("V-E4", t, "two_group", 10, 200, fc = 2, plant_share = 0.10)
  # V-E5 override: 100 runs through the engine; the default's FDR on 200 more.
  for (t in TEMPLATES) for (case in c("well_behaved", "compositional", "zero_inflated")) add("V-E5", t, "two_group", 10, 100, case = case, fdr_runs = 200)
  sc <- do.call(rbind, lapply(seq_along(s), function(i) { x <- s[[i]]
    data.frame(scenario = i, mark = x$mark, template = x$template, design = x$design, n = x$n, runs = x$runs,
               fc = x$fc %||% 1, plant_share = x$plant_share %||% 0, case = x$case %||% "", contaminants_in_study = isTRUE(x$contaminants_in_study),
               fdr_runs = x$fdr_runs %||% 0, stringsAsFactors = FALSE) }))
  sc$label <- with(sc, sprintf("s%03d %s %s %s n=%d%s", scenario, mark, template, design, n, ifelse(nzchar(case), paste0(" ", case), "")))
  sc
}

`%||%` <- function(a, b) if (is.null(a)) b else a
