#!/usr/bin/env Rscript
# ve2_guide.R: V-E2 (guide obedience) and the first four parts of V-E2b
# (validation/PREREGISTRATION.md §5), on the Mac.
#
#   Rscript validation/ve2_guide.R <seq-triage test file> <results dir>
#
# (a) one column's role changed changes the analysis as the new role says;
# (b) an `ignore` column appears in no result, a column missing from the guide stops;
# (c) no guide stops and writes the draft;
# (d) every case of seq-triage's tests/study_metadata test set, rebuilt as a
#     bundle: it stops or runs as in seq-triage, with the same message. Two
#     mechanical substitutions are allowed and shown: seq-triage's flag name
#     `--column_guide` is "the column guide" here, and its real-sample value
#     `sample` is `none` here (CLAUDE.md D6). Cases about seq-triage's
#     samplesheet, its --metadata joining or its own example files are not
#     ported to the engine (R/guide.R) and are listed as not applicable.
args <- commandArgs(trailingOnly = TRUE)
triage_test <- args[1]; rdir <- args[2]
suppressPackageStartupMessages(library(seqcompendium))
dir.create(rdir, recursive = TRUE, showWarnings = FALSE)
tmp <- tempfile("ve2_"); dir.create(tmp)
res <- list(); add <- function(part, case, expected, got, pass, note = "") res[[length(res) + 1]] <<- data.frame(part = part, case = case, expected = expected, got = substr(got, 1, 300), pass = pass, note = note)

# A bundle from a metadata table and a guide (guide NULL: none; "" : an empty file).
counts_for <- function(samples, seed = 1) { set.seed(seed); f <- sprintf("g%02d", 1:20)
  data.frame(sample = rep(samples, each = 20), feature = rep(f, length(samples)), value = stats::rnbinom(20 * length(samples), mu = 40, size = 2)) }
