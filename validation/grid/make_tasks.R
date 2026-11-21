#!/usr/bin/env Rscript
# make_tasks.R: one line per array task (scenario, first run, last run) for
# grid.sbatch, and the V-E6 tasks for ve6.sbatch (CLAUDE.md D33 E7-M6).
#   Rscript validation/grid/make_tasks.R <out dir> [runs per task, default 2] [fresh]   (fresh: tasks_fresh.tsv only)
# A task's runs are a contiguous block of one scenario. V-E5 scenarios also
# get the 200 extra runs (k = 101-300) that measure the default's FDR.
args <- commandArgs(trailingOnly = TRUE); od <- args[1]; per <- if (length(args) > 1) as.integer(args[2]) else 2L
here <- dirname(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))))
source(file.path(here, "R", "scenarios.R"))
source(file.path(here, "R", "tasks.R"))
fresh <- identical(args[3], "fresh")   # the 39 fresh-template scenarios of V-E7(c); written to tasks_fresh.tsv, no V-E6 tasks
t <- make_task_table(scenarios(), per, fresh)
dir.create(od, showWarnings = FALSE, recursive = TRUE)
if (fresh) {
  utils::write.table(t, file.path(od, "tasks_fresh.tsv"), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
  cat(nrow(t), "fresh tasks ->", file.path(od, "tasks_fresh.tsv"), "\n"); quit(save = "no")
}
utils::write.table(t, file.path(od, "tasks.tsv"), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
v6 <- expand.grid(family = c("nb", "lm_hill", "permanova", "logistic"), first = c(1, 51), stringsAsFactors = FALSE); v6$last <- v6$first + 49
utils::write.table(v6, file.path(od, "tasks_ve6.tsv"), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
cat(nrow(t), "grid tasks +", nrow(v6), "V-E6 tasks =", nrow(t) + nrow(v6), "tasks ->", od, "\n")
