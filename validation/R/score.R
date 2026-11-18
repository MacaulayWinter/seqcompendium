# score.R: from one run's output to one row of numbers, and from those rows
# to each mark (validation/PREREGISTRATION.md §5; CLAUDE.md D33, E7-M4).
# A run's whole compendium is not kept: only the row below, so a grid of
# thousands of runs fits on disk.

FAMILIES <- c("Q2", "Q3", "Q4", "Q5", "Q6", "Q7")

rd <- function(out, ...) { f <- file.path(out, ...); if (file.exists(f)) utils::read.csv(f, stringsAsFactors = FALSE) else NULL }

# V-E1: the profile against the generator's truth.
profile_matches <- function(prof, truth) {
  v <- function(layer, prop) prof$value[prof$layer == layer & prof$property == prop][1]
  want <- c(shape = "S1 counts", unit = "count", design_class = truth$class, subjects = as.character(truth$subjects),
            timepoints = truth$timepoints, blocks = truth$blocks, n_study_samples = as.character(truth$n_study_samples),
            predictor = if (truth$design == "three_group") "levels: control|dose_low|dose_high; reference: control" else "levels: control|treated; reference: control")
  got <- c(shape = v("sim_counts", "shape"), unit = v("sim_counts", "unit"), design_class = v("design", "design_class"),
           subjects = v("design", "subjects"), timepoints = v("design", "timepoints"), blocks = v("design", "blocks"),
           n_study_samples = v("sim_counts", "n_study_samples"), predictor = v("design", "predictor_group"))
  bad <- names(want)[is.na(got) | got != want]
  list(ok = !length(bad), bad = paste(sprintf("%s: got %s, truth %s", bad, got[bad], want[bad]), collapse = "; "))
}

# V-E8: the honesty checks on one output.
honesty <- function(out, leads) {
  asked <- unique(leads$question)
  every_q <- all(sprintf("Q%d", 0:11) %in% asked)
  # The frozen check is for the two-sample rank tests: 2 / choose(2n, n) for
  # the smallest group n (the simulated groups are equal). The paired rank and
  # permutation floors are checked by their own formulas (2 / 2^n, 1 / (R-PERM + 1)).
  nm <- seqcompendium:::METHOD_NAMES
  pf <- leads[is.finite(leads$p_floor), , drop = FALSE]
  nmin <- function(x) suppressWarnings(min(as.integer(strsplit(as.character(x), "[^0-9]+")[[1]]), na.rm = TRUE))
  want <- vapply(seq_len(nrow(pf)), function(i) {
    n <- nmin(pf$n_per_group[i]); m <- pf$method[i]
    if (m %in% nm[c("K02", "D17")]) 2 / choose(2 * n, n) else if (m %in% nm["K02p"]) 2 / 2^n else if (m %in% nm[c("K04", "K04p")]) 1 / (seqcompendium:::rule("R-PERM") + 1) else NA_real_
  }, 0)
  floor_ok <- all(is.finite(want) & abs(pf$p_floor - want) <= 1e-9 * pmax(1, pf$p_floor))
  pooled <- !any(leads$timepoint %in% "all" & leads$question != "Q6")
  copy <- tempfile("figcopy"); dir.create(copy)
  file.copy(list.files(out, full.names = TRUE), copy, recursive = TRUE)
  fig <- tryCatch({ seqcompendium::draw_figures(copy); TRUE }, error = function(e) FALSE)
  unlink(copy, recursive = TRUE)
  c(every_question = every_q, p_floor = floor_ok, no_pooling = pooled, figures_csv_only = fig)
}

