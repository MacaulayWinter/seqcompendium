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

  leads <- build_leads(q2, lc$layers, des)
  write_csv(leads, file.path(out, "05_leads", "leads.csv"))

  figures <- draw_figures(out)
  write_provenance(out, b)
  write_readme(out)
  write_report(out, list(des = des, leads = leads, q2 = q2, q1 = q1, profile = profile, controls = controls, check = check,
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
  writeLines(c("This folder is a compendium written by seqcompendium (milestone E1).",
               "",
               "report/          the report: start here (compendium_report.html, or .md)",
               "00_input_check/  every check on the input, the column guide as read, the design in words, every control sample",
               "01_profile/      the shape profile: the facts every later choice points back to",
               "03_results/      one folder per question: results, diagnostics, model details",
               "05_leads/        leads.csv: every question asked, ranked; negative and untestable results included",
               "figures/         figures drawn only from the CSVs; figures_index.csv names each one's source",
               "provenance/      versions, rules, input checksums",
               "",
               "02_method_choice/ and 04_agreement/ arrive at milestone E3."), file.path(out, "README.txt"))
}