bundle <- function(md, guide, name, crlf = FALSE) {
  d <- file.path(tmp, name); dir.create(file.path(d, "metadata"), recursive = TRUE); dir.create(file.path(d, "layers"))
  md <- md[, setdiff(names(md), c("fastq_1", "fastq_2")), drop = FALSE]
  f <- file.path(d, "metadata/study_metadata.tsv")
  utils::write.table(md, f, sep = "\t", quote = FALSE, row.names = FALSE, na = "")
  if (crlf) writeLines(gsub("\n", "\r\n", paste(readLines(f), collapse = "\n")), f, sep = "\r\n")
  gf <- NULL
  if (identical(guide, "")) { gf <- "metadata/column_guide.csv"; file.create(file.path(d, gf)) }
  else if (!is.null(guide)) { gf <- "metadata/column_guide.csv"; utils::write.csv(guide, file.path(d, gf), row.names = FALSE, na = "") }
  utils::write.table(counts_for(md$sample), file.path(d, "layers/c.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.table(data.frame(feature = sprintf("g%02d", 1:20), label = sprintf("gene %d", 1:20)), file.path(d, "layers/c_features.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  yaml::write_yaml(list(bundle_version = 1L, produced_by = list(pipeline = "validation ve2_guide.R"),
                        metadata = Filter(Negate(is.null), list(table = "metadata/study_metadata.tsv", column_guide = gf)),
                        layers = list(list(name = "c", file = "layers/c.tsv", unit = "count", feature_level = "test gene", features = "layers/c_features.tsv", feature_columns = list(label = "label"), source = list(tool = "ve2", version = "1")))), file.path(d, "manifest.yaml"))
  d
}
run <- function(b) { o <- paste0(b, "_out")
  msg <- tryCatch({ suppressMessages(suppressWarnings(run_compendium(b, o))); NA_character_ }, error = function(e) conditionMessage(e))
  list(stopped = !is.na(msg), msg = msg %||% "", out = o) }
`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

# ---- (d) seq-triage's cases ---------------------------------------------------------------
# Load the case definitions from seq-triage's own test file: everything up to
# its first run(), so the tables (base, guide_ok, ctl, guide_ctl) are theirs.
src <- readLines(triage_test)
env <- new.env()
eval(parse(text = src[grep("^`%\\|\\|%`", src):grep("^              row\\(\"day\"", src)]), envir = env)
eval(parse(text = src[grep("^ctl <- rbind", src):grep("^guide_ctl <- ", src)]), envir = env)
base <- env$base; guide_ok <- env$guide_ok; row <- env$row; G <- env$G
ctl <- env$ctl; ctl$kind[ctl$kind == "sample"] <- "none"                         # D6: the real-sample value
ctl[ctl$kind != "none", c("trt", "temp", "day", "animal", "weight")] <- NA
guide_ctl <- env$guide_ctl
# Design section 2.10 (F8) requires a sample_control column to list in `levels`
# the values it uses; seq-triage does not. The control cases list them, and
# say so (CLAUDE.md D37).
guide_ctl$levels[guide_ctl$column == "kind"] <- "none|negative_extraction|positive_mock"
CTL_NOTE <- "levels listed for `kind` (design 2.10 requires them; seq-triage does not)"
sub_msg <- function(p) gsub("write `sample` for a real sample", "write none for a study sample", gsub("--column_guide", "the column guide", p, fixed = TRUE), fixed = TRUE)
unlev <- within(guide_ok, { type[column == "trt"] <- "categorical"; levels[column == "trt"] <- "" })
stop_case <- function(case, md, guide, pattern) {
  r <- run(bundle(md, guide, case)); p <- sub_msg(pattern)
  add("d", case, sprintf("stops, naming: %s", p), if (r$stopped) r$msg else "ran", r$stopped && grepl(p, r$msg),
      paste(c(if (p != pattern) "message substitution (see header)", if (!identical(guide, "") && "kind" %in% guide$column) CTL_NOTE), collapse = "; "))
}
run_case <- function(case, md, guide, check = function(r) TRUE, crlf = FALSE, what = "runs") {
  r <- run(bundle(md, guide, case, crlf)); ok <- !r$stopped && isTRUE(tryCatch(check(r), error = function(e) FALSE))
  add("d", case, what, if (r$stopped) r$msg else "ran", ok, if ("kind" %in% guide$column) CTL_NOTE else "")
}
na <- function(case, why) add("d", case, "not applicable", "", NA, why)
rd <- function(r, ...) utils::read.csv(file.path(r$out, ...), stringsAsFactors = FALSE)
txt <- function(r, f) paste(readLines(file.path(r$out, f)), collapse = "\n")

run_case("OK_EXIT", base, guide_ok)
run_case("OK_LONGITUDINAL", base, guide_ok, function(r) grepl("change over time", txt(r, "00_input_check/design_reading.txt")), what = "runs; design read as change over time")
run_case("OK_CONTINUOUS_IS_COVARIATE", base, guide_ok, function(r) !any(grepl("weight", rd(r, "01_profile/shape_profile.csv")$property)), what = "runs; weight is an outcome, not a predictor")
run_case("OK_DISCRETE_IS_GROUPS", base, guide_ok, function(r) any(rd(r, "01_profile/shape_profile.csv")$property == "predictor_temp"), what = "runs; temp is a grouping predictor")
run_case("TEMP_DECLARED_CONTINUOUS", base, within(guide_ok, type[column == "temp"] <- "continuous"),
         function(r) { p <- rd(r, "01_profile/shape_profile.csv"); p$value[p$property == "predictor_temp"] == "continuous covariate" }, what = "runs; temp is a continuous covariate")
na("NOGUIDE_EXIT", "seq-triage runs without a guide and only describes; the engine stops (V-E2 part c requires it), checked in part c")
na("NOGUIDE_NO_DESIGN", "as NOGUIDE_EXIT"); na("NOGUIDE_DRAFT_BLANK_CHOICES", "checked in part c"); na("NOGUIDE_DRAFT_SHOWS_VALUES", "checked in part c")
na("STOP_LANES_DISAGREE", "samplesheet lanes: not ported (the engine receives one joined table)")
stop_case("STOP_CASE_TYPO", within(base, trt[1] <- "Control"), unlev, "'control' / 'Control'|'Control' / 'control'")
stop_case("STOP_ONE_KEYSTROKE", within(base, trt[1] <- "contol"), unlev, "one keystroke apart")
na("STOP_NUMBERS_AND_TEXT", "a no-guide check in seq-triage; with a guide the same cell is STOP_UNIT_IN_CELL")
stop_case("STOP_NOT_IN_GUIDE", cbind(base, site = "X"), guide_ok, "`site` is not in --column_guide")
stop_case("STOP_GUIDE_ROW_NOT_IN_DATA", base, rbind(guide_ok, row("weigth", "outcome", "continuous")), "`weigth` is in --column_guide but not in the data")
stop_case("STOP_UNKNOWN_ROLE", base, within(guide_ok, role[column == "trt"] <- "predicter"), "role 'predicter' is not one of")
stop_case("STOP_UNKNOWN_TYPE", base, within(guide_ok, type[column == "trt"] <- "factor"), "type 'factor' is not one of")
stop_case("STOP_OUTSIDE_LEVELS", within(base, trt[3] <- "Drug"), guide_ok, "not among its listed levels: 'Drug'")
stop_case("STOP_UNIT_IN_CELL", within(base, weight[2] <- "19.8g"), guide_ok, "'19.8g' is not a number")
stop_case("STOP_DECIMAL_COMMA", within(base, weight[2] <- "19,8"), guide_ok, "decimal comma")
stop_case("STOP_BINARY_THREE", within(base, trt[3] <- "placebo"), within(guide_ok, levels[column == "trt"] <- ""), "declared binary, but has 3 values")
stop_case("STOP_COUNT_FRACTION", within(base, day[2] <- "0.5"), guide_ok, "declared count, but '0.5'")
stop_case("STOP_ORDINAL_NO_LEVELS", base, within(guide_ok, type[column == "day"] <- "ordinal"), "declared ordinal, so `levels`")
stop_case("STOP_TIME_NOT_ORDERED", base, within(guide_ok, type[column == "day"] <- "categorical"), "a time column must be")
stop_case("STOP_MISSING_CODE_UNDECLARED", within(base, weight[4] <- "99"), within(guide_ok, missing_codes[column == "weight"] <- ""), "contains '99', often a code")
stop_case("STOP_DERIVED_INCONSISTENT", cbind(base, grp = c("C", "D", "C", "D", "C", "D", "C", "C")), rbind(guide_ok, row("grp", "ignore", "categorical", derived = "trt")), "declared derived from `trt`")
stop_case("STOP_NESTED_INCONSISTENT", cbind(base, cage = c("K1", "K1", "K2", "K2", "K1", "K2", "K2", "K2")),
          rbind(guide_ok[guide_ok$column != "animal", ], row("animal", "subject_id", "text", nested = "cage"), row("cage", "block", "categorical")), "declared nested in `cage`")
na("STOP_META_NO_SAMPLE", "--metadata joining: not ported"); na("STOP_META_PIPELINE_NAME", "--metadata joining: not ported")
stop_case("STOP_GUIDE_TYPO_HEADER", base, stats::setNames(guide_ok, sub("levels", "lvels", names(guide_ok))), "column\\(s\\) the guide does not have: `lvels`")
na("STOP_EMPTY_METADATA", "--metadata joining: not ported"); na("HEADER_ONLY_METADATA_NO_CRASH", "--metadata joining: not ported")
stop_case("STOP_EMPTY_GUIDE", base, "", "is empty")
run_case("NO_STOP_NUMBERED_SERIES", transform(base, animal = rep(c("A1", "A2", "A3", "A4"), 2)), guide_ok)
run_case("NO_STOP_SINGLE_CHARACTERS", transform(base, tooth = rep(c("H", "E", "D", "H"), 2)), rbind(guide_ok, row("tooth", "ignore", "categorical")))
run_case("NO_STOP_CONFIRMED_BY_LEVELS", within(base, trt[1] <- "Control"), within(guide_ok, { type[column == "trt"] <- "categorical"; levels[column == "trt"] <- "control|Control|drug" }))
run_case("MISSING_CODE_BECOMES_MISSING", within(base, weight[4] <- "99"), within(guide_ok, missing_codes[column == "weight"] <- "99"),
         function(r) any(grepl("missing-value codes \\('99'\\)|missing-value codes \\(99\\)", rd(r, "00_input_check/bundle_check.csv")$message)), what = "runs; 99 read as missing")
na("META_ID_FROM_GUIDE", "--metadata joining: not ported")
run_case("CRLF_READ", base, guide_ok, crlf = TRUE)
run_case("CONFOUNDED_WARNS_NOT_STOPS", cbind(base, batch = rep(c("B1", "B2"), 4)), rbind(guide_ok, row("batch", "batch", "categorical")),
         function(r) any(grepl("`trt` and `batch` always move together", rd(r, "00_input_check/bundle_check.csv")$message)), what = "runs; warns that trt and batch move together")
na("EXAMPLE_PASSES_NO_WARNING", "seq-triage's own example files"); na("TEMPLATE_HEADER", "seq-triage's own template file")
run_case("CTL_OK_EXIT", ctl, guide_ctl)
run_case("CTL_COUNTED_BY_KIND", ctl, guide_ctl, function(r) { c0 <- rd(r, "00_input_check/controls.csv"); setequal(unique(paste(c0$sample, c0$kind)), c("NEG1 negative_extraction", "MOCK1 positive_mock")) }, what = "runs; controls listed by kind")
run_case("CTL_NOT_IN_GROUPS", ctl, guide_ctl, function(r) { p <- rd(r, "01_profile/shape_profile.csv"); p$value[p$property == "n_study_samples"][1] == "8" }, what = "runs; 8 study samples")
run_case("CTL_NOT_SUBJECTS", ctl, guide_ctl, function(r) { p <- rd(r, "01_profile/shape_profile.csv"); p$value[p$property == "subjects"] == "4" }, what = "runs; 4 subjects")
run_case("CTL_BLANKS_NOT_MISSING", ctl, guide_ctl, function(r) !any(grepl("^Missing for", rd(r, "00_input_check/bundle_check.csv")$message)), what = "runs; control rows' empty cells not reported as missing")
na("CTL_NO_WARNING", "seq-triage's report wording; covered by CTL_BLANKS_NOT_MISSING"); na("CTL_KEPT_IN_OUTPUT", "seq-triage's output table; the engine's controls.csv is CTL_COUNTED_BY_KIND")
stop_case("STOP_CTL_CASE", within(ctl, kind[9] <- "negative_PCR"), guide_ctl, "'negative_PCR'.*'negative_pcr'")
stop_case("STOP_CTL_UNKNOWN", within(ctl, kind[9] <- "blank"), guide_ctl, "not a sample_control value.*'blank'|'blank'.*not a sample_control value")
stop_case("STOP_CTL_EMPTY", within(ctl, kind[3] <- ""), guide_ctl, "`kind`: 1 sample\\(s\\) have no sample_control value")
run_case("CTL_NONE_IS_A_SAMPLE (seq-triage: STOP_CTL_NONE_IS_EMPTY)", ctl, guide_ctl, what = "runs: in the engine `none` is the real-sample value (D6)")
stop_case("STOP_CTL_TWO_COLUMNS", cbind(ctl, kind2 = ctl$kind), rbind(guide_ctl, row("kind2", "sample_control", "categorical")), "role sample_control to more than one column")
stop_case("STOP_CTL_TYPE", ctl, within(guide_ctl, type[column == "kind"] <- "text"), "a sample_control column must be (type )?categorical \\(it is text\\)")
stop_case("STOP_CTL_LEVELS", ctl, within(guide_ctl, levels[column == "kind"] <- "none|blank"), "'blank' is not a sample_control value")
run_case("WARN_NO_CTL_COLUMN", base, guide_ok, function(r) any(grepl("no controls|No column has role sample_control", c(txt(r, "report/compendium_report.md")), ignore.case = TRUE)), what = "runs; warns there are no controls")
run_case("WARN_ALL_REAL", cbind(base, kind = "none"), guide_ctl, function(r) any(grepl("no controls|every sample is a real sample", txt(r, "report/compendium_report.md"), ignore.case = TRUE)), what = "runs; warns there are no controls")
na("FUZZ_300_NO_CRASH", "seq-triage's no-guide reader on random sheets; the engine's own fuzz is in its test suite")

# ---- (c) no guide -----------------------------------------------------------------------
r <- run(bundle(base, NULL, "c_noguide"))
add("c", "no guide", "stops; column_guide_draft.csv written", if (r$stopped) r$msg else "ran", r$stopped && file.exists(file.path(r$out, "00_input_check/column_guide_draft.csv")))

# ---- (b) ignore, and a column absent from the guide --------------------------------------
r <- run(bundle(cbind(base, cage = rep(c("K1", "K2"), 4)), rbind(guide_ok, row("cage", "ignore", "categorical")), "b_ignore"))
f <- list.files(file.path(r$out, c("02_method_choice", "03_results", "05_leads")), recursive = TRUE, full.names = TRUE)
hit <- f[vapply(f, function(x) any(grepl("cage", readLines(x, warn = FALSE))), TRUE)]
add("b", "ignore column (cage) in no model or result", "ran; `cage` in no file of 02_method_choice, 03_results, 05_leads", if (r$stopped) r$msg else paste(basename(hit), collapse = ", "), !r$stopped && !length(hit))
r <- run(bundle(cbind(base, cage = rep(c("K1", "K2"), 4)), guide_ok, "b_absent"))
add("b", "column absent from the guide", "stops, naming `cage`", r$msg, r$stopped && grepl("`cage` is not in the column guide", r$msg))

# ---- (a) one role changed -------------------------------------------------------------------
role_case <- function(case, guide, check, what, md = base) { r <- run(bundle(md, guide, paste0("a_", gsub("[^A-Za-z0-9]", "_", case))))
  add("a", case, what, if (r$stopped) r$msg else "ran", !r$stopped && isTRUE(tryCatch(check(r), error = function(e) FALSE))) }
prof <- function(r, p) { x <- rd(r, "01_profile/shape_profile.csv"); x$value[x$property == p] }
res_any <- function(r, col, val) { f <- list.files(file.path(r$out, "03_results"), pattern = "results.csv$", recursive = TRUE, full.names = TRUE)
  any(vapply(f, function(x) { t <- utils::read.csv(x, stringsAsFactors = FALSE); col %in% names(t) && any(t[[col]] %in% val) }, TRUE)) }
role_case("predictor -> ignore (trt)", within(guide_ok, role[column == "trt"] <- "ignore"), function(r) !res_any(r, "predictor", "trt") && length(prof(r, "predictor_trt")) == 0, "trt is no longer compared")
role_case("ignore -> predictor (a new column)", rbind(guide_ok, row("cage", "predictor", "categorical", "K1|K2")), function(r) res_any(r, "predictor", "cage"), "cage is compared", md = cbind(base, cage = rep(c("K1", "K1", "K2", "K2"), 2)))
role_case("predictor -> block (temp)", within(guide_ok, role[column == "temp"] <- "block"), function(r) prof(r, "blocks") == "temp" && res_any(r, "block", c("26", "30", "temp=26", "temp=30")) && !res_any(r, "predictor", "temp"), "temp becomes a block: estimated within, not compared")
role_case("predictor -> batch (temp)", within(guide_ok, role[column == "temp"] <- "batch"), function(r) prof(r, "batch") == "temp" && !res_any(r, "predictor", "temp"), "temp becomes a batch: adjusted for, not compared")
role_case("time -> ignore (day)", within(guide_ok, role[column == "day"] <- "ignore"), function(r) prof(r, "design_class") == "snapshot-paired" && prof(r, "timepoints") == "no time column", "no longer longitudinal")
role_case("subject_id -> ignore (animal)", within(guide_ok, role[column == "animal"] <- "ignore"), function(r) prof(r, "design_class") == "snapshot-independent", "no subject: snapshot-independent")
role_case("outcome -> ignore (weight)", within(guide_ok, role[column == "weight"] <- "ignore"), function(r) prof(r, "outcomes") == "none", "weight no longer an outcome")
role_case("ignore -> outcome (a new column)", rbind(guide_ok, row("score", "outcome", "continuous")), function(r) grepl("score", prof(r, "outcomes")), "score is an outcome", md = cbind(base, score = seq(1, 8)))
role_case("ignore -> sample_control (kind)", guide_ctl, function(r) nrow(rd(r, "00_input_check/controls.csv")) == 2, "NEG1 and MOCK1 become controls", md = ctl)

out <- do.call(rbind, res)
utils::write.csv(out, file.path(rdir, "ve2_cases.csv"), row.names = FALSE)
marks <- do.call(rbind, lapply(c("a", "b", "c", "d"), function(p) { x <- out[out$part == p & !is.na(out$pass), ]
  data.frame(mark = "V-E2", scenario = sprintf("part %s (%d cases%s)", p, nrow(x), if (p == "d") sprintf("; %d not applicable", sum(out$part == "d" & is.na(out$pass))) else ""),
             number = mean(x$pass), threshold = "= 1", pass = all(x$pass), runs = nrow(x)) }))
utils::write.csv(marks, file.path(rdir, "ve2_marks.csv"), row.names = FALSE)
print(out[!out$pass %in% TRUE, c("part", "case", "expected", "got")], right = FALSE)
print(marks, right = FALSE)