# Control samples must appear in no result table (V-E2b).
controls_absent <- function(out, controls) {
  f <- list.files(file.path(out, "03_results"), pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  hit <- vapply(f, function(x) { t <- readLines(x, warn = FALSE); any(vapply(controls, function(s) any(grepl(sprintf("(^|,|\")%s(\"|,|$)", s), t)), TRUE)) }, TRUE)
  !any(hit)
}

# One run's row. out: the compendium folder; truth: the generator's truth.
run_record <- function(out, truth, mark, scenario, k, seconds, error = NA_character_) {
  base <- data.frame(mark = mark, scenario = scenario, k = k, seed = truth$seed, seconds = round(seconds, 1), error = error, stringsAsFactors = FALSE)
  if (!is.na(error)) return(base)
  leads <- rd(out, "05_leads", "leads.csv")
  for (q in FAMILIES) {
    r <- leads[leads$question == q, , drop = FALSE]
    base[[paste0("asked_", q)]] <- any(!r$status %in% c("not_asked", "not_testable"))
    base[[paste0("lead_", q)]] <- any(r$status == "lead")
  }
  q4 <- leads[leads$question == "Q4" & leads$status == "lead", , drop = FALSE]
  base$planted_n <- length(truth$planted)
  base$planted_found <- sum(truth$planted %in% q4$feature)
  base$false_q4_leads <- length(setdiff(unique(q4$feature), truth$planted))
  ov <- rd(out, "02_method_choice", "override.csv")
  base$override_units <- if (is.null(ov)) 0L else nrow(ov)
  base$override_switched <- if (is.null(ov)) NA else any(ov$decision == "switched")
  base$override_decisions <- if (is.null(ov)) NA else paste(unique(ov$decision), collapse = " | ")
  q0 <- leads[leads$question == "Q0" & leads$status == "lead", , drop = FALSE]
  base$contaminants_n <- length(truth$contaminants)
  base$contaminants_flagged <- sum(truth$contaminants %in% q0$feature)
  ctl <- rd(out, "00_input_check", "controls.csv")
  ctl_names <- c("BLANK1", "BLANK2", "MOCK1")
  base$controls_listed <- !is.null(ctl) && all(ctl_names %in% ctl$sample)
  base$controls_absent <- controls_absent(out, ctl_names)
  pm <- profile_matches(rd(out, "01_profile", "shape_profile.csv"), truth)
  base$profile_ok <- pm$ok; base$profile_diff <- pm$bad
  h <- honesty(out, leads)
  for (nm in names(h)) base[[paste0("honest_", nm)]] <- h[[nm]]
  base
}

# --- From rows to marks. Each returns rows of marks.csv:
#     mark, scenario, number, threshold, pass.
mark_row <- function(mark, scenario, number, threshold, pass, runs) data.frame(mark = mark, scenario = scenario, number = number, threshold = threshold, pass = pass, runs = runs, stringsAsFactors = FALSE)

score_ve3 <- function(rows, limit = 0.142) {
  out <- list()
  for (s in unique(rows$scenario)) {
    r <- rows[rows$scenario == s & is.na(rows$error), , drop = FALSE]
    for (q in FAMILIES) {
      a <- r[[paste0("asked_", q)]]; if (!any(a, na.rm = TRUE)) next
      x <- mean(r[[paste0("lead_", q)]][a])
      out[[length(out) + 1]] <- mark_row("V-E3", paste(s, q), x, sprintf("<= %.3f", limit), x <= limit, sum(a))
    }
    nerr <- sum(rows$scenario == s & !is.na(rows$error))
    if (nerr) out[[length(out) + 1]] <- mark_row("V-E3", paste(s, "runs that failed"), nerr, "0", FALSE, sum(rows$scenario == s))
  }
  do.call(rbind, out)
}

score_ve4 <- function(rows, limit = 0.80) {
  do.call(rbind, lapply(unique(rows$scenario), function(s) {
    r <- rows[rows$scenario == s & is.na(rows$error), , drop = FALSE]
    x <- sum(r$planted_found) / sum(r$planted_n)
    mark_row("V-E4", s, x, sprintf(">= %.2f", limit), x >= limit, nrow(r))
  }))
}

# V-E5: miscalibrated says whether the default's FDR, measured separately,
# exceeded R-CAL x R-FDR; switches must then be >= 0.90, keeps otherwise.
score_ve5 <- function(rows, fdr, limit = 0.90) {
  do.call(rbind, lapply(unique(rows$scenario), function(s) {
    r <- rows[rows$scenario == s & is.na(rows$error) & rows$override_units > 0, , drop = FALSE]
    mis <- fdr$miscalibrated[fdr$scenario == s]
    x <- if (isTRUE(mis)) mean(r$override_switched) else mean(!r$override_switched)
    mark_row("V-E5", sprintf("%s (default FDR %.3f: %s)", s, fdr$fdr[fdr$scenario == s], if (isTRUE(mis)) "miscalibrated, share switched" else "calibrated, share kept"),
             x, sprintf(">= %.2f", limit), x >= limit, nrow(r))
  }))
}

score_ve6 <- function(d, hit = 0.90, clean = 0.10) {
  # d: family, kind ("violated" or "clean"), flagged (share of features or tests flagged in one dataset)
  do.call(rbind, lapply(unique(d$family), function(f) {
    v <- d[d$family == f & d$kind == "violated", ]; c0 <- d[d$family == f & d$kind == "clean", ]
    rbind(mark_row("V-E6", paste(f, "violations flagged"), mean(v$flagged), sprintf(">= %.2f", hit), mean(v$flagged) >= hit, nrow(v)),
          mark_row("V-E6", paste(f, "clean flagged"), mean(c0$flagged), sprintf("<= %.2f", clean), mean(c0$flagged) <= clean, nrow(c0)))
  }))
}

score_ve2b_contaminants <- function(rows, limit = 0.80) {
  x <- sum(rows$contaminants_flagged, na.rm = TRUE) / sum(rows$contaminants_n, na.rm = TRUE)
  mark_row("V-E2b", "planted contaminants flagged by Q0", x, sprintf(">= %.2f", limit), x >= limit, sum(is.na(rows$error)))
}

score_ve8 <- function(rows) {
  r <- rows[is.na(rows$error), , drop = FALSE]
  do.call(rbind, lapply(grep("^honest_", names(r), value = TRUE), function(nm) {
    x <- mean(r[[nm]]); mark_row("V-E8", sub("^honest_", "", nm), x, "= 1", x == 1, nrow(r))
  }))
}
