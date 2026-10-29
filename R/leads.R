# leads.R: the leads table (design §8). One row per thing the engine asked,
# including what found nothing and what could not be asked. Never filtered.

LEAD_COLS <- c("lead_id", "tier", "rank", "status", "question", "layer", "feature", "contrast", "timepoint", "block",
               "effect", "effect_unit", "ci_low", "ci_high", "p", "q", "p_floor", "n_per_group", "method", "method_role",
               "agreement", "agreement_label", "loo_stable", "min_detectable_effect", "caveats", "flags", "result_file")

QUESTIONS <- c(Q0 = "Which features look like contaminants?", Q1 = "What is there?", Q2 = "Does within-sample diversity differ?",
               Q3 = "Does overall composition differ?", Q4 = "Which features differ in abundance?", Q5 = "Which features differ in presence?",
               Q6 = "How does it change over time?", Q7 = "Which feature sets shift together?", Q8 = "Which genes go with a phenotype, allowing for relatedness?",
               Q9 = "Which pairs share strains, and what predicts it?", Q10 = "Is activity (RNA given DNA) different?", Q11 = "Do the layers relate to each other?")

lead_row <- function(...) {
  x <- list(...)
  r <- as.data.frame(stats::setNames(rep(list(NA), length(LEAD_COLS)), LEAD_COLS), stringsAsFactors = FALSE)
  for (n in names(x)) r[[n]] <- x[[n]]
  r
}

# Which questions apply to this bundle, and what is not built yet.
unbuilt_rows <- function(layers, des, built = c("Q0", "Q3", "Q4", "Q5", "Q7")) {
  units <- vapply(layers, function(L) L$spec$unit, "")
  has_tree <- any(vapply(layers, function(L) !is.null(L$spec$tree), TRUE))
  has_pair <- any(vapply(layers, function(L) !is.null(L$spec$paired_with), TRUE))
  neg <- any(grepl("^negative_", des$controls$kind))
  plan <- list(
    Q0 = if (!neg) c("not_testable", "no negative control samples, so contaminants cannot be checked"),
    Q6 = if (des$class == "longitudinal") c("not_asked", "change over time is built at milestone E5") else c("not_testable", "the design is not longitudinal (no subject sampled at two or more times)"),
    Q8 = if ("presence" %in% units && has_tree) c("not_asked", "phylogeny-aware association is built at milestone E9") else c("not_testable", "needs a presence/absence layer with a tree (shape S3); this bundle has none"),
    Q9 = c("not_testable", "needs pairwise data (shape S5); this bundle has none"),
    Q10 = if (has_pair) c("not_asked", "paired RNA/DNA activity is built at milestone E8") else c("not_testable", "needs paired RNA and DNA layers (shape S4); this bundle has none"),
    Q11 = if (length(layers) > 1) c("not_asked", "cross-layer questions are built at milestone E10") else c("not_testable", "needs two or more layers on the same samples (shape S7); this bundle has one"))
  plan <- Filter(Negate(is.null), plan)
  do.call(rbind, lapply(names(plan), function(Q) lead_row(lead_id = sprintf("%s-all", Q), status = plan[[Q]][1], question = Q, layer = "all",
                                                          feature = "all", caveats = plan[[Q]][2])))
}

METHOD_NAMES <- c(A02 = "Hill numbers at equal sample coverage (iNEXT), Welch t-test", D01 = "DESeq2, denominator as offset", D09 = "LinDA", D06 = "ANCOM-BC2", D04 = "ALDEx2",
                  R02 = "zero-inflated negative binomial", K02 = "Wilcoxon rank-sum test on the Hill numbers", K04 = "permutation test on CLR", K01 = "Welch t-test on CLR", D17 = "Wilcoxon on CLR",
                  R01 = "logistic regression", G06 = "Firth logistic regression", E02 = "pre-ranked fgsea", N11 = "decontam (prevalence)",
                  `B06 PERMANOVA` = "PERMANOVA on robust Aitchison distance, with betadisper", `B14 mvabund` = "mvabund (negative binomial), betadisper differs")

# Turns one question's result table into leads rows.
as_leads <- function(r, Q, feature_col, base_caveats, contaminants, result_file, des) {
  if (is.null(r) || !nrow(r)) return(NULL)
  do.call(rbind, lapply(seq_len(nrow(r)), function(i) {
    x <- r[i, ]
    feat <- if (is.null(feature_col)) "whole community" else as.character(x[[feature_col]])
    if (Q == "Q2") feat <- sprintf("whole community, Hill q = %d", x$q_order)
    if (Q == "Q7") feat <- sprintf("set %s = %s", x$set_column, x$feature)
    contam <- Q %in% c("Q4", "Q5") && !is.null(contaminants) && any(contaminants$layer == x$layer & contaminants$feature == feat & contaminants$possible_contaminant)
    tested <- x$status %in% c("lead", "no_evidence")
    mid <- x$method_id %||% x$primary %||% "A02"
    lead_row(
      lead_id = gsub("[^A-Za-z0-9=.-]+", "_", sprintf("%s-%s-%s-%s-%s-%s-%s", Q, x$layer, x$predictor, x$contrast, x$timepoint, x$block, feat)),
      tier = if (x$status == "lead") 2L else if (x$status == "no_evidence") 4L else NA_integer_,
      status = x$status, question = Q, layer = x$layer, feature = feat,
      contrast = sprintf("%s: %s", x$predictor, x$contrast), timepoint = x$timepoint, block = x$block,
      effect = x$effect, effect_unit = x$effect_unit %||% sprintf("difference in Hill number q = %d (effective number of features)", x$q_order),
      ci_low = x$ci_low %||% NA, ci_high = x$ci_high %||% NA, p = x$p, q = x$q, p_floor = NA,
      n_per_group = sprintf("%s=%d; %s=%d", sub("^.* vs ", "", x$contrast), x$n_reference, sub(" vs .*$", "", x$contrast), x$n_level),
      method = unname(METHOD_NAMES[mid]) %||% mid, method_role = x$method_role %||% "default",
      agreement = x$agreement %||% "0/0", agreement_label = x$agreement_label %||% "not testable", loo_stable = "not run (milestone E6)",
      min_detectable_effect = "not run (simulation: E4)",
      caveats = paste(c(if (!tested) x$reason, if (nzchar(x$caveat %||% "")) x$caveat,
                        if (contam) "possible contaminant (Q0): flagged, not removed; cannot reach tier 1",
                        if (x$status == "lead") "tier 2 at most: no lead reaches tier 1 until leave-one-out exists (E6)",
                        if (tested) base_caveats), collapse = "; "),
      flags = if (contam) "possible_contaminant" else NA,
      result_file = result_file)
  }))
}

