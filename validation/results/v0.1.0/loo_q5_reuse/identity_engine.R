# One toy bundle through the whole engine; prints the Q5 leads and their leave-one-out verdicts and the stage's seconds.
args <- commandArgs(TRUE); variant <- args[1]; out <- args[2]
options(seqcompendium.simrep = 2L, seqcompendium.chancerep = 3L)
suppressPackageStartupMessages(library(seqcompendium))
b <- tempfile("bundle"); seqcompendium:::make_toy_bundle(b, variant)
suppressMessages(suppressWarnings(run_compendium(b, out)))
f <- file.path(out, "03_results/Q5_presence/results.csv")
q <- if (file.exists(f)) utils::read.csv(f) else NULL
l <- if (is.null(q)) NULL else q[q$status == "lead", ]
t <- utils::read.delim(file.path(out, "provenance/step_timings.tsv"))
cat(sprintf("RUN %s: %d csv files; Q5 leads %d (yes %d, no %d, not run %d); leave-one-out Q5 %.2f s\n", variant,
  length(list.files(out, "\\.csv$", recursive = TRUE)), NROW(l), sum(l$loo_stable == "yes"), sum(grepl("^no:", l$loo_stable)),
  sum(grepl("^not run", l$loo_stable)), sum(t$seconds[t$step == "leave-one-out Q5"])))
