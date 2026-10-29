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

rules <- function() {
  r <- yaml::read_yaml(system.file("rules", "rules.yaml", package = "seqcompendium"))
  r
}
rule <- function(id) rules()$rules[[id]]$value

split_levels <- function(x) if (is.na(x %||% NA)) character(0) else trimws(strsplit(x, "|", fixed = TRUE)[[1]])
