# guide.R: the column guide (seq-triage D95, plus F8's sample_control role).
#
# THE RULE  Nothing about a column is guessed. Role and type come only from the
#           guide; the data are used to CHECK the guide, never to fill it in.
#           Anything that looks like a typo stops the run, naming it.
# WHERE IT CAME FROM  The per-column checks are a port of seq-triage
#           bin/study_metadata.R (commit fbf74dd, 2026-10-28), with the same
#           messages, so a user sees the same stop from either tool (design C4:
#           a copy now, with a shared test set). The samplesheet and --metadata
#           joining parts are not ported: the engine receives one table, already
#           joined, keyed by `sample`.

ROLES <- c("sample_id", "subject_id", "predictor", "outcome", "time", "block", "batch", "ignore", "sample_control")
TYPES <- c("binary", "categorical", "ordinal", "count", "continuous", "proportion", "date", "text")
GUIDE_COLS <- c("column", "role", "type", "levels", "missing_codes", "unit", "nested_in", "derived_from", "description", "seen_in_data")
CONVENTIONAL_CODES <- c("99", "999", "9999", "-9", "-99", "-999", "-9999")
# F8: the closed list of sample_control values (user approved 2026-10-28).
CONTROL_VALUES <- c("none", "negative_extraction", "negative_pcr", "negative_other", "positive_mock", "positive_other")

# What the data show for certain, per column (facts, not choices).
seen <- function(v) {
  v <- stats::na.omit(v); u <- unique(v)
  if (!length(v)) return("no values")
  if (all(is_num(v))) {
    x <- as.numeric(v); whole <- all(x == round(x))
    return(if (length(u) < length(v)) sprintf("%s: %s", if (whole) "whole numbers" else "numbers", paste(format(sort(unique(x)), trim = TRUE), collapse = "|"))
           else sprintf("%s, %s to %s, all different", if (whole) "whole numbers" else "numbers", format(min(x)), format(max(x))))
  }
  if (all(!is.na(as.Date(v, optional = TRUE, tryFormats = c("%Y-%m-%d"))))) return(sprintf("dates, %s to %s", min(v), max(v)))
  if (length(u) == length(v)) return(sprintf("a different value for every sample (%d)", length(u)))
  sprintf("%d values: %s", length(u), paste(sort(u), collapse = "|"))
}

# Values that look like misspellings of each other.
typo_pairs <- function(v) {
  u <- unique(stats::na.omit(v)); u <- u[!is_num(u)]
  if (length(u) < 2) return(character(0))
  out <- character(0)
  key <- tolower(gsub("[[:space:][:punct:]]", "", u))
  for (k in unique(key[duplicated(key)])) out <- c(out, sprintf("%s (differ only in case, spaces or punctuation)", paste(sprintf("'%s'", u[key == k]), collapse = " / ")))
  # One keystroke apart, where neither value is a single character and the
  # values do not differ only in their digits (A1 / A2 are a series, not a typo).
  # The option is a test hook only (CLAUDE.md D5, mark E1-M13).
  if (!isTRUE(getOption("seqcompendium.disable_one_keystroke"))) {
    d <- utils::adist(u)
    for (i in seq_along(u)) for (j in seq_along(u)) if (i < j && d[i, j] == 1 && nchar(u[i]) > 1 && nchar(u[j]) > 1 &&
        gsub("[0-9]", "", u[i]) != gsub("[0-9]", "", u[j]) && key[i] != key[j])
      out <- c(out, sprintf("'%s' / '%s' (one keystroke apart)", u[i], u[j]))
  }
  out
}

# The closest closed-list value to an unknown sample_control value, if it
# looks like a typo of one (same letters ignoring case and punctuation, or at
# most two keystrokes away).
near_control <- function(x) {
  k <- function(s) tolower(gsub("[[:space:][:punct:]]", "", s))
  hit <- CONTROL_VALUES[k(CONTROL_VALUES) == k(x)]
  if (length(hit)) return(hit[1])
  d <- utils::adist(tolower(x), CONTROL_VALUES)[1, ]
  if (min(d) <= 2) CONTROL_VALUES[which.min(d)] else NA_character_
}

