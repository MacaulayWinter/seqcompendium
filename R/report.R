# report.R: the plain-language report (design §7). It reads only what the
# models already wrote; the wording is fixed so reports read the same across
# studies. Markdown is always written; HTML is rendered from it with
# rmarkdown when pandoc is available (it is, in the container).

md_table <- function(d, cols = names(d), max_rows = Inf) {
  d <- utils::head(d, max_rows)
  fmt <- function(v) if (is.numeric(v)) ifelse(is.na(v), "NA", formatC(v, digits = 3, format = "g")) else ifelse(is.na(v), "NA", as.character(v))
  c(sprintf("| %s |", paste(cols, collapse = " | ")), sprintf("|%s|", paste(rep("---", length(cols)), collapse = "|")),
    if (nrow(d)) vapply(seq_len(nrow(d)), function(i) sprintf("| %s |", paste(vapply(cols, function(c) fmt(d[[c]][i]), ""), collapse = " | ")), ""))
}

write_report <- function(out, ctx) {
  L <- character(0); add <- function(...) L <<- c(L, ...)
  des <- ctx$des; leads <- ctx$leads; q2 <- ctx$q2
  add("# Compendium report", "",
      sprintf("seqcompendium %s (milestone E1, the walking skeleton). Rules version %s. FDR level for a lead: q <= %s (rule R-FDR), on every page.",
              ENGINE_VERSION(), rules()$rules_version, rule("R-FDR")), "",
      "**This is an exploratory survey.** The leads at the end are things worth a closer look, not findings.", "")
  if (!nrow(des$controls)) add("> **Warning: this design has no control samples.** No negative controls means contaminants cannot be checked, and no mock community means the methods cannot be checked against a known truth. Every row of the leads table carries the flag `no_controls`.", "")

  add("## 1. Input check", "", sprintf("The bundle at `%s` was read and checked. Every check is in `00_input_check/bundle_check.csv`.", ctx$bundle_path), "")
  nb <- ctx$check[ctx$check$status != "passed", , drop = FALSE]
  add(if (nrow(nb)) sprintf("- **%s** (%s): %s", nb$status, nb$check, nb$message) else "- All checks passed, with no notes.", "")

  add("## 2. Controls", "", "Control samples are declared in the column guide (role `sample_control`). They are never analysed as biology: they are left out of every result below.", "")
  if (nrow(ctx$controls)) {
    add(md_table(ctx$controls), "")
    mk <- ctx$res$override$mock
    if (!is.null(mk$note)) add(sprintf("Mock check: %s.", mk$note), "")
    if (!is.null(mk$recovery)) add("Mock recovery (how well each mock community's known members were found; `00_input_check/mock_recovery.csv`):", "", md_table(mk$recovery), "")
    if (!is.null(mk$test)) add("Mock test (labels shuffled among the mocks; a method that reports a difference between mock replicates cannot be chosen; `02_method_choice/simulation/mock_test.csv`):", "", md_table(mk$test), "")
  }
  else add("No control samples.", "")

  add("## 3. Design as read", "", "Read only from your column guide; nothing about a column was guessed.", "", design_text(des, ctx$info), "")

  add("## 4. Shape profile", "", "Every later choice points back to these rows (`01_profile/shape_profile.csv`).", "", md_table(ctx$profile), "")

  add("## 5. How the methods were chosen", "",
      sprintf("The catalogue has %d methods. For this bundle %d were eligible; every one, with the reason it was or was not, is in `02_method_choice/methods_considered.csv`. Each question then uses the fixed default of the design (section 5.2) for this data shape; the facts it rests on are below. No method was chosen by looking at your data's p-values. For Q4, the default is then checked on simulated data made from your own reference samples, and replaced only if it fails that check (section 10, Q4).",
              length(unique(ctx$considered$id)), sum(ctx$considered$eligible == "yes")), "",
      md_table(ctx$choices, c("layer", "question", "default_id", "default_method", "rests_on", "default_eligible")), "")

  add("## 6. Q1. What is there?", "", "Description only, no test. Prevalence and median per feature, group, timepoint and block: `03_results/Q1_describe/results.csv`. The ten most prevalent features overall:", "")
  q1 <- ctx$q1; top <- stats::aggregate(prevalence ~ layer + feature, q1, mean); top <- top[order(-top$prevalence, top$feature), ]
  add(md_table(top, max_rows = 10), "")

  five <- function(asked, why, checks, limits, agree) add(
    sprintf("**What was asked.** %s", asked), "", sprintf("**Why this method.** %s", why), "", sprintf("**What the checks showed.** %s", checks), "",
    sprintf("**Limitations.** %s", limits), "", sprintf("**Did the alternatives agree.** %s Agreement is not proof: methods that agree can share the same bias.", agree), "")
  # The top leads of one question (up to 10, by rank), with agreement and stability (D29, E6-M5).
  top_leads <- function(Q) {
    x <- leads[leads$question == Q & leads$status == "lead", , drop = FALSE]
    if (!nrow(x)) return(add(sprintf("No %s result reached the lead threshold.", Q), ""))
    x <- x[order(x$rank), , drop = FALSE]
    add(sprintf("Top %s leads (of %d; all in `05_leads/leads.csv`):", Q, nrow(x)), "",
        md_table(x, c("rank", "tier", "feature", "contrast", "timepoint", "effect", "q", "agreement_label", "loo_stable"), max_rows = 10), "")
  }
  agree_summary <- function(r) if (is.null(r) || !nrow(r)) "Not testable." else {
    tb <- table(factor(r$agreement_label, levels = c("agreed", "partly agreed", "disagreed", "not testable")))
    sprintf("Per result: %s.", paste(sprintf("%s %d", names(tb), as.vector(tb)), collapse = ", "))
  }
  batch_note <- " What each result was adjusted for is in its `adjusted_for` column (batch and the other declared predictors where the sample size allows; CLAUDE.md D24)."
  res <- ctx$res

  add("## 7. Q0. Which features look like contaminants?", "")
  if (is.null(res$q0)) add("Not testable: no negative control samples were declared.", "")
  else {
    fl <- res$q0[res$q0$possible_contaminant, ]
    five("Which features are more common in the negative controls than in the study samples?",
         "decontam's prevalence method (catalogue N11), comparing the declared negative controls (F8) with the study samples.",
         "None needed: a description, not a model.",
         "With few negative controls the score is coarse. A feature common in both blanks and samples is not flagged. Flagged features are never removed (C24): they stay in every analysis and their leads cannot reach tier 1.",
         "Not testable: the design has no alternative for Q0.")
    add(sprintf("%d of %d features flagged: %s. Full table: `03_results/Q0_contaminants/results.csv`.", nrow(fl), nrow(res$q0), if (nrow(fl)) paste(fl$feature, collapse = ", ") else "none"), "")
  }

  add("## 8. Q2. Does within-sample diversity differ?", "")
  r <- q2$results
  if (is.null(r)) add("Q2 could not be asked: see the leads table for the reason.", "")
  else for (nm in unique(r$layer)) for (p in unique(r$predictor[r$layer == nm])) {
    x <- r[r$layer == nm & r$predictor == p, , drop = FALSE]
    cov <- unique(signif(q2$per_sample$coverage[q2$per_sample$layer == nm], 3))
    prof <- ctx$profile[ctx$profile$layer == nm, ]
    pv <- function(k) prof$value[prof$property == k]
    add(sprintf("### Layer `%s`, by `%s`", nm, p), "")
    five(sprintf("Does the number and evenness of features (alpha diversity, Hill numbers q = 0, 1, 2) differ between the levels of `%s`, against the reference level `%s`, at each timepoint and block separately? Timepoints are never pooled.", p, des$levels_of(p)[1]),
         sprintf("%sHill numbers at equal sample coverage (iNEXT, catalogue A02), compared with Welch t-tests (K01) or, when covariates apply (D24), a linear model. Chosen because the data are counts (shape %s), library size varies %s-fold between study samples, and within each timepoint every subject is sampled once (design class: %s). Standardising to equal coverage (here %s) avoids comparing deeply and shallowly sequenced samples unfairly; Welch's test does not assume equal spread. q-values: Benjamini-Hochberg within each contrast, timepoint and block, over the three orders.",
                 if (isTRUE(res$long)) "Because the same subjects were sampled over time, a linear mixed model with subject as a random effect (L01) was used, set up so each timepoint's difference is its own estimate (timepoints are never pooled). " else "",
                 pv("shape"), pv("library_size_max_over_min"), des$class, paste(cov, collapse = ", ")),
         sprintf("Residual skewness above %s moves a comparison to the Wilcoxon rank-sum test; %d of %d comparisons moved (`03_results/Q2_alpha/diagnostics.csv`).", rule("R-SKEW"), sum(x$method_role != "default"), nrow(x)),
         sprintf("A handful of samples per group gives little power: a difference can be real and still not reach q <= %s. Each predictor is compared on its own.%s Hill numbers count features, so one organism or gene split by the database inflates q = 0.%s",
                 rule("R-FDR"), batch_note, if (!nrow(des$controls)) " There are no controls, so contaminant features may be counted as diversity." else ""),
         paste("Alternatives: plug-in Hill numbers on rarefied counts (A01) and DivNet (A04, q = 1 and 2 only).", agree_summary(x)))
    add(md_table(x, c("contrast", "timepoint", "block", "q_order", "n_reference", "n_level", "effect", "ci_low", "ci_high", "p", "q", "status", "method_role", "agreement", "agreement_label", "loo_stable")), "")
  }
  if (!is.null(r)) top_leads("Q2")

  add("## 9. Q3. Does overall composition differ?", "")
  r <- res$q3$results
  if (is.null(r)) add("Q3 could not be asked: see the leads table for the reason.", "")
  else {
    five("Does the whole community's make-up differ between each level and the reference, within each timepoint and block?",
         "PERMANOVA (B06) on robust Aitchison distance (B03), which respects that the data are proportions of a whole, always reported with betadisper (B07), because PERMANOVA cannot tell a shift in location from a difference in spread when groups are unbalanced (Anderson and Walsh 2013).",
         sprintf("betadisper differed (p < %s) with unbalanced groups (ratio above %s) in %d of %d comparisons; there mvabund (B14) is the primary and the result says why. betadisper itself fires by chance in about %.0f%% of comparisons whose spread is really equal, so a switch to mvabund is a precaution, not proof that spread differs.", rule("R-DIAGP"), rule("R-UNBAL"), sum(r$primary == "B14 mvabund"), nrow(r), 100 * rule("R-DIAGP")),
         sprintf("Permutation p-values cannot go below 1/%d. R-squared is the share of variation explained, not a size of difference in any one feature.%s", rule("R-PERM") + 1, batch_note),
         paste("Alternatives: PERMANOVA on Bray-Curtis of rarefied counts (B01) and mvabund (B14). ANOSIM and SIMPER are shown in `04_agreement/Q3.csv` for comparison only (F1).", agree_summary(r)))
    add(md_table(r, c("layer", "contrast", "timepoint", "block", "group_sizes", "permanova_r2", "permanova_p", "betadisper_p", "primary", "q", "status", "agreement_label", "loo_stable")), "")
    top_leads("Q3")
  }

  # Never silent: an alternative method that could not fit is named, with how often.
  failed_methods <- function(f) {
    p <- file.path(out, f); if (is.null(f) || !file.exists(p)) return("")
    a <- utils::read.csv(p, stringsAsFactors = FALSE)
    if (!"note" %in% names(a)) return("")
    bad <- a[grepl("failed to fit|did not fit", a$note), ]
    if (!nrow(bad)) return("Every alternative method ran.")
    tb <- table(bad$method_id)
    sprintf("**Could not fit:** %s; these are left out of the agreement counts.", paste(sprintf("%s (%d result%s)", names(tb), as.vector(tb), ifelse(tb == 1, "", "s")), collapse = ", "))
  }
  feature_block <- function(r, title, asked, why, checks, limits, alts, file, agr_file = NULL) {
    add(title, "")
    if (is.null(r)) { add("Could not be asked: see the leads table for the reason.", ""); return(invisible()) }
    five(asked, why, checks, limits, paste(alts, agree_summary(r), failed_methods(agr_file)))
    r$tested <- 1L; r$leads <- as.integer(r$status == "lead")
    s <- stats::aggregate(cbind(tested, leads) ~ layer + contrast + timepoint + block, data = r, FUN = sum)
    add(md_table(s), "", sprintf("Every feature, with its method, rung, effect, q and agreement: `%s`.", file), "")
    top_leads(sub("^## [0-9]+\\. (Q[0-9]+)\\..*$", "\\1", title))
  }
  r4 <- res$q4$results
  # The range the residual checks and the chance rule were tested on (D17's
  # grid; CLAUDE.md D22). A comparison outside it is flagged, not refused.
  feature_range_note <- function(r) {
    n <- stats::aggregate(feature ~ layer + contrast + timepoint + block, data = r, FUN = length)
    out <- n[n$feature < 30 | n$feature > 300, ]
    sprintf("The residual checks and the rule for moving a whole comparison were tested on 30 to 300 features per comparison; this bundle has %d to %d.%s",
            min(n$feature), max(n$feature),
            if (nrow(out)) sprintf(" **%d comparison(s) are outside that range, so how often their checks move by chance has not been tested.**", nrow(out)) else "")
  }
  dec <- res$override$decisions
  sim_sentence <- if (is.null(dec)) "" else paste(vapply(seq_len(nrow(dec)), function(i) { d <- dec[i, ]
    where <- sprintf("For %s at timepoint %s, block %s", d$contrast, d$timepoint, d$block)
    if (d$datasets == 0) sprintf("%s: the default method could not be checked on simulated data from your controls, because the control group has n = %d (fewer than %d). The default was kept on the strength of published benchmarks only.", where, d$n_reference, rule("R-MINSIM"))
    else if (d$decision == "kept") sprintf("%s: on %d simulated data sets made from your %d control samples, this method's false discovery rate was %.2f (limit %.2f), so the default was kept.", where, d$datasets, d$n_reference, d$default_fdr, d$limit)
    else if (d$decision == "switched") sprintf("%s: on %d simulated data sets made from your %d control samples, the default's false discovery rate was %.2f (limit %.2f), so the engine switched to %s, the first method in the pre-written priority order that passed.", where, d$datasets, d$n_reference, d$default_fdr, d$limit, METHOD_NAMES[[d$final_id]])
    else sprintf("%s: on %d simulated data sets made from your %d control samples, no method's false discovery rate was within the limit (%.2f), so the default was kept and every result carries that caveat.", where, d$datasets, d$n_reference, d$limit)
  }, ""), collapse = " ")
  feature_block(r4, "## 10. Q4. Which features differ in abundance?",
    "Which features are more or less abundant in each level than in the reference, within each timepoint and block?",
    sprintf("%s. Features present in at least %.0f%% of one group's samples are tested (R-PREV); q-values are Benjamini-Hochberg within each comparison. %s",
            paste(sprintf("Layer `%s`: %s, because %s", ctx$choices$layer[ctx$choices$question == "Q4"], ctx$choices$default_method[ctx$choices$question == "Q4"],
                          ctx$choices$rests_on[ctx$choices$question == "Q4"]), collapse = "; "), 100 * rule("R-PREV"), sim_sentence),
    if (is.null(r4)) "Not run." else paste(feature_range_note(r4),sprintf("Residual checks per feature (DHARMa on a negative binomial refit for count models; residual skewness and spread for LinDA). A feature that fails moves down the fallback ladder to a method that assumes less, and its result says so. %d of %d feature results needed a fallback rung; %d comparison(s) moved as a whole, because clearly more features failed than in clean data simulated from the same features (one-sided Fisher's exact test, p < %s) (`03_results/Q4_differential/diagnostics.csv`).",
                                             sum(r4$rung > 0), nrow(r4), length(unique(paste(r4$timepoint, r4$block, r4$contrast)[r4$whole_question_moved %in% TRUE])), rule("R-EXCESS")),
                                             if (any(is.finite(r4$share_expected_by_chance))) sprintf("**Some of these failures are expected by chance alone:** each feature gets 3 checks at p < %s, so about %.0f%% of features that fit well fail at least one. Compare that with the share that failed in each comparison (column `share_failed_checks`). A share near %.0f%% means most moves are probably chance; a much larger share means the model really does not suit these data. Either way, a moved feature's result is valid: it comes from a method that assumes less.",
                                                                                                rule("R-DIAGP"), 100 * max(r4$share_expected_by_chance, na.rm = TRUE), 100 * max(r4$share_expected_by_chance, na.rm = TRUE)) else ""),
    sprintf("No differential-abundance method is best on all data (Nearing 2022; Wirbel 2024), which is why the alternatives are shown. A per-denominator fold change is not a per-cell change unless the denominator tracks cells. The residual checks miss many features with extra zeros: in a rare feature, extra zeros look like the zeros the model already expects (in a test with 20 subjects per group they caught 6 of 15), so a feature that passed its checks can still have more zeros than modelled.%s", batch_note),
    if (isTRUE(res$long)) sprintf("Because the same subjects were sampled over time, the default is a mixed model with subject as a random effect, set up so each timepoint's group difference is its own estimate. Alternatives: Wilcoxon on CLR within each timepoint, and GEE (L03), which runs only with at least %d subjects (here %d) (`04_agreement/Q4.csv`). LEfSe is shown for comparison only (`04_agreement/Q4_describe_only.csv`, F1); it is known to give many false positives.",
                                   rule("R-GEE"), length(unique(stats::na.omit(des$study[[des$subject]]))))
    else "Alternatives: LinDA or ANCOM-BC2, ALDEx2, and Wilcoxon on CLR (`04_agreement/Q4.csv`). LEfSe is shown for comparison only (`04_agreement/Q4_describe_only.csv`, F1); it is known to give many false positives.",
    "03_results/Q4_differential/results.csv", "04_agreement/Q4.csv")
  if (!is.null(res$override$calibration)) add("The full simulation check: every eligible method's false discovery rate and power on the simulated data sets (half with no planted difference, half with 10% of features planted at fold change 2), whatever the decision (`02_method_choice/simulation/calibration.csv`):", "",
                                              md_table(res$override$calibration, c("contrast", "timepoint", "block", "n_reference", "method_id", "datasets", "failed_fits", "fdr", "power")), "")
  feature_block(res$q5$results, "## 11. Q5. Which features differ in presence?",
    "Is each feature present in a different share of samples in each level than in the reference, within each timepoint and block?",
    "Logistic regression per feature (R01); Firth's correction (G06) where a group is all present or all absent, which ordinary logistic regression cannot fit.",
    "Separation is the check; features that need Firth's correction say so.",
    "Only features whose presence varies are tested. With few samples, presence differences need to be large to be detected.",
    "Alternative: Fisher's exact test (K03).", "03_results/Q5_presence/results.csv", "04_agreement/Q5.csv")
  feature_block(res$q7$results, "## 12. Q7. Which feature sets shift together?",
    "Do the features of a set (each `set` column in the manifest) tend to move together in Q4's ranking?",
    "Pre-ranked fgsea (E02) on Q4's signed z-scores, so the whole ranking is used, not a cut-off list.",
    "None needed beyond Q4's.",
    "Sets come from the annotation the pipeline supplied; a set defined by the result itself would be circular.",
    "Alternative: camera (E03) on CLR values, which allows for correlation between features.", "03_results/Q7_sets/results.csv", "04_agreement/Q7.csv")

  add("## 13. Q6. How does it change over time?", "")
  q6 <- res$q6
  if (is.null(q6)) add(sprintf("Not testable: %s.", des$long_reason %||% "the design is not longitudinal"), "")
  else {
    five("Within each group, how do diversity, each feature, and the whole community change from the first timepoint to each later one?",
         "The same mixed models as Q2 and Q4, parameterised so each group's change from the first timepoint is its own coefficient (subject as a random effect, so each subject is compared with itself); for the whole community, PERMANOVA with permutations restricted within subject.",
         "As for Q2 and Q4: the same residual checks and fallback ladder (rank-based or paired permutation tests when a check fails).",
         "Change is measured against the first timepoint only; a change that comes and goes between later timepoints is not tested here. Subjects missing a timepoint drop out of the paired alternatives.",
         paste("Alternatives: paired Wilcoxon tests (and a GAMM time trend for diversity when there are 4 or more timepoints).", agree_summary(rbind(q6$alpha[, c("agreement_label"), drop = FALSE], q6$features[, c("agreement_label"), drop = FALSE]))))
    for (nm in c("alpha", "features", "composition")) {
      r <- q6[[nm]]; if (is.null(r) || !nrow(r)) next
      r$tested <- 1L; r$leads <- as.integer(r$status == "lead")
      add(sprintf("%s (`03_results/Q6_change/%s.csv`):", c(alpha = "Diversity", features = "Features", composition = "Whole community")[[nm]], nm), "",
          md_table(stats::aggregate(cbind(tested, leads) ~ layer + predictor + group + change + block, data = r, FUN = sum)), "")
    }
    top_leads("Q6")
  }

  idx <- ctx$figures
  if (nrow(idx)) {
    add("## Figures", "", "Each drawn only from the CSV it names.", "")
    for (i in seq_len(nrow(idx))) {
      png <- sub("\\.pdf$", ".png", idx$figure[i])
      add(if (file.exists(file.path(out, png))) sprintf("![%s](../%s)", idx$caption[i], png) else NULL,
          sprintf("- [%s](../%s): %s", idx$figure[i], idx$figure[i], idx$caption[i]), "")
    }
  }

  add("## 14. What was not found", "", "Placed before the leads on purpose: negative results are results.", "")
  ne <- leads[leads$status == "no_evidence", , drop = FALSE]
  if (nrow(ne)) {
    ne$results <- 1L
    s <- stats::aggregate(results ~ question + layer + contrast + timepoint + block, data = ne, FUN = sum)
    add("No evidence of a difference at this sample size, for these results (every one is a row of the leads table):", "", md_table(s), "")
    one <- ne[ne$question %in% c("Q2", "Q3"), , drop = FALSE]
    if (nrow(one)) add(sprintf("- %s, %s, %s, %s, timepoint %s, block %s: effect %s (95%% CI %s to %s), q = %s.",
                               one$question, one$layer, one$feature, one$contrast, one$timepoint, one$block, signif(one$effect, 3), signif(one$ci_low, 3), signif(one$ci_high, 3), signif(one$q, 3)), "")
  } else add("- Every tested comparison reached the lead threshold.", "")
  dec <- res$override$decisions
  if (!is.null(dec)) for (i in seq_len(nrow(dec))) if (is.finite(dec$mde_log2[i]))
    add(sprintf("- Q4, %s, timepoint %s, block %s: on data simulated from your controls, a fold change of about %.1f (log2 %.2f) was found with 80%% power; smaller differences may have been missed.",
                dec$contrast[i], dec$timepoint[i], dec$block[i], 2^dec$mde_log2[i], dec$mde_log2[i]))
  fl <- ne[is.finite(ne$p_floor) & ne$p_floor > rule("R-FDR"), , drop = FALSE]
  if (nrow(fl)) add("", sprintf("%d of these results come from tests whose smallest possible p-value is above %s at these group sizes: this design cannot reach significance there, so they show effect sizes only, not an absence of difference.", nrow(fl), rule("R-FDR")))
  add("")
  nt <- leads[leads$status %in% c("not_testable", "not_asked"), , drop = FALSE]
  add("Questions not asked, or not testable, and why:", "", sprintf("- %s (%s) %s: %s", nt$question, QUESTIONS[nt$question], gsub("_", " ", nt$status), nt$caveats), "")

  add("## 15. Leads", "", sprintf("All %d rows, ranked by tier, then by effect size relative to its interval (`05_leads/leads.csv`). No row is hidden.", nrow(leads)), "",
      sprintf("**Tier 1:** a lead (q <= %s) from the default method with its checks passed, its alternatives agreed, stable when any one sample is left out, and no contaminant flag. **Tier 2:** every other lead (the caveats say which condition it missed). **Tier 3:** no evidence, but an effect at least as large as the smallest one the simulation showed this design can detect. **Tier 4:** the rest. Tier 1: %d, tier 2: %d, tier 3: %d.",
              rule("R-FDR"), sum(leads$tier %in% 1L), sum(leads$tier %in% 2L), sum(leads$tier %in% 3L)), "",
      md_table(leads, c("rank", "tier", "status", "question", "layer", "feature", "contrast", "timepoint", "effect", "q", "agreement_label", "flags")), "")
  add("## Provenance", "", "R and package versions: `provenance/session_info.txt`. Engine, rules and seed: `provenance/engine.yaml`. Input checksums: `provenance/inputs.sha256`.")

  dir.create(file.path(out, "report"), showWarnings = FALSE)
  md <- file.path(out, "report", "compendium_report.md")
  writeLines(L, md, useBytes = TRUE)
  html <- FALSE
  if (requireNamespace("rmarkdown", quietly = TRUE) && rmarkdown::pandoc_available()) {
    rmarkdown::render(md, output_format = rmarkdown::html_document(self_contained = TRUE, toc = TRUE, mathjax = NULL), output_file = "compendium_report.html",
                      output_dir = file.path(out, "report"), quiet = TRUE)
    html <- TRUE
  } else message("pandoc is not available here, so only the Markdown report was written (the HTML is rendered in the container).")
  invisible(html)
}
