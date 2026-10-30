# Helpers: invented bundles and the edits that break them (CLAUDE.md D5).

toy <- function(variant = "main") { d <- tempfile("bundle"); make_toy_bundle(d, variant); d }
out_dir <- function() tempfile("out")
rd <- function(f) utils::read.table(f, sep = if (grepl("\\.csv$", f)) "," else "\t", header = TRUE, colClasses = "character",
                                    na.strings = character(0), quote = "\"", check.names = FALSE, comment.char = "")
wr <- function(x, f) if (grepl("\\.csv$", f)) utils::write.csv(x, f, row.names = FALSE, na = "") else
  utils::write.table(x, f, sep = "\t", quote = FALSE, row.names = FALSE, na = "")
edit <- function(bundle, file, fn) { f <- file.path(bundle, file); wr(fn(rd(f)), f); bundle }
META <- "metadata/study_metadata.tsv"; GUIDE <- "metadata/column_guide.csv"; LAYER <- "layers/toy_counts.tsv"
guide_row <- function(column, role, type, levels = "", missing_codes = "")
  data.frame(column = column, role = role, type = type, levels = levels, missing_codes = missing_codes, description = "")
add_column <- function(b, name, values, role, type, levels = "", missing_codes = "") {
  edit(b, META, function(x) { x[[name]] <- rep_len(values, nrow(x)); x })
  edit(b, GUIDE, function(g) { for (c in setdiff(names(guide_row("", "", "")), names(g))) g[[c]] <- ""; rbind(g[, names(guide_row("", "", ""))], guide_row(name, role, type, levels, missing_codes)) })
}

# E1-M2: each case breaks a main toy bundle one way; `pattern` is what the
# stop message must say.
STOP_CASES <- list(
  no_guide = list(pattern = "No column guide", edit = function(b) {
    m <- yaml::read_yaml(file.path(b, "manifest.yaml")); m$metadata$column_guide <- NULL; yaml::write_yaml(m, file.path(b, "manifest.yaml")); b }),
  column_not_in_guide = list(pattern = "`site` is not in the column guide", edit = function(b) edit(b, META, function(x) { x$site <- "north"; x })),
  guide_row_not_in_data = list(pattern = "`weight` is in the column guide but not in the data", edit = function(b)
    edit(b, GUIDE, function(g) rbind(g, data.frame(column = "weight", role = "outcome", type = "continuous", levels = "", description = "")))),
  unknown_role = list(pattern = "role 'predicter' is not one of", edit = function(b) edit(b, GUIDE, function(g) { g$role[g$column == "group"] <- "predicter"; g })),
  unknown_type = list(pattern = "type 'categorial' is not one of", edit = function(b) edit(b, GUIDE, function(g) { g$type[g$column == "group"] <- "categorial"; g })),
  value_outside_levels = list(pattern = "not among its listed levels: 'treatd'", edit = function(b) edit(b, META, function(x) { x$group[x$group == "treated"][1] <- "treatd"; x })),
  contradicts_type = list(pattern = "'19.8g' is not a number", edit = function(b) add_column(b, "weight", c("20.1", "19.8g", "21.0"), "outcome", "continuous", missing_codes = "none")),
  one_keystroke_typo = list(pattern = "one keystroke apart", edit = function(b) add_column(b, "diet", c("low_fat", "high_fat", "low_fit"), "predictor", "categorical")),
  conventional_code = list(pattern = "contains '99', often a code", edit = function(b) add_column(b, "weight", c("20.1", "99", "21.0"), "outcome", "continuous")),
  control_unknown_value = list(pattern = "value 'blank' is not a sample_control value", edit = function(b) edit(b, META, function(x) { x$kind[x$sample == "BLANK1"] <- "blank"; x })),
  control_typo = list(pattern = "looks like a typo of 'negative_extraction'", edit = function(b) edit(b, META, function(x) { x$kind[x$sample == "BLANK1"] <- "negative_extration"; x })),
  control_level_outside_list = list(pattern = "level 'blank_water' is not a sample_control value", edit = function(b)
    edit(b, GUIDE, function(g) { g$levels[g$column == "kind"] <- "none|negative_extraction|positive_mock|blank_water"; g })),
  count_not_whole = list(pattern = "not a whole number 0 or more", edit = function(b) edit(b, LAYER, function(x) { x$value[5] <- "12.5"; x })),
  missing_row = list(pattern = "row\\(s\\) are missing", edit = function(b) edit(b, LAYER, function(x) x[-7, ])),
  layer_sample_not_in_metadata = list(pattern = "has sample\\(s\\) not in the metadata: S01_T9", edit = function(b) edit(b, LAYER, function(x) { x$sample[x$sample == "S01_T0"] <- "S01_T9"; x })),
  manifest_missing_file = list(pattern = "that file is not in the bundle", edit = function(b) {
    m <- yaml::read_yaml(file.path(b, "manifest.yaml")); m$layers[[1]]$features <- "layers/nope.tsv"; yaml::write_yaml(m, file.path(b, "manifest.yaml")); b })
)

# Runs one stop case; TRUE when the run stopped with the expected message.
stops_as_expected <- function(case) {
  b <- case$edit(toy())
  e <- tryCatch({ run_compendium(b, out_dir()); NULL }, seqcompendium_stop = function(e) e)
  !is.null(e) && grepl(case$pattern, conditionMessage(e))
}

# Each fixture is run once per test session and shared (a run takes ~40 s).
.runs <- new.env()
run_fixture <- function(variant) {
  if (is.null(.runs[[variant]])) { b <- toy(variant); o <- out_dir(); l <- run_compendium(b, o); .runs[[variant]] <- list(b = b, o = o, l = l) }
  .runs[[variant]]
}
res_csv <- function(x, f) utils::read.csv(file.path(x$o, f), stringsAsFactors = FALSE)

# The override rule's simulation uses R-SIMREP (100) data sets; tests use 6
# so a run takes seconds, not hours (CLAUDE.md D20). Production is unchanged.
options(seqcompendium.simrep = 6)

# The mixed models' chance rate uses R-CHANCEREP (20) simulated data sets;
# tests use 3 (CLAUDE.md D26). Production is unchanged.
options(seqcompendium.chancerep = 3)
