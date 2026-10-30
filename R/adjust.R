# adjust.R: what each comparison is adjusted for (CLAUDE.md D24, the user's
# choice of option (a), 2026-10-30).
#
# Batch and every other declared predictor enter as main effects. Never:
# outcomes, ignored or text columns, the subject, time or block (the design
# handles those). Safeguard: fewer than R-SPP samples per fixed-effect
# parameter drops the adjustment to batch only, then to none. A covariate
# constant within the comparison, with missing values, or confounded with the
# predictor (it adds no new column to the model) is left out and named.

covariate_frame <- function(st, col, des) {
  t <- des$types[[col]]
  v <- st[[col]]
  if (t %in% c("count", "continuous", "proportion")) as.numeric(v)
  else if (t == "date") as.numeric(as.Date(v))
  else factor(v, levels = unique(c(des$levels_of(col), sort(unique(stats::na.omit(v))))))
}

# samples: the comparison's samples; focus: the predictor being compared;
# base: the design's own model matrix for these samples (intercept, the
# focus, and time terms in a longitudinal model).
adjustment_for <- function(samples, des, focus, base) {
  st <- des$study[match(samples, des$study$sample), , drop = FALSE]
  want <- c(des$batch, setdiff(c(des$grouping, des$continuous), focus))
  notes <- character(0)
  usable <- function(cols) {
    keep <- character(0); X <- base
    for (c in cols) {
      if (!des$types[[c]] %in% c("binary", "categorical", "ordinal", "count", "continuous", "proportion", "date")) { notes <<- c(notes, sprintf("`%s` (type %s cannot be adjusted for)", c, des$types[[c]])); next }
      v <- covariate_frame(st, c, des)
      if (anyNA(v)) { notes <<- c(notes, sprintf("`%s` (missing for some samples here)", c)); next }
      if (length(unique(v)) < 2) next   # constant here: nothing to adjust
      M <- stats::model.matrix(~ v)[, -1, drop = FALSE]
      if (qr(cbind(X, M))$rank < ncol(X) + ncol(M)) { notes <<- c(notes, sprintf("`%s` (confounded with `%s` or another covariate here, so their effects cannot be separated)", c, focus)); next }
      X <- cbind(X, M); keep <- c(keep, c)
    }
    list(cols = keep, params = ncol(X))
  }
  n <- length(samples)
  full <- usable(want)
  chosen <- full; why <- ""
  if (n / full$params < rule("R-SPP")) {
    b <- usable(intersect(des$batch, full$cols))
    if (length(b$cols) && n / b$params >= rule("R-SPP")) { chosen <- b; why <- sprintf("adjusted for batch only: %d samples for %d parameters with every covariate, fewer than %d per parameter (R-SPP)", n, full$params, rule("R-SPP")) }
    else { chosen <- list(cols = character(0), params = ncol(base)); why <- sprintf("not adjusted: %d samples for %d parameters, fewer than %d per parameter (R-SPP)", n, full$params, rule("R-SPP")) }
  }
  cov <- if (length(chosen$cols)) as.data.frame(stats::setNames(lapply(chosen$cols, function(c) covariate_frame(st, c, des)), sprintf("cov%d", seq_along(chosen$cols)))) else NULL
  label <- if (length(chosen$cols)) paste(chosen$cols, collapse = ", ") else "nothing"
  text <- paste(c(sprintf("adjusted for %s", label), if (nzchar(why)) why, if (length(notes)) sprintf("left out: %s", paste(notes, collapse = "; "))), collapse = "; ")
  list(cov = cov, cols = chosen$cols, adjusted_for = text)
}

cov_terms <- function(cov) if (is.null(cov) || !ncol(cov)) "" else paste0(paste(names(cov), collapse = " + "), " + ")
