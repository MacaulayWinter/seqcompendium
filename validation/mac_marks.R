#!/usr/bin/env Rscript
# mac_marks.R: the Mac marks of v0.1.0 that run on the V-E1 bundles
# (validation/PREREGISTRATION.md §5 and §7; CLAUDE.md D33): V-E1, V-E8 on the
# V-E1 runs, the first four parts of V-E2b, and V-E10.
#
#   Rscript validation/mac_marks.R <phase> <templates dir> <results dir>
#
# Phases, run in this order (each can be run again on its own):
#   ve1    the 6 V-E1 bundles (scenarios 1-6, run 1, the seeds of run.R),
#          kept in <results dir>/bundles/, each run once into out_a/. Writes
#          rows/s00N_001-001.csv in run.R's format, so collect.R scores V-E1,
#          V-E8 and the V-E2b control checks from them.
#   ctl    each V-E1 bundle with one control's sample_control value changed to
#          an unknown value and to a one-keystroke typo: the run must stop and
#          name the value. Writes ctl.csv.
#   noctl  each V-E1 bundle simulated again with the same seed and no controls:
#          the report must carry the no-controls warning. Writes noctl.csv.
#   ve10   the main toy and the first 4 V-E1 bundles run a second time (out_b/)
#          with the same engine and container: every CSV must be byte-identical
#          to the first run. Writes ve10.csv.
#   marks  the four V-E2b parts and V-E10 as rows of marks.csv: mac_marks.csv.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("usage: mac_marks.R <ve1|ctl|noctl|ve10|marks> <templates dir> <results dir>")
phase <- args[1]; tdir <- args[2]; rdir <- args[3]
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
for (f in c("scenarios.R", "simulate.R", "score.R", "engine_bits.R")) source(file.path(here, "R", f))
suppressPackageStartupMessages(library(seqcompendium))
dir.create(file.path(rdir, "rows"), recursive = TRUE, showWarnings = FALSE)
sc <- scenarios(); v1 <- sc[sc$mark == "V-E1", ]
bdir <- function(s) file.path(rdir, "bundles", sprintf("s%03d", s))
spec_of <- function(x) list(design = x$design, n = x$n, fc = x$fc, plant_share = x$plant_share, contaminants_in_study = x$contaminants_in_study)
engine <- function(b, o) tryCatch({ unlink(o, recursive = TRUE); suppressMessages(suppressWarnings(run_compendium(b, o))); NA_character_ }, error = function(e) conditionMessage(e))
stamp <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")

if (phase == "ve1") {
  for (i in seq_len(nrow(v1))) {
    x <- v1[i, ]; s <- x$scenario; seed <- run_seed(s, 1); b <- bdir(s); o <- file.path(rdir, "out_a", sprintf("s%03d", s))
    # A bundle whose row is already written is not run again, so the phase can be stopped between bundles and resumed.
    if (file.exists(file.path(rdir, "rows", sprintf("s%03d_001-001.csv", s)))) { stamp("V-E1", x$label, "already done, skipped"); next }
    fit <- readRDS(file.path(tdir, sprintf("%s.fit.rds", x$template)))
    unlink(b, recursive = TRUE); truth <- simulate_bundle(fit, spec_of(x), seed, b, scenario = x$label)
    stamp("V-E1", x$label, "started")
    t0 <- proc.time()[["elapsed"]]; err <- engine(b, o); secs <- proc.time()[["elapsed"]] - t0
    # V-E8: figures are drawn with the bundle out of reach (run.R deletes it; here it is moved and moved back).
    hidden <- paste0(b, ".away"); file.rename(b, hidden)
    row <- run_record(o, truth, x$mark, x$label, 1L, secs, err)
    file.rename(hidden, b)
    utils::write.csv(row, file.path(rdir, "rows", sprintf("s%03d_001-001.csv", s)), row.names = FALSE)
    stamp("V-E1", x$label, "done in", round(secs), "s; error:", err, "; profile_ok:", row$profile_ok %||% NA)
  }
}

