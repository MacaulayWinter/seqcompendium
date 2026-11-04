#!/usr/bin/env Rscript
# make_tasks.R: one line per array task (scenario, first run, last run) for
# grid.sbatch, and the V-E6 tasks for ve6.sbatch (CLAUDE.md D33 E7-M6).
#   Rscript validation/isca/make_tasks.R <out dir> [runs per task, default 2] [fresh]
# A task's runs are a contiguous block of one scenario. V-E5 scenarios also
# get the 200 extra runs (k = 101-300) that measure the default's FDR.
args <- commandArgs(trailingOnly = TRUE); od <- args[1]; per <- if (length(args) > 1) as.integer(args[2]) else 2L
here <- dirname(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))))
source(file.path(here, "R", "scenarios.R"))
sc <- scenarios(); sc <- sc[sc$mark != "V-E1", ]   # V-E1 runs on the Mac (PREREGISTRATION.md §7)
t <- do.call(rbind, lapply(seq_len(nrow(sc)), function(i) {
  n <- sc$runs[i] + sc$fdr_runs[i]; a <- seq(1, n, by = per)
  # The FDR runs are quick: one block per 50.
  if (sc$fdr_runs[i] > 0) a <- c(seq(1, sc$runs[i], by = per), seq(sc$runs[i] + 1, n, by = 50))
  b <- c(a[-1] - 1, n)
  data.frame(scenario = sc$scenario[i], first = a, last = b)
}))
dir.create(od, showWarnings = FALSE, recursive = TRUE)
utils::write.table(t, file.path(od, "tasks.tsv"), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
v6 <- expand.grid(family = c("nb", "lm_hill", "permanova", "logistic"), first = c(1, 51), stringsAsFactors = FALSE); v6$last <- v6$first + 49
utils::write.table(v6, file.path(od, "tasks_ve6.tsv"), sep = "\t", row.names = FALSE, col.names = FALSE, quote = FALSE)
cat(nrow(t), "grid tasks,", nrow(v6), "V-E6 tasks ->", od, "\n")
