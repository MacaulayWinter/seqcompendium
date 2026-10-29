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
  if (nrow(ctx$controls)) add(md_table(ctx$controls), "", "Contaminant check (Q0) and mock recovery are built at milestones E3 and E4.", "")
  else add("No control samples.", "")

  add("## 3. Design as read", "", "Read only from your column guide; nothing about a column was guessed.", "", design_text(des, ctx$info), "")

  add("## 4. Shape profile", "", "Every later choice points back to these rows (`01_profile/shape_profile.csv`).", "", md_table(ctx$profile), "")

  add("## 5. Q1. What is there?", "", "Description only, no test. Prevalence and median per feature, group, timepoint and block: `03_results/Q1_describe/results.csv`. The ten most prevalent features overall:", "")
  q1 <- ctx$q1; top <- stats::aggregate(prevalence ~ layer + feature, q1, mean); top <- top[order(-top$prevalence, top$feature), ]
  add(md_table(top, max_rows = 10), "")

  add("## 6. Q2. Does within-sample diversity differ?", "")
  r <- q2$results
  if (is.null(r)) add("Q2 could not be asked: see the leads table for the reason.", "")
  else for (nm in unique(r$layer)) for (p in unique(r$predictor[r$layer == nm])) {
    x <- r[r$layer == nm & r$predictor == p, , drop = FALSE]
    cov <- unique(signif(q2$per_sample$coverage[q2$per_sample$layer == nm], 3))
    prof <- ctx$profile[ctx$profile$layer == nm, ]
    pv <- function(k) prof$value[prof$property == k]
    add(sprintf("### Layer `%s`, by `%s`", nm, p), "",
        sprintf("**What was asked.** Does the number and evenness of features (alpha diversity, Hill numbers q = 0, 1, 2) differ between the levels of `%s`, against the reference level `%s`, at each timepoint and block separately? Timepoints are never pooled.", p, des$levels_of(p)[1]), "",
        sprintf("**Why this method.** Hill numbers at equal sample coverage (iNEXT, catalogue A02), compared with Welch t-tests (K01). Chosen because the data are counts (shape %s), library size varies %s-fold between study samples, and within each timepoint every subject is sampled once (design class: %s). Standardising to equal coverage (here %s) avoids comparing deeply and shallowly sequenced samples unfairly; Welch's test does not assume equal spread. q-values: Benjamini-Hochberg within each contrast, timepoint and block, over the three orders.",
                pv("shape"), pv("library_size_max_over_min"), des$class, paste(cov, collapse = ", ")), "",
        "**What the checks showed.** Residual skewness and the ratio of group spreads are recorded in `03_results/Q2_alpha/diagnostics.csv`. In this milestone they are recorded only: the fallback ladder (rank-based tests) is built at milestone E3.", "",
        sprintf("**Limitations.** Welch tests on a handful of samples per group have little power: a difference can be real and still not reach q <= %s. Each predictor is compared on its own%s. Hill numbers count features, so features that are really one organism or gene split by the reference database inflate q = 0.%s",
                rule("R-FDR"), if (length(des$batch)) sprintf(", and batch %s is not adjusted for yet", q(des$batch)) else "",
                if (!nrow(des$controls)) " There are no controls, so contaminant features may be counted as diversity." else ""), "",
        "**Did the alternatives agree.** Not testable yet: the agreement set for Q2 (plug-in Shannon on rarefied counts; DivNet) is built at milestone E3.", "",
        md_table(x, c("contrast", "timepoint", "block", "q_order", "n_reference", "n_level", "mean_reference", "mean_level", "effect", "ci_low", "ci_high", "p", "q", "status")), "")
  }
  idx <- ctx$figures
  if (nrow(idx)) {
    add("Figures (each drawn only from the CSV it names):", "")
    for (i in seq_len(nrow(idx))) {
      png <- sub("\\.pdf$", ".png", idx$figure[i])
      add(if (file.exists(file.path(out, png))) sprintf("![%s](../%s)", idx$caption[i], png) else NULL,
          sprintf("- [%s](../%s): %s", idx$figure[i], idx$figure[i], idx$caption[i]), "")
    }
  }

  add("## 7. What was not found", "", "Placed before the leads on purpose: negative results are results.", "")
  ne <- leads[leads$status == "no_evidence", , drop = FALSE]
  if (nrow(ne)) add(sprintf("- %s, %s, %s, %s, timepoint %s, block %s: difference %s (95%% CI %s to %s), q = %s. No evidence of a difference at this sample size.",
                            ne$question, ne$layer, ne$feature, ne$contrast, ne$timepoint, ne$block, signif(ne$effect, 3), signif(ne$ci_low, 3), signif(ne$ci_high, 3), signif(ne$q, 3)), "")
  else add("- Every tested comparison reached the lead threshold.", "")
  nt <- leads[leads$status %in% c("not_testable", "not_asked"), , drop = FALSE]
  add("Questions not asked, or not testable, and why:", "", sprintf("- %s (%s) %s: %s", nt$question, QUESTIONS[nt$question], gsub("_", " ", nt$status), nt$caveats), "")

  add("## 8. Leads", "", sprintf("All %d rows, ranked by tier, then by effect size relative to its interval (`05_leads/leads.csv`). No row is hidden.", nrow(leads)), "",
      md_table(leads, c("rank", "tier", "status", "question", "layer", "feature", "contrast", "timepoint", "effect", "q", "flags")), "")
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
