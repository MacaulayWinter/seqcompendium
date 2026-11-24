# utils.R: small helpers shared by every step.

`%||%` <- function(a, b) if (length(a) && !is.na(a[1])) a[1] else b
q <- function(x) paste(sprintf("`%s`", x), collapse = ", ")

ENGINE_VERSION <- function() as.character(utils::packageVersion("seqcompendium"))

# Cells that mean "no value" (the same list as seq-triage's study_metadata.R).
EMPTY <- c("", "na", "n/a", "nan", "null", "none", "missing", ".", "-", "--")
NUM <- "^[-+]?([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][-+]?[0-9]+)?$"
is_num <- function(v) grepl(NUM, v)

# Reads a TSV or CSV as text, exactly as seq-triage does: every cell a string,
# CRLF removed, the empty-cell words made NA. `keep_none` keeps the word
# "none", which is a real value in a sample_control column (F8).
read_table <- function(f, keep_none = FALSE) {
  first <- readLines(f, n = 1, warn = FALSE)
  if (!length(first) || !nzchar(trimws(first)))
    stop_engine(sprintf("%s is empty: it needs a first row of column names.", basename(f)))
  sep <- if (grepl("\\.(tsv|txt)$", tolower(f))) "\t" else ","
  x <- utils::read.table(f, sep = sep, header = TRUE, colClasses = "character", na.strings = character(0), quote = "\"",
                         comment.char = "", check.names = FALSE, strip.white = TRUE, fill = TRUE, fileEncoding = "UTF-8-BOM")
  names(x) <- trimws(gsub("\r", "", names(x)))
  empty <- if (keep_none) setdiff(EMPTY, "none") else EMPTY
  x[] <- lapply(x, function(v) { v <- trimws(gsub("\r", "", v)); ifelse(tolower(v) %in% empty, NA_character_, v) })
  x
}

# The engine stops with a classed condition, so tests can tell an engine stop
# (a problem the user must fix) from a bug.
stop_engine <- function(msg) {
  stop(structure(class = c("seqcompendium_stop", "error", "condition"),
                 list(message = msg, call = NULL)))
}

# CSVs are written one way everywhere, so two runs give identical bytes.
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "NA", fileEncoding = "UTF-8")
  invisible(path)
}

.rules_cache <- new.env(parent = emptyenv())
rules <- function() {
  # Read once per session: the profile of one run spent ~3% of its time re-reading this file.
  if (is.null(.rules_cache$r)) .rules_cache$r <- yaml::read_yaml(system.file("rules", "rules.yaml", package = "seqcompendium"))
  .rules_cache$r
}
rule <- function(id) rules()$rules[[id]]$value

split_levels <- function(x) if (is.na(x %||% NA)) character(0) else trimws(strsplit(x, "|", fixed = TRUE)[[1]])

# ---- Step timings (CLAUDE.md D69) -------------------------------------------
# Each stage of a run writes one line (step, seconds, peak memory, finish time) to
# provenance/step_timings.tsv the moment it ends, so a run that is stopped or killed still shows how far it got.
# It is a .tsv, not a .csv, so that the CSV files compared between runs (V-E10b) are untouched. With
# SEQCOMPENDIUM_TIMING_LOG=1 (or options(seqcompendium.timing_log = TRUE)) the same line is also printed, for a cluster log.
# Timing never draws a random number and never changes a result.
.timing <- new.env(parent = emptyenv())
timing_start <- function(out) {
  p <- file.path(out, "provenance"); dir.create(p, recursive = TRUE, showWarnings = FALSE)
  .timing$path <- file.path(p, "step_timings.tsv")
  writeLines("step\tseconds\tpeak_memory_mb\tfinished_at", .timing$path)
  invisible(.timing$path)
}
# Peak resident memory of this process in MB where the system says so (Linux), else NA.
peak_memory_mb <- function() {
  f <- "/proc/self/status"; if (!file.exists(f)) return(NA_real_)
  v <- grep("^VmHWM:", readLines(f, warn = FALSE), value = TRUE)
  if (length(v)) round(as.numeric(gsub("[^0-9]", "", v[1])) / 1024) else NA_real_
}
timing_note <- function(step, seconds) {
  mb <- peak_memory_mb(); when <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  if (!is.null(.timing$path)) cat(sprintf("%s\t%.1f\t%s\t%s\n", gsub("[\t\n]", " ", step), seconds, if (is.na(mb)) "NA" else format(mb), when), file = .timing$path, append = TRUE)
  if (isTRUE(getOption("seqcompendium.timing_log", Sys.getenv("SEQCOMPENDIUM_TIMING_LOG") == "1")))
    cat(sprintf("[seqcompendium step] %s: %.0f s, peak memory %s MB, finished %s\n", step, seconds, if (is.na(mb)) "NA" else format(mb), when))
  invisible(NULL)
}
# timed("name", expr): evaluates expr and returns its value; the line is written even if expr stops with an error.
timed <- function(step, expr) {
  t0 <- proc.time()[["elapsed"]]
  on.exit(timing_note(step, proc.time()[["elapsed"]] - t0), add = TRUE)
  expr
}