if (phase == "ctl") {
  res <- list()
  for (s in v1$scenario) for (case in c("unknown", "typo")) {
    value <- if (case == "unknown") "spike_in_control" else "negative_extracton"   # typo: one letter dropped from negative_extraction
    w <- tempfile("ctl"); dir.create(w); file.copy(bdir(s), w, recursive = TRUE); b <- file.path(w, basename(bdir(s)))
    f <- file.path(b, "metadata/study_metadata.tsv"); md <- utils::read.delim(f, colClasses = "character")
    md$kind[md$sample == "BLANK2"] <- value
    utils::write.table(md, f, sep = "\t", quote = FALSE, row.names = FALSE, na = "")
    err <- engine(b, file.path(w, "out"))
    res[[length(res) + 1]] <- data.frame(scenario = s, case = case, value = value, stopped = !is.na(err), names_value = !is.na(err) && grepl(value, err, fixed = TRUE), message = substr(err %||% "", 1, 300))
    unlink(w, recursive = TRUE)
    stamp("ctl", s, case, "stopped:", !is.na(err))
  }
  utils::write.csv(do.call(rbind, res), file.path(rdir, "ctl.csv"), row.names = FALSE)
}

if (phase == "noctl") {
  res <- list()
  for (i in seq_len(nrow(v1))) {
    x <- v1[i, ]; s <- x$scenario; w <- tempfile("noctl"); b <- file.path(w, "bundle"); o <- file.path(w, "out")
    fit <- readRDS(file.path(tdir, sprintf("%s.fit.rds", x$template)))
    simulate_bundle(fit, utils::modifyList(spec_of(x), list(controls = FALSE)), run_seed(s, 1), b, scenario = x$label)
    stamp("noctl", x$label, "started")
    err <- engine(b, o)
    rep <- if (is.na(err)) readLines(file.path(o, "report", "compendium_report.md"), warn = FALSE) else character(0)
    leads <- if (is.na(err)) utils::read.csv(file.path(o, "05_leads", "leads.csv"), stringsAsFactors = FALSE) else NULL
    res[[length(res) + 1]] <- data.frame(scenario = s, error = err, warning_in_report = any(grepl("this design has no control samples", rep, fixed = TRUE)),
                                         every_lead_flagged = !is.null(leads) && all(grepl("no_controls", leads$flags, fixed = TRUE)))
    unlink(w, recursive = TRUE)
    stamp("noctl", x$label, "done; warning:", res[[length(res)]]$warning_in_report)
  }
  utils::write.csv(do.call(rbind, res), file.path(rdir, "noctl.csv"), row.names = FALSE)
}

if (phase == "ve10") {
  csvs <- function(o) sort(list.files(o, pattern = "\\.csv$", recursive = TRUE))
  same <- function(a, b) {
    fa <- csvs(a); fb <- csvs(b)
    differ <- fa[vapply(fa, function(f) !file.exists(file.path(b, f)) || !identical(unname(tools::md5sum(file.path(a, f))), unname(tools::md5sum(file.path(b, f)))), TRUE)]
    data.frame(files = length(fa), same_file_set = identical(fa, fb), files_differing = length(differ), differing = paste(utils::head(differ, 10), collapse = "; "))
  }
  res <- list()
  toy <- file.path(rdir, "toy_bundle"); unlink(toy, recursive = TRUE); make_toy_bundle(toy)
  for (r in c("a", "b")) { stamp("ve10 toy run", r); err <- engine(toy, file.path(rdir, paste0("out_", r), "toy")); if (!is.na(err)) stop("toy run ", r, ": ", err) }
  res[[1]] <- cbind(bundle = "main toy", same(file.path(rdir, "out_a", "toy"), file.path(rdir, "out_b", "toy")))
  for (s in utils::head(v1$scenario, 4)) {
    stamp("ve10 second run of", s)
    a <- file.path(rdir, "out_a", sprintf("s%03d", s)); b <- file.path(rdir, "out_b", sprintf("s%03d", s))
    err <- engine(bdir(s), b); if (!is.na(err)) stop("second run of s", s, ": ", err)
    res[[length(res) + 1]] <- cbind(bundle = v1$label[v1$scenario == s], same(a, b))
  }
  utils::write.csv(do.call(rbind, res), file.path(rdir, "ve10.csv"), row.names = FALSE)
}

