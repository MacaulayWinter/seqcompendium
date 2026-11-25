# Repeat the leave-one-out Q5 stage of the `spread` toy bundle on the host, old against new, from the engine's own Q5 results.
a <- commandArgs(TRUE); R <- file.path(a[1], "R")
for (f in c("utils.R", "profile.R", "adjust.R", "units.R", "loo.R", "toy.R")) source(file.path(R, f))
rl <- yaml::read_yaml(file.path(a[1], "inst", "rules", "rules.yaml")); rules <- function() rl
new <- loo_q5; e <- new.env(); sys.source(a[2], e, keep.source = FALSE); old <- e$loo_q5; environment(old) <- globalenv()
b <- tempfile("bundle"); make_toy_bundle(b, "spread")
md <- utils::read.delim(file.path(b, "metadata", "study_metadata.tsv"), colClasses = "character")
layer <- list(spec = list(unit = "count"), data = utils::read.delim(file.path(b, "layers", "toy_counts.tsv")))
res <- utils::read.csv(file.path(a[3], "03_results", "Q5_presence", "results.csv"))
print(unique(res[, c("layer", "predictor", "contrast", "timepoint", "block", "adjusted_for")]))
units <- lapply(unique(res$timepoint), function(tp) { x <- res[res$timepoint == tp, ][1, ]; d <- md[md$day == tp & md$kind == "none", ]
  list(layer = x$layer, predictor = x$predictor, contrast = x$contrast, timepoint = tp, block = x$block, reference = "control", level = "treated",
       ref_samples = d$sample[d$group == "control"], level_samples = d$sample[d$group == "treated"], testable = TRUE) })
layers <- stats::setNames(list(layer), res$layer[1]); r <- res; r$loo_stable <- NULL
for (i in 1:5) { to <- system.time(o <- suppressWarnings(old(r, units, layers, NULL)))[[3]]; tn <- system.time(n <- suppressWarnings(new(r, units, layers, NULL)))[[3]]
  cat(sprintf("repeat %d: leads %d, main %.2f s, branch %.2f s, identical %s, same verdicts as the engine run %s\n", i, sum(r$status == "lead"), to, tn, identical(o, n), identical(n$loo_stable, res$loo_stable))) }