skipped_rows <- function(sk, Q) {
  if (is.null(sk) || !nrow(sk)) return(NULL)
  do.call(rbind, lapply(seq_len(nrow(sk)), function(i) lead_row(
    lead_id = gsub("[^A-Za-z0-9=.-]+", "_", sprintf("%s-%s-%s-%s-%s-%s-skipped", Q, sk$layer[i], sk$predictor[i] %||% "", sk$contrast[i] %||% "", sk$timepoint[i] %||% "", sk$block[i] %||% "")),
    status = "not_testable", question = Q, layer = sk$layer[i], feature = "all",
    contrast = if (!is.null(sk$predictor) && !is.na(sk$contrast[i])) sprintf("%s: %s", sk$predictor[i], sk$contrast[i]) else NA,
    timepoint = sk$timepoint[i] %||% NA, block = sk$block[i] %||% NA, caveats = sk$reason[i])))
}

build_leads <- function(res, layers, des) {
  rows <- list(lead_row(lead_id = "Q1-all", status = "described", question = "Q1", layer = paste(names(layers), collapse = "; "), feature = "all",
                        caveats = "description only, not a test", result_file = "03_results/Q1_describe/results.csv"))
  base_caveats <- c("leave-one-out not run yet (E6)",
                    if (length(des$batch)) sprintf("batch %s not adjusted for yet (milestone E5, with the other covariates)", q(des$batch)),
                    if (length(des$grouping) > 1) "each predictor is compared on its own, not adjusted for the others (E5)",
                    if (!any(grepl("^negative_", des$controls$kind))) "no negative controls, so contaminants could not be checked")
  if (!is.null(res$q0)) for (nm in unique(res$q0$layer)) {
    x <- res$q0[res$q0$layer == nm, ]
    fl <- x$feature[x$possible_contaminant]
    rows[[length(rows) + 1]] <- lead_row(lead_id = sprintf("Q0-%s", nm), status = "described", question = "Q0", layer = nm,
      feature = if (length(fl)) paste(fl, collapse = "; ") else "none flagged", method = METHOD_NAMES[["N11"]], method_role = "default",
      agreement = "0/0", agreement_label = "not testable",
      caveats = sprintf("%d of %d features flagged as possible contaminants; flagged features stay in every analysis (C24)", length(fl), nrow(x)),
      flags = if (length(fl)) "possible_contaminant" else NA, result_file = "03_results/Q0_contaminants/results.csv")
  }
  rows <- c(rows,
    list(as_leads(res$q2$results, "Q2", NULL, base_caveats, NULL, "03_results/Q2_alpha/results.csv", des), skipped_rows(res$q2$skipped, "Q2")),
    list(as_leads(res$q3$results, "Q3", NULL, base_caveats, NULL, "03_results/Q3_composition/results.csv", des), skipped_rows(res$q3$skipped, "Q3")),
    list(as_leads(res$q4$results, "Q4", "feature", base_caveats, res$q0, "03_results/Q4_differential/results.csv", des), skipped_rows(res$q4$skipped, "Q4")),
    list(as_leads(res$q5$results, "Q5", "feature", base_caveats, res$q0, "03_results/Q5_presence/results.csv", des), skipped_rows(res$q5$skipped, "Q5")),
    list(as_leads(res$q7$results, "Q7", "feature", base_caveats, NULL, "03_results/Q7_sets/results.csv", des), skipped_rows(res$q7$skipped, "Q7")))
  for (Q in c("Q2", "Q3", "Q4", "Q5", "Q7")) {
    have <- any(vapply(Filter(Negate(is.null), rows), function(r) any(r$question == Q), TRUE))
    if (!have) rows[[length(rows) + 1]] <- lead_row(lead_id = sprintf("%s-all", Q), status = "not_testable", question = Q, layer = "all", feature = "all",
                                                    caveats = if (!length(des$grouping)) "no grouping predictor declared in the column guide" else "nothing to test in this bundle")
  }
  leads <- rbind(do.call(rbind, Filter(Negate(is.null), rows)), unbuilt_rows(layers, des))
  if (!nrow(des$controls)) leads$flags <- ifelse(is.na(leads$flags), "no_controls", paste(leads$flags, "no_controls", sep = "; "))
  # Rank: tier first, then the size of the effect relative to its interval (C17).
  score <- abs(leads$effect) / pmax(leads$ci_high - leads$ci_low, .Machine$double.eps)
  o <- order(is.na(leads$tier), leads$tier, -ifelse(is.na(score), -Inf, score), as.integer(sub("^Q", "", leads$question)), leads$lead_id)
  leads <- leads[o, ]
  leads$rank <- ifelse(is.na(leads$tier), NA_integer_, cumsum(!is.na(leads$tier)))
  rownames(leads) <- NULL
  leads[, LEAD_COLS]
}
