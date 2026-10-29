# design.R: the design, read only from the column guide (design §2.9, §2.10).

# Splits study samples from control samples (F8) and names each column's role.
read_design <- function(md, guide, info) {
  role_of <- function(r) info$column[info$role %in% r]
  type_of <- function(c) info$type[match(c, info$column)]
  ctl <- role_of("sample_control")[1]
  kind <- if (!is.na(ctl)) md[[ctl]] else rep("none", nrow(md))
  controls <- data.frame(sample = md$sample[kind != "none"], kind = kind[kind != "none"], stringsAsFactors = FALSE)
  study <- md[kind == "none", , drop = FALSE]
  pred <- role_of("predictor")
  grouping <- pred[type_of(pred) %in% c("binary", "categorical", "ordinal")]
  levels_of <- function(c) split_levels(guide$levels[match(c, guide$column)])
  subj <- role_of("subject_id")[1]; tim <- role_of("time")[1]; blk <- role_of("block"); bat <- role_of("batch")
  # Time values in their declared order (ordinal levels; otherwise numbers or dates sort).
  time_order <- if (is.na(tim)) character(0) else {
    lv <- levels_of(tim); u <- unique(stats::na.omit(study[[tim]]))
    if (length(lv)) intersect(lv, u) else if (type_of(tim) %in% c("count", "continuous")) as.character(sort(as.numeric(u))) else sort(u)
  }
  long <- FALSE; repeated_within_time <- FALSE
  if (!is.na(subj)) {
    s <- study[[subj]]
    if (!is.na(tim)) {
      tt <- tapply(study[[tim]], s, function(x) length(unique(stats::na.omit(x))))
      long <- any(tt >= 2, na.rm = TRUE)
      repeated_within_time <- any(duplicated(paste(s, study[[tim]])[!is.na(s)]))
    } else repeated_within_time <- any(duplicated(stats::na.omit(s)))
  }
  class <- if (long) "longitudinal" else if (repeated_within_time) "snapshot-paired" else "snapshot-independent"
  list(controls = controls, study = study, grouping = grouping, continuous = setdiff(pred, grouping), levels_of = levels_of,
       subject = subj, time = tim, time_order = time_order, block = blk, batch = bat, outcome = role_of("outcome"),
       ctl_column = ctl, class = class)
}

# The cells within which every comparison is made: timepoint x block. Time
# and blocks are never pooled (X0124).
design_cells <- function(des) {
  st <- des$study
  tp <- if (is.na(des$time)) rep("none", nrow(st)) else ifelse(is.na(st[[des$time]]), "missing", st[[des$time]])
  bk <- if (length(des$block)) do.call(paste, c(lapply(des$block, function(b) paste0(b, "=", st[[b]])), sep = "; ")) else rep("none", nrow(st))
  data.frame(sample = st$sample, timepoint = tp, block = bk, stringsAsFactors = FALSE)
}

design_text <- function(des, info) {
  st <- des$study; out <- character(0)
  for (c in c(des$grouping, des$continuous, des$block)) {
    t <- info$type[match(c, info$column)]; r <- info$role[match(c, info$column)]
    out <- c(out, if (t %in% c("count", "continuous", "proportion")) {
      x <- suppressWarnings(as.numeric(st[[c]]))
      sprintf("- `%s` (%s, %s): %s to %s; a covariate, not groups.", c, r, t, format(min(x, na.rm = TRUE)), format(max(x, na.rm = TRUE)))
    } else {
      tb <- table(factor(st[[c]], levels = unique(c(des$levels_of(c), sort(unique(stats::na.omit(st[[c]])))))))
      sprintf("- `%s` (%s, %s): %s%s", c, r, t, paste(sprintf("%s (n = %d)", names(tb), as.vector(tb)), collapse = ", "),
              if (length(des$levels_of(c))) sprintf("; reference level `%s`", des$levels_of(c)[1]) else "; **no levels listed, so no reference level is declared**")
    })
  }
  if (!is.na(des$subject)) {
    n_per <- table(st[[des$subject]])
    out <- c(out, sprintf("- `%s` (subject_id): %d subjects, %s sample(s) each.", des$subject, length(n_per),
                          if (length(unique(as.vector(n_per))) == 1) n_per[1] else paste(range(n_per), collapse = " to ")))
  }
  if (!is.na(des$time)) out <- c(out, sprintf("- `%s` (time): %d timepoint(s), in order: %s.", des$time, length(des$time_order), paste(des$time_order, collapse = ", ")))
  for (b in des$batch) out <- c(out, sprintf("- `%s` (batch): %s.", b, paste(sprintf("%s (n = %d)", names(table(st[[b]])), as.vector(table(st[[b]]))), collapse = ", ")))
  out <- c(out, sprintf("- Layout: **%s**.", switch(des$class, longitudinal = "change over time (the same subjects sampled repeatedly)",
                                                   `snapshot-paired` = "a snapshot, with subjects sampled more than once",
                                                   "a snapshot (independent samples)")))
  out <- c(out, sprintf("- Study samples: %d. Control samples (never analysed as biology): %d.", nrow(st), nrow(des$controls)))
  out
}
