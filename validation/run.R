#!/usr/bin/env Rscript
# run.R: one piece of the v0.1.0 validation grid (CLAUDE.md D33, D34).
#
#   Rscript validation/run.R <scenario> <first run> <last run> <templates dir> <results dir> [fresh]
#
# Simulates each run's bundle from its template, runs the engine on it,
# keeps one row of numbers per run (validation/R/score.R) and deletes the
# bundle and the compendium. Writes <results dir>/rows/s<scenario>_<first>-<last>.csv.
# For V-E5, run numbers above the scenario's `runs` are the separate runs
# that measure the default method's FDR with known truth.
# Scenario numbers, seeds and templates: validation/R/scenarios.R, simulate.R.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 5) stop("usage: run.R <scenario> <first run> <last run> <templates dir> <results dir> [fresh]")
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
for (f in c("scenarios.R", "simulate.R", "score.R", "engine_bits.R")) source(file.path(here, "R", f))
s <- as.integer(args[1]); first <- as.integer(args[2]); last <- as.integer(args[3])
tdir <- args[4]; rdir <- args[5]; fresh <- identical(args[6], "fresh")
suppressPackageStartupMessages(library(seqcompendium))

sc <- scenarios(); x <- sc[sc$scenario == s, ]
if (!nrow(x)) stop("no scenario ", s)
fit <- readRDS(file.path(tdir, sprintf("%s.fit.rds", if (fresh) fresh_template(x$template) else x$template)))
dir.create(file.path(rdir, "rows"), recursive = TRUE, showWarnings = FALSE)
rows <- list()
for (k in first:last) {
  seed <- run_seed(s, k, fresh)
  work <- tempfile(sprintf("s%03d_k%03d_", s, k)); b <- file.path(work, "bundle"); o <- file.path(work, "out")
  spec <- list(design = x$design, n = x$n, fc = x$fc, plant_share = x$plant_share, contaminants_in_study = x$contaminants_in_study)
  if (x$case == "compositional") { spec$plant_top <- 3; spec$fc <- 10 }
  if (x$case == "zero_inflated") spec$zero_inflate <- 0.5
  truth <- simulate_bundle(fit, spec, seed, b, scenario = x$label)
  if (x$mark == "V-E5" && k > x$runs) {
    # The default's FDR with known truth (PREREGISTRATION.md §5, V-E5).
    t0 <- proc.time()[["elapsed"]]
    r <- default_q4_calls(b, truth)
    rows[[length(rows) + 1]] <- data.frame(mark = "V-E5 fdr", scenario = x$label, k = k, seed = seed, seconds = round(proc.time()[["elapsed"]] - t0, 1),
                                           error = r$error, default_id = r$default_id, calls = r$calls, false_calls = r$false_calls, stringsAsFactors = FALSE)
  } else {
    t0 <- proc.time()[["elapsed"]]
    err <- tryCatch({ suppressMessages(suppressWarnings(run_compendium(b, o))); NA_character_ }, error = function(e) conditionMessage(e))
    secs <- proc.time()[["elapsed"]] - t0
    unlink(b, recursive = TRUE)   # V-E8: figures are drawn with the bundle gone
    rows[[length(rows) + 1]] <- run_record(o, truth, x$mark, x$label, k, secs, err)
  }
  unlink(work, recursive = TRUE)
}
all_cols <- unique(unlist(lapply(rows, names)))
rows <- do.call(rbind, lapply(rows, function(r) { r[setdiff(all_cols, names(r))] <- NA; r[all_cols] }))
f <- file.path(rdir, "rows", sprintf("s%03d_%03d-%03d%s.csv", s, first, last, if (fresh) "_fresh" else ""))
utils::write.csv(rows, f, row.names = FALSE)
cat("wrote", f, "\n")
