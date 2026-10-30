# run.R: run_compendium(), the one entry point a domain pipeline calls.

#' Run the compendium engine on a bundle
#'
#' @param bundle the bundle folder (design §2).
#' @param out the output folder (the compendium, design §9). It must not exist,
#'   or be empty, unless `overwrite = TRUE`, which replaces only a folder this
#'   engine wrote before.
#' @param overwrite replace an earlier compendium in `out`.
#' @return the leads table, invisibly. Stops with a classed condition
#'   (`seqcompendium_stop`) naming every problem the user must fix.
#' @export
run_compendium <- function(bundle, out, overwrite = FALSE) {
  if (dir.exists(out) && length(list.files(out, all.files = TRUE, no.. = TRUE))) {
    if (!overwrite) stop_engine(sprintf("The output folder %s already has files in it. Choose a new folder, or use overwrite = TRUE to replace an earlier compendium.", out))
    if (!file.exists(file.path(out, "provenance", "engine.yaml"))) stop_engine(sprintf("The output folder %s has files but was not written by seqcompendium, so it is not replaced.", out))
    unlink(out, recursive = TRUE)
  }
  dir.create(file.path(out, "00_input_check"), recursive = TRUE, showWarnings = FALSE)
  b <- read_bundle(bundle)

  if (is.null(b$guide)) {
    write_csv(guide_draft(b$md), file.path(out, "00_input_check", "column_guide_draft.csv"))
    write_csv(data.frame(check = "column guide", status = "stop", message = "No column guide: nothing is analysed without one (D95)."), file.path(out, "00_input_check", "bundle_check.csv"))
    stop_engine(sprintf("No column guide, so nothing can be analysed: roles and types come only from the guide. A draft with what the data show is in %s; fill in role and type, and name it in the manifest (metadata: column_guide).",
                        file.path(out, "00_input_check", "column_guide_draft.csv")))
  }
  gc <- check_guide(b$md, b$guide)
  lc <- check_layers(b$layers, gc$md)
  check <- rbind(data.frame(check = "files named in the manifest", status = "passed", message = "all present"),
                 if (nrow(gc$findings)) data.frame(check = paste("metadata", gc$findings$column), status = gc$findings$status, message = gc$findings$message),
                 lc$notes,
                 if (length(gc$stops)) data.frame(check = "column guide", status = "stop", message = gc$stops),
                 if (length(lc$stops)) data.frame(check = "layers", status = "stop", message = lc$stops))
  write_csv(check, file.path(out, "00_input_check", "bundle_check.csv"))
  write_csv(b$guide, file.path(out, "00_input_check", "column_guide_used.csv"))
  stops <- c(gc$stops, lc$stops)
  if (length(stops)) stop_engine(sprintf("%d problem(s) to fix before the run can continue. Nothing has been assumed.\n  - %s\nAll checks are in %s.",
                                         length(stops), paste(stops, collapse = "\n  - "), file.path(out, "00_input_check", "bundle_check.csv")))

  des <- read_design(gc$md, b$guide, gc$info)
  cells <- design_cells(des)
  writeLines(design_text(des, gc$info), file.path(out, "00_input_check", "design_reading.txt"))
  controls <- controls_table(lc$layers, des)
  write_csv(controls, file.path(out, "00_input_check", "controls.csv"))

  profile <- shape_profile(lc$layers, des, cells)
  write_csv(profile, file.path(out, "01_profile", "shape_profile.csv"))

  q1 <- q1_describe(lc$layers, des, cells)
  write_csv(q1, file.path(out, "03_results", "Q1_describe", "results.csv"))

  q2 <- q2_alpha(lc$layers, des, cells)
  qdir <- file.path(out, "03_results", "Q2_alpha")
  dir.create(qdir, recursive = TRUE, showWarnings = FALSE)
  if (!is.null(q2$per_sample)) write_csv(q2$per_sample[order(q2$per_sample$layer, q2$per_sample$sample, q2$per_sample$q_order), ], file.path(qdir, "per_sample.csv"))
  if (!is.null(q2$results)) write_csv(q2$results, file.path(qdir, "results.csv"))
  if (!is.null(q2$diagnostics)) write_csv(q2$diagnostics, file.path(qdir, "diagnostics.csv"))
  write_csv(data.frame(question = "Q2", method = "iNEXT::estimateD(base = 'coverage', q = 0:2, nboot = 0), then stats::t.test(var.equal = FALSE)",
                       package = c("iNEXT", "stats"), version = c(as.character(utils::packageVersion("iNEXT")), as.character(getRversion())),
                       seed = "none needed (no random step)"), file.path(qdir, "model_info.csv"))

  # Method choice: the catalogue filter and the defaults (design 3.2, 5.2).
  considered <- do.call(rbind, lapply(names(lc$layers), function(nm) filter_catalogue(nm, lc$layers[[nm]], des)))
  choices <- do.call(rbind, lapply(names(lc$layers), function(nm) choose_methods(nm, lc$layers[[nm]], considered[considered$layer == nm, ])))
  write_csv(considered, file.path(out, "02_method_choice", "methods_considered.csv"))
  write_csv(choices, file.path(out, "02_method_choice", "choices.csv"))

  units <- contrast_units(lc$layers, des, cells)
  # Longitudinal designs (E5): mixed models for Q2 and Q4, and Q6.
  des$long_reason <- long_ready(des)
  lus <- if (is.null(des$long_reason)) long_units(lc$layers, des, cells) else list()
  if (is.null(des$long_reason) && !length(lus)) des$long_reason <- "no predictor with listed levels has two or more timepoints to compare"
  long <- length(lus) > 0
  if (long) {
    # The longitudinal defaults of design section 5.2 (S1 longitudinal table).
    i2 <- choices$question == "Q2"; i4 <- choices$question == "Q4"
    choices$default_id[i2] <- "L01"; choices$final_id[i2] <- "L01"; choices$default_method[i2] <- "linear mixed model on the Hill numbers (subject random effect)"
    choices$rests_on[i2] <- "the same subjects were sampled at several timepoints"
    for (k in which(i4)) {
      den <- !is.null(lc$layers[[choices$layer[k]]]$spec$denominators)
      choices$default_id[k] <- choices$final_id[k] <- if (den) "L02" else "D09re"
      choices$default_method[k] <- if (den) "negative binomial mixed model, denominator as offset (glmmTMB)" else "LinDA with a subject random effect"
      choices$rests_on[k] <- sprintf("the same subjects were sampled at several timepoints; %s", if (den) "the layer has a denominator" else "the layer has no denominator")
    }
    choices <- rbind(choices, data.frame(layer = unique(choices$layer), question = "Q6", default_id = "L01/L02", default_method = "time contrasts within each group from the Q2 and Q4 mixed models; PERMANOVA with permutations within subject",
                                         rests_on = "the same subjects were sampled at several timepoints", default_eligible = "yes", override = "not applicable", final_id = "L01/L02", rule = "design section 5.2, S1 longitudinal table"))
    write_csv(choices, file.path(out, "02_method_choice", "choices.csv"))
  }
  q0 <- q0_contaminants(lc$layers, des)
  if (!is.null(q0)) write_csv(q0, file.path(out, "03_results", "Q0_contaminants", "results.csv"))
  a2 <- q2_agreement(units, lc$layers, des)
  if (long) {
    q2l <- q2_long(lus, q2$per_sample, des)
    if (!is.null(q2l$results)) q2$results <- q2l$results
    q2$diagnostics <- q2l$diagnostics
  }
  if (!is.null(q2$results)) q2$results <- agreement_labels(q2$results, a2, c("layer", "predictor", "contrast", "timepoint", "block", "q_order"))
  if (!is.null(q2$diagnostics)) write_csv(q2$diagnostics, file.path(qdir, "diagnostics.csv"))
  if (!is.null(q2$results)) write_csv(q2$results, file.path(qdir, "results.csv"))
  q3 <- q3_composition(units, lc$layers, des)
  if (!is.null(q3$results)) q3$results <- agreement_labels(q3$results, q3$agreement[q3$agreement$role == "agreement", ],
                                                           c("layer", "predictor", "contrast", "timepoint", "block"), directional = FALSE)
  # The override rule (design 5.3): checks each Q4 default on simulated data
  # from the reference samples, and switches only if it fails (C13).
  ov <- if (!long) run_override(units, lc$layers, choices, considered, des, bundle) else long_override_note(units, lc$layers, choices, des, bundle, considered)
  w0 <- function(x, ...) if (!is.null(x)) write_csv(x, file.path(out, ...))
  w0(ov$decisions, "02_method_choice", "override.csv"); w0(ov$calibration, "02_method_choice", "simulation", "calibration.csv")
  w0(ov$per_rep, "02_method_choice", "simulation", "per_dataset.csv")
  w0(ov$mock$recovery, "00_input_check", "mock_recovery.csv"); w0(ov$mock$test, "02_method_choice", "simulation", "mock_test.csv")
  if (!is.null(ov$decisions)) {
    ch4 <- choices$question == "Q4"
    choices$override[ch4] <- vapply(choices$layer[ch4], function(nm) {
      d <- ov$decisions[ov$decisions$layer == nm, ]
      paste(unique(sprintf("%s: %s", paste(d$contrast, d$timepoint, d$block), ifelse(d$decision == "switched", sprintf("switched to %s", d$final_id), d$decision))), collapse = "; ")
    }, "")
    write_csv(choices, file.path(out, "02_method_choice", "choices.csv"))
  }
  if (long) {
    q4 <- q4_long(lus, lc$layers, des, choices)
    # Q7 per timepoint, ranked by the mixed model's per-timepoint z-scores.
    q4$for_q7 <- Filter(Negate(is.null), lapply(units, function(u) {
      if (!u$testable || is.null(q4$results)) return(NULL)
      r <- q4$results[q4$results$layer == u$layer & q4$results$predictor == u$predictor & q4$results$contrast == u$contrast &
                      q4$results$timepoint == u$timepoint & q4$results$block == u$block, ]
      if (!nrow(r)) return(NULL)
      z <- sign(r$effect) * stats::qnorm(pmax(r$p, 1e-300) / 2, lower.tail = FALSE)
      list(unit = u, stat = stats::setNames(z, r$feature)[is.finite(z)], ud = unit_data(u, lc$layers[[u$layer]], des), feats = r$feature)
    }))
  } else q4 <- q4_abundance(units, lc$layers, choices, ov$decisions, des)
  if (!is.null(q4$results)) q4$results <- agreement_labels(q4$results, q4$agreement, c("layer", "predictor", "contrast", "timepoint", "block", "feature"))
  q5 <- q5_presence(units, lc$layers, des)
  if (!is.null(q5$results)) q5$results <- agreement_labels(q5$results, q5$agreement, c("layer", "predictor", "contrast", "timepoint", "block", "feature"))
  q7 <- q7_sets(q4$for_q7, lc$layers)
  if (!is.null(q7$results)) q7$results <- agreement_labels(q7$results, q7$agreement, c("layer", "predictor", "contrast", "timepoint", "block", "set_column", "feature"))
  w <- function(x, ...) if (!is.null(x)) write_csv(x, file.path(out, ...))
  w(q3$results, "03_results", "Q3_composition", "results.csv"); w(q3$ordination, "03_results", "Q3_composition", "ordination.csv")
  w(q4$results, "03_results", "Q4_differential", "results.csv"); w(q4$checks, "03_results", "Q4_differential", "diagnostics.csv")
  w(q5$results, "03_results", "Q5_presence", "results.csv"); w(q7$results, "03_results", "Q7_sets", "results.csv")
  w(a2, "04_agreement", "Q2.csv"); w(q3$agreement, "04_agreement", "Q3.csv"); w(q4$agreement, "04_agreement", "Q4.csv")
  w(q4$describe, "04_agreement", "Q4_describe_only.csv"); w(q5$agreement, "04_agreement", "Q5.csv"); w(q7$agreement, "04_agreement", "Q7.csv")

  q6 <- NULL
  if (long) {
    q6 <- list(alpha = q2l$change, features = q4$change, composition = q6_composition(lus, lc$layers))
    a6a <- change_agreement_alpha(lus, q2$per_sample); a6f <- change_agreement_features(lus, lc$layers)
    if (!is.null(q6$alpha)) q6$alpha <- agreement_labels(q6$alpha, a6a, c("layer", "predictor", "group", "change", "block", "q_order"))
    if (!is.null(q6$features)) q6$features <- agreement_labels(q6$features, a6f, c("layer", "predictor", "group", "change", "block", "feature"))
    w(q6$alpha, "03_results", "Q6_change", "alpha.csv"); w(q6$features, "03_results", "Q6_change", "features.csv")
    w(q6$composition, "03_results", "Q6_change", "composition.csv"); w(a6a, "04_agreement", "Q6_alpha.csv"); w(a6f, "04_agreement", "Q6_features.csv")
  }
  res <- list(q0 = q0, q2 = q2, q3 = q3, q4 = q4, q5 = q5, q7 = q7, q6 = q6, override = ov, long = long)
  leads <- build_leads(res, lc$layers, des)
  write_csv(leads, file.path(out, "05_leads", "leads.csv"))

  figures <- draw_figures(out)
  write_provenance(out, b)
  write_readme(out)
  write_report(out, list(des = des, leads = leads, q2 = q2, q1 = q1, res = res, choices = choices, considered = considered, profile = profile, controls = controls, check = check,
                         info = gc$info, figures = figures, bundle_path = normalizePath(bundle)))
  invisible(leads)
}

