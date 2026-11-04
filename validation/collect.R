#!/usr/bin/env Rscript
# collect.R: every row of the grid into validation/results/<release>/marks.csv
# (validation/PREREGISTRATION.md §7; CLAUDE.md D33 E7-M8).
#
#   Rscript validation/collect.R <results dir> <out marks.csv> [mac results dir ...]
#
# Reads <results dir>/rows/*.csv (from run.R and ve6_diagnostics.R) and any
# marks tables written on the Mac (ve2_marks.csv, ve7a_marks.csv, ...), scores
# each mark, and writes one table: mark, scenario, number, threshold, pass, runs.
args <- commandArgs(trailingOnly = TRUE); rdir <- args[1]; out <- args[2]; extra <- args[-(1:2)]
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
for (f in c("scenarios.R", "simulate.R", "score.R", "engine_bits.R")) source(file.path(here, "R", f))
fs <- list.files(file.path(rdir, "rows"), pattern = "\\.csv$", full.names = TRUE)
read <- function(p) { x <- lapply(fs[grepl(p, basename(fs))], utils::read.csv, stringsAsFactors = FALSE); if (!length(x)) return(NULL)
  cols <- unique(unlist(lapply(x, names))); do.call(rbind, lapply(x, function(r) { r[setdiff(cols, names(r))] <- NA; r[cols] })) }
runs <- read("^s[0-9]"); v6 <- read("^ve6_")
m <- list()
if (!is.null(runs)) {
  fresh <- grepl("_fresh", basename(fs[grepl("^s[0-9]", basename(fs))]))
  by <- function(k) runs[runs$mark == k, , drop = FALSE]
  if (nrow(by("V-E1"))) { r <- by("V-E1"); m$v1 <- mark_row("V-E1", "S1: 6 designs, profile equals the generator's truth", mean(r$profile_ok %in% TRUE), "= 1", all(r$profile_ok %in% TRUE), nrow(r)) }
  if (nrow(by("V-E2b"))) {
    r <- by("V-E2b"); m$v2b <- score_ve2b_contaminants(r)
    m$v2b_ctl <- rbind(mark_row("V-E2b", "no control sample in any Q1-Q11 result", mean(r$controls_absent %in% TRUE), "= 1", all(r$controls_absent %in% TRUE), nrow(r)),
                       mark_row("V-E2b", "every control in controls.csv", mean(r$controls_listed %in% TRUE), "= 1", all(r$controls_listed %in% TRUE), nrow(r)))
  }
  if (nrow(by("V-E3"))) m$v3 <- score_ve3(by("V-E3"))
  if (nrow(by("V-E4"))) m$v4 <- score_ve4(by("V-E4"))
  if (nrow(by("V-E5"))) m$v5 <- score_ve5(by("V-E5"), fdr_table(runs))
  h <- runs[runs$mark %in% c("V-E1", "V-E3") & is.na(runs$error), , drop = FALSE]
  if (nrow(h)) m$v8 <- score_ve8(h)
}
if (!is.null(v6)) m$v6 <- score_ve6(v6[is.finite(v6$flagged), ])
for (f in extra) m[[f]] <- utils::read.csv(f, stringsAsFactors = FALSE)
res <- do.call(rbind, lapply(m, function(x) x[, c("mark", "scenario", "number", "threshold", "pass", "runs")]))
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("%d rows, %d pass, %d fail -> %s\n", nrow(res), sum(res$pass %in% TRUE), sum(res$pass %in% FALSE), out))