# V-E10 confirmation after a fix (CLAUDE.md D53): both runs with the fixed engine,
# each in its own R process (its own container), toy first, so each run's first
# call of every method is the first in its session.
#   ve10run <label>   the main toy and bundles 1-4 into out_<label>/
#   ve10cmp <a> <b>   compares out_<a>/ with out_<b>/: ve10_<a>_<b>.csv and its mark row
if (phase == "ve10run") {
  lab <- args[4]; o <- file.path(rdir, paste0("out_", lab))
  toy <- file.path(rdir, "toy_bundle"); if (!dir.exists(toy)) make_toy_bundle(toy)
  stamp("ve10run", lab, "toy"); err <- engine(toy, file.path(o, "toy")); if (!is.na(err)) stop("toy: ", err)
  for (s in utils::head(v1$scenario, 4)) { stamp("ve10run", lab, s); err <- engine(bdir(s), file.path(o, sprintf("s%03d", s))); if (!is.na(err)) stop("s", s, ": ", err) }
  stamp("ve10run", lab, "done")
}
if (phase == "ve10cmp") {
  a <- args[4]; b <- args[5]
  csvs <- function(o) sort(list.files(o, pattern = "\\.csv$", recursive = TRUE))
  same <- function(x, y) {
    fa <- csvs(x); fb <- csvs(y)
    differ <- fa[vapply(fa, function(f) !file.exists(file.path(y, f)) || !identical(unname(tools::md5sum(file.path(x, f))), unname(tools::md5sum(file.path(y, f)))), TRUE)]
    data.frame(files = length(fa), same_file_set = identical(fa, fb), files_differing = length(differ), differing = paste(utils::head(differ, 10), collapse = "; "))
  }
  dirs <- c(toy = "toy", stats::setNames(sprintf("s%03d", utils::head(v1$scenario, 4)), utils::head(v1$label, 4)))
  res <- do.call(rbind, lapply(names(dirs), function(n) cbind(bundle = if (n == "toy") "main toy" else n, same(file.path(rdir, paste0("out_", a), dirs[[n]]), file.path(rdir, paste0("out_", b), dirs[[n]])))))
  utils::write.csv(res, file.path(rdir, sprintf("ve10_%s_%s.csv", a, b)), row.names = FALSE)
  ok <- res$same_file_set & res$files_differing == 0
  utils::write.csv(mark_row("V-E10", sprintf("main toy and the first 4 V-E1 bundles run twice (runs %s, %s; fixed engine): every CSV byte-identical", a, b), mean(ok), "= 1", all(ok), nrow(res)),
                   file.path(rdir, sprintf("ve10_%s_%s_mark.csv", a, b)), row.names = FALSE)
  print(res); stamp("V-E10 confirmation:", sum(ok), "of", nrow(res), "identical")
}

if (phase == "marks") {
  rows <- do.call(rbind, lapply(list.files(file.path(rdir, "rows"), pattern = "^s00[1-6]_", full.names = TRUE), utils::read.csv, stringsAsFactors = FALSE))
  ok <- is.na(rows$error); ctl <- utils::read.csv(file.path(rdir, "ctl.csv")); nc <- utils::read.csv(file.path(rdir, "noctl.csv")); v10 <- utils::read.csv(file.path(rdir, "ve10.csv"))
  m <- rbind(
    mark_row("V-E2b", "(1) V-E1 bundles: no control sample in any Q1-Q11 result", mean(ok & rows$controls_absent %in% TRUE), "= 1", all(ok & rows$controls_absent %in% TRUE), nrow(rows)),
    mark_row("V-E2b", "(2) a control value changed to an unknown value or a typo: the run stops naming the value", mean(ctl$names_value), "= 1", all(ctl$names_value), nrow(ctl)),
    mark_row("V-E2b", "(3) V-E1 bundles: every control in controls.csv", mean(ok & rows$controls_listed %in% TRUE), "= 1", all(ok & rows$controls_listed %in% TRUE), nrow(rows)),
    mark_row("V-E2b", "(4) V-E1 bundles without controls: the no-controls warning is written", mean(is.na(nc$error) & nc$warning_in_report), "= 1", all(is.na(nc$error) & nc$warning_in_report), nrow(nc)),
    mark_row("V-E10", "main toy and the first 4 V-E1 bundles run twice: every CSV byte-identical", mean(v10$same_file_set & v10$files_differing == 0), "= 1", all(v10$same_file_set & v10$files_differing == 0), nrow(v10)))
  utils::write.csv(m, file.path(rdir, "mac_marks.csv"), row.names = FALSE)
  print(m[, c("mark", "scenario", "number", "pass")], row.names = FALSE)
}