write_provenance <- function(out, b) {
  p <- file.path(out, "provenance"); dir.create(p, showWarnings = FALSE)
  pk <- c("seqcompendium", "iNEXT", "ggplot2", "yaml", "digest", "rmarkdown")
  v <- vapply(pk, function(x) tryCatch(as.character(utils::packageVersion(x)), error = function(e) "not installed"), "")
  writeLines(c(sprintf("%s %s", pk, v), "", utils::capture.output(print(utils::sessionInfo()))), file.path(p, "session_info.txt"))
  yaml::write_yaml(list(engine = "seqcompendium", engine_version = ENGINE_VERSION(), milestone = "E1", rules_version = rules()$rules_version,
                        r_version = as.character(getRversion()), seeds = "none used", run_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
                   file.path(p, "engine.yaml"))
  f <- file.path(b$path, b$inputs)
  writeLines(sprintf("%s  %s", vapply(f, function(x) digest::digest(file = x, algo = "sha256"), ""), b$inputs), file.path(p, "inputs.sha256"))
}

write_readme <- function(out) {
  writeLines(c("This folder is a compendium written by seqcompendium.",
               "",
               "report/          the report: start here (compendium_report.html, or .md)",
               "00_input_check/  every check on the input, the column guide as read, the design in words, every control sample",
               "01_profile/      the shape profile: the facts every later choice points back to",
               "03_results/      one folder per question: results, diagnostics, model details",
               "05_leads/        leads.csv: every question asked, ranked; negative and untestable results included",
               "figures/         figures drawn only from the CSVs; figures_index.csv names each one's source",
               "provenance/      versions, rules, input checksums",
               "",
               "02_method_choice/ every catalogue method, eligible or not and why; the method chosen per question",
               "04_agreement/    the alternative and describe-only methods' results, per feature"), file.path(out, "README.txt"))
}