read_guide <- function(f) {
  # `none` kept: it is a real entry in missing_codes ("confirms real values").
  # (seq-triage reads it as empty, so its `none` never takes effect: CLAUDE.md D6.)
  guide <- read_table(f, keep_none = TRUE)
  names(guide) <- tolower(names(guide))
  miss <- setdiff(c("column", "role", "type"), names(guide))
  if (length(miss)) stop_engine(sprintf("The column guide %s needs the columns column, role and type; missing: %s.", basename(f), q(miss)))
  odd <- setdiff(names(guide), GUIDE_COLS)
  if (length(odd)) stop_engine(sprintf("The column guide %s has column(s) the guide does not have: %s (allowed: %s). Nothing has been assumed: check the spelling.", basename(f), q(odd), q(GUIDE_COLS)))
  for (c in setdiff(GUIDE_COLS, names(guide))) guide[[c]] <- NA_character_
  guide$role <- tolower(guide$role); guide$type <- tolower(guide$type)
  guide <- guide[!is.na(guide$column), , drop = FALSE]
  dup <- unique(guide$column[duplicated(guide$column)])
  if (length(dup)) stop_engine(sprintf("The column guide lists column(s) more than once: %s. Give each column one row.", q(dup)))
  guide
}

# Checks the metadata against the guide. `md` is the metadata table (text,
# `sample` first). Returns the metadata with declared missing codes made NA,
# the per-column facts, the findings (notes, warnings) and the stops; the
# caller writes them out before stopping.
check_guide <- function(md, guide) {
  stops <- character(0); stop_if <- function(cond, msg) if (isTRUE(cond)) stops <<- c(stops, msg)
  findings <- list(); add <- function(column, status, message) findings[[length(findings) + 1]] <<- data.frame(column = column, status = status, message = message)
  g <- function(c, field) if (is.null(guide)) NA_character_ else guide[[field]][match(c, guide$column)]
  analysed <- setdiff(names(md), "sample")

  # The word "none" is kept when reading (it is a sample_control value, F8);
  # in every other column it means "no value", as in seq-triage.
  for (c in analysed) if (!g(c, "role") %in% "sample_control") md[[c]][tolower(md[[c]]) %in% "none"] <- NA_character_

  code_n <- list()
  if (!is.null(guide)) for (c in intersect(guide$column, analysed)) {
    mc <- g(c, "missing_codes"); if (is.na(mc) || tolower(mc) == "none") next
    codes <- trimws(strsplit(mc, "|", fixed = TRUE)[[1]])
    hit <- md[[c]] %in% codes; code_n[[c]] <- sum(hit); md[[c]][hit] <- NA_character_
  }
  info <- data.frame(column = analysed, stringsAsFactors = FALSE)
  info$seen <- vapply(analysed, function(c) seen(md[[c]]), "")
  # Missing values are counted over study samples only: control samples (F8)
  # have no design values by construction, so they are not "missing".
  ctl <- guide$column[guide$role %in% "sample_control"][1]
  study_rows <- if (!is.na(ctl) && ctl %in% names(md)) !md[[ctl]] %in% setdiff(CONTROL_VALUES, "none") else rep(TRUE, nrow(md))
  info$n_missing <- vapply(analysed, function(c) sum(is.na(md[[c]][if (identical(c, ctl)) TRUE else study_rows])), 0L)
  info$n_values <- vapply(analysed, function(c) length(unique(stats::na.omit(md[[c]]))), 0L)
  info$role <- vapply(analysed, function(c) g(c, "role"), ""); info$type <- vapply(analysed, function(c) g(c, "type"), "")

  dup <- unique(md$sample[duplicated(md$sample)])
  stop_if(length(dup) > 0, sprintf("The metadata has more than one row for sample(s) %s: one row per sample.", q(dup)))

  for (c in analysed) {
    v <- stats::na.omit(md[[c]]); r <- g(c, "role"); t <- g(c, "type")
    lv <- split_levels(g(c, "levels"))
    if (g(c, "role") %in% "ignore") { }
    else if (!length(v)) add(c, "note", "No values for any sample in this run.")
    else if (length(unique(v)) == 1) add(c, "note", sprintf("The same value ('%s') for every sample: it cannot explain differences in this run.", v[1]))
    if (!g(c, "role") %in% "ignore" && info$n_missing[match(c, info$column)] > 0 && length(v)) add(c, "note", sprintf("Missing for %d of %d %s.", info$n_missing[match(c, info$column)], sum(study_rows), if (all(study_rows)) "sample(s)" else "study sample(s) (control samples are not counted)"))
    if (!is.null(code_n[[c]]) && code_n[[c]] > 0) add(c, "note", sprintf("%d value(s) were missing-value codes (%s) and are treated as missing.", code_n[[c]], g(c, "missing_codes")))
    codes_here <- intersect(unique(v), CONVENTIONAL_CODES)
    if (!c %in% guide$column) { stop_if(TRUE, sprintf("`%s` is not in the column guide: give it a role and type (role ignore keeps it without analysing it).", c)); next }
    stop_if(is.na(r) || !r %in% ROLES, sprintf("`%s`: role '%s' is not one of: %s.", c, r %||% "", paste(ROLES, collapse = ", ")))
    stop_if(is.na(t) || !t %in% TYPES, sprintf("`%s`: type '%s' is not one of: %s.", c, t %||% "", paste(TYPES, collapse = ", ")))
    if (!t %in% TYPES) next

    if (r %in% "sample_control") {
      # F8: a closed list. Unknown values or suspected typos stop, value named.
      stop_if(!t %in% "categorical", sprintf("`%s`: a sample_control column must be type categorical (it is %s).", c, t))
      stop_if(!length(lv), sprintf("`%s`: a sample_control column must list in `levels` which of these values it uses: %s.", c, paste(CONTROL_VALUES, collapse = "|")))
      for (x in setdiff(lv, CONTROL_VALUES)) {
        n <- near_control(x)
        stop_if(TRUE, sprintf("`%s`: level '%s' is not a sample_control value (allowed: %s)%s.", c, x, paste(CONTROL_VALUES, collapse = ", "),
                              if (!is.na(n)) sprintf("; it looks like a typo of '%s'", n) else ""))
      }
      for (x in setdiff(unique(v), CONTROL_VALUES)) {
        n <- near_control(x)
        stop_if(TRUE, sprintf("`%s`: value '%s' is not a sample_control value (allowed: %s)%s.", c, x, paste(CONTROL_VALUES, collapse = ", "),
                              if (!is.na(n)) sprintf("; it looks like a typo of '%s'", n) else ""))
      }
      out <- setdiff(intersect(unique(v), CONTROL_VALUES), lv)
      stop_if(length(lv) && length(out) > 0, sprintf("`%s`: value(s) not among its listed levels: %s (check spelling and case).", c, paste(sprintf("'%s'", out), collapse = ", ")))
      stop_if(info$n_missing[match(c, info$column)] > 0, sprintf("`%s`: %d sample(s) have no sample_control value; write none for a study sample.", c, info$n_missing[match(c, info$column)]))
      next
    }

    if (!length(v)) next
    stop_if(length(codes_here) > 0 && t %in% c("count", "continuous", "proportion", "ordinal") && is.na(g(c, "missing_codes")),
            sprintf("`%s`: contains %s, often a code for 'not recorded'. Nothing has been assumed: list it in this column's missing_codes, or write none there if it is a real value.",
                    c, paste(sprintf("'%s'", codes_here), collapse = ", ")))
    bad <- switch(t,
      binary      = if (length(unique(v)) > 2) sprintf("declared binary, but has %d values: %s", length(unique(v)), paste(sprintf("'%s'", unique(v)), collapse = ", ")),
      count       = { x <- suppressWarnings(as.numeric(v)); if (any(!is_num(v)) || any(x < 0) || any(x != round(x))) sprintf("declared count, but '%s' is not a whole number 0 or more", v[!is_num(v) | is.na(x) | x < 0 | x != round(x)][1]) },
      continuous  = if (any(!is_num(v))) sprintf("declared continuous, but '%s' is not a number%s", v[!is_num(v)][1],
                                                 if (grepl("^[-+]?[0-9]+,[0-9]+$", v[!is_num(v)][1])) " (a decimal comma? write 12.5, not 12,5)" else " (units go in the guide's `unit`, not in the cells)"),
      proportion  = { x <- suppressWarnings(as.numeric(v)); if (any(!is_num(v)) || any(x < 0 | x > 1)) sprintf("declared proportion, but '%s' is not a number from 0 to 1", v[!is_num(v) | is.na(x) | x < 0 | x > 1][1]) },
      date        = if (any(is.na(as.Date(v, optional = TRUE, tryFormats = "%Y-%m-%d")))) sprintf("declared date, but '%s' is not written YYYY-MM-DD", v[is.na(as.Date(v, optional = TRUE, tryFormats = "%Y-%m-%d"))][1]),
      NULL)
    stop_if(!is.null(bad), sprintf("`%s`: %s.", c, bad))
    stop_if(t == "ordinal" && !length(lv), sprintf("`%s`: declared ordinal, so `levels` must list the values in order, separated by |.", c))
    if (length(lv)) {
      out <- setdiff(unique(v), lv)
      stop_if(length(out) > 0, sprintf("`%s`: value(s) not among its listed levels: %s (check spelling and case).", c, paste(sprintf("'%s'", out), collapse = ", ")))
      unused <- setdiff(lv, unique(v))
      if (length(unused)) add(c, "note", sprintf("Listed level(s) not seen in this run: %s.", paste(unused, collapse = ", ")))
    } else if (t %in% c("binary", "categorical") && !r %in% "ignore" && is.na(g(c, "derived_from"))) {
      for (p in typo_pairs(v)) stop_if(TRUE, sprintf("`%s`: %s. Fix the spelling, or confirm both are intended by listing the column's values in `levels`.", c, p))
    }
    # F8: an experimental control group is a predictor level; a control-sample
    # kind is not. The two declared roles must not overlap.
    if (r %in% "predictor") {
      kinds <- intersect(unique(v), setdiff(CONTROL_VALUES, "none"))
      stop_if(length(kinds) > 0, sprintf("`%s`: a predictor holds the control-sample kind(s) %s. Control samples are declared in a column with role sample_control, not as a predictor level.", c, paste(sprintf("'%s'", kinds), collapse = ", ")))
    }
    stop_if(r %in% "time" && !t %in% c("ordinal", "count", "continuous", "date"), sprintf("`%s`: a time column must be ordinal, count, continuous or date, so samples can be put in order (it is %s).", c, t))
    stop_if(r %in% "outcome" && t %in% "text", sprintf("`%s`: an outcome cannot be text; give its type, or role ignore.", c))
    for (rel in c("nested_in", "derived_from")) {
      p <- g(c, rel); if (is.na(p)) next
      parents <- trimws(strsplit(p, "|", fixed = TRUE)[[1]])
      miss <- setdiff(parents, analysed)
      stop_if(length(miss) > 0, sprintf("`%s`: %s names column(s) not in the data: %s.", c, rel, q(miss)))
      if (length(miss)) next
      key <- do.call(paste, c(lapply(parents, function(x) md[[x]]), sep = "\r"))
      ok <- !is.na(md[[c]]) & !is.na(key)
      if (rel == "derived_from") {
        n <- tapply(md[[c]][ok], key[ok], function(z) length(unique(z)))
        stop_if(any(n > 1), sprintf("`%s`: declared derived from %s, but one combination of those has %d different values of it.", c, q(parents), max(n)))
      } else {
        n <- tapply(key[ok], md[[c]][ok], function(z) length(unique(z)))
        stop_if(any(n > 1), sprintf("`%s`: declared nested in %s, but value '%s' occurs under %d different values of it.", c, q(parents), names(n)[n > 1][1], max(n)))
      }
    }
  }
  extra_rows <- setdiff(guide$column[!guide$role %in% "sample_id"], c(analysed, "sample"))
  for (c in extra_rows) stop_if(TRUE, sprintf("`%s` is in the column guide but not in the data (check the spelling of the column name).", c))
  stop_if(sum(guide$role %in% "sample_id") > 1, sprintf("The column guide gives role sample_id to more than one column: %s.", q(guide$column[guide$role %in% "sample_id"])))
  stop_if(sum(guide$role %in% "sample_control") > 1, sprintf("The column guide gives role sample_control to more than one column: %s. Use one column.", q(guide$column[guide$role %in% "sample_control"])))

  # Columns that always move together (a warning, as in seq-triage). Study
  # samples only: control samples have no design values by construction.
  cand <- info$column[info$n_values > 1 & !grepl("^a different value", info$seen) & !info$role %in% "sample_control"]
  if (length(cand) >= 2) for (a in seq_along(cand)) for (b in seq_along(cand)) if (a < b) {
    x <- md[[cand[a]]][study_rows]; y <- md[[cand[b]]][study_rows]; ok <- !is.na(x) & !is.na(y)
    if (sum(ok) > 1 && all(tapply(y[ok], x[ok], function(z) length(unique(z))) == 1) && all(tapply(x[ok], y[ok], function(z) length(unique(z))) == 1)) {
      declared <- (g(cand[a], "derived_from") %in% cand[b]) || (g(cand[b], "derived_from") %in% cand[a]) ||
                  any(c(g(cand[a], "role"), g(cand[b], "role")) %in% "ignore")
      if (!declared)
        add("design", "warning", sprintf("`%s` and `%s` always move together: each value of one comes with one value of the other, so their effects cannot be separated. If one is derived from the other, say so with derived_from (or give it role ignore).", cand[a], cand[b]))
    }
  }
  check <- if (length(findings)) do.call(rbind, findings) else data.frame(column = character(0), status = character(0), message = character(0))
  list(md = md, info = info, findings = check, stops = stops)
}

# Without a guide nothing is analysed (D95): a draft with facts only.
guide_draft <- function(md) {
  cols <- setdiff(names(md), "sample")
  data.frame(column = cols, role = "", type = "", levels = "", missing_codes = "", unit = "", nested_in = "", derived_from = "",
             description = "", seen_in_data = vapply(cols, function(c) seen(md[[c]]), ""), check.names = FALSE, row.names = NULL)
}
