# catalogue.R: the methods catalogue and its filter (design section 3.2).
#
# The catalogue is the literature scan's methods_catalogue.csv (115 rows) with
# columns a computer can read added (inst/catalogue/README.md). The filter
# only removes methods, by hard requirements in a fixed order; it never picks
# one. Picking is the default table (design section 5.2), in choose_methods().

BUILT <- c("E1", "E2", "E3")   # milestones whose methods this engine version runs

catalogue <- function() utils::read.csv(system.file("catalogue", "methods.csv", package = "seqcompendium"), colClasses = "character",
                                        check.names = FALSE, na.strings = character(0))

# One row per catalogue row for one layer: eligible or not, and the first
# requirement it failed.
filter_catalogue <- function(layer_name, layer, des) {
  cat <- catalogue()
  unit <- layer$spec$unit
  has <- c(tree = !is.null(layer$spec$tree), denominator = !is.null(layer$spec$denominators), paired_layer = !is.null(layer$spec$paired_with),
           subject_id = !is.na(des$subject) && des$class == "longitudinal", negative_controls = any(grepl("^negative_", des$controls$kind)),
           set_column = any(unlist(layer$spec$feature_columns) == "set"), outcome = length(des$outcome) > 0,
           two_layers = FALSE, pairs = FALSE, external_result = FALSE)
  smallest <- smallest_group(des)
  out <- lapply(seq_len(nrow(cat)), function(i) {
    r <- cat[i, ]
    why <- if (r$role == "excluded") r$engine_note
      else if (!(r$needs_unit %in% c("any", "") || unit %in% strsplit(r$needs_unit, "|", fixed = TRUE)[[1]]))
        sprintf("needs unit %s; this layer is %s", gsub("\\|", " or ", r$needs_unit), unit)
      else if (nzchar(r$needs) && !isTRUE(has[[r$needs]])) sprintf("needs %s; this bundle has none", gsub("_", " ", r$needs))
      else if (des$class == "longitudinal" && r$handles_repeated == "no" && r$question %in% c("Q6"))
        "does not handle repeated measures"
      else if (nzchar(r$min_group) && !is.na(smallest) && smallest < as.integer(r$min_group))
        sprintf("smallest group is %d, below %s (rule R-MINGRP)", smallest, r$min_group)
      else if (!r$milestone %in% BUILT) sprintf("eligible, but not built yet (milestone %s)", r$milestone)
      else NA_character_
    data.frame(layer = layer_name, id = r$id, method = r$method, role = r$role, question = r$question,
               eligible = if (is.na(why)) "yes" else "no", reason = why %||% "")
  })
  do.call(rbind, out)
}

smallest_group <- function(des) {
  if (!length(des$grouping)) return(NA_integer_)
  cells <- design_cells(des)
  st <- des$study
  min(vapply(des$grouping, function(p) { tb <- table(st[[p]], paste(cells$timepoint, cells$block)); min(tb[tb > 0]) }, 1L))
}

# The default for each question and layer (design section 5.2, S1 snapshot),
# with the profile facts it rests on. A default that the filter made
# ineligible is never used: the question becomes not_testable, with the reason.
choose_methods <- function(layer_name, layer, considered) {
  ok <- function(id) considered$eligible[considered$id == id] == "yes"
  denom <- !is.null(layer$spec$denominators)
  q4 <- if (denom) "D01" else "D09"
  rows <- list(
    c("Q0", "N11", "decontam prevalence method", "negative controls declared (F8)"),
    c("Q2", "A02", "Hill numbers at equal coverage, Welch test (K01)", sprintf("unit %s", layer$spec$unit)),
    c("Q3", "B06", "PERMANOVA on robust Aitchison distance (B03), with betadisper (B07)", sprintf("unit %s", layer$spec$unit)),
    c("Q4", q4, if (denom) "DESeq2 with the denominator as offset" else "LinDA",
      if (denom) sprintf("the layer has a denominator (%s)", paste(names(layer$spec$denominators$columns), collapse = ", ")) else "the layer has no denominator"),
    c("Q5", "R01", "logistic regression per feature; Firth (G06) where separation occurs", sprintf("unit %s", layer$spec$unit)),
    c("Q7", "E02", "pre-ranked fgsea on the Q4 statistic", "the manifest declares a set column"))
  do.call(rbind, lapply(rows, function(r) data.frame(layer = layer_name, question = r[1], default_id = r[2], default_method = r[3],
                                                      rests_on = r[4], default_eligible = if (ok(r[2])) "yes" else "no",
                                                      override = "not run (the override rule is built at milestone E4)",
                                                      final_id = if (ok(r[2])) r[2] else NA_character_,
                                                      rule = "design section 5.2, S1 snapshot table")))
}

agreement_ids <- function(question, layer) {
  denom <- !is.null(layer$spec$denominators)
  switch(question,
         Q2 = c("A01", "A04"),
         Q3 = c("B01", "B14"),
         Q4 = if (denom) c("D09", "D04", "D17") else c("D06", "D04", "D17"),
         Q5 = "K03",
         Q7 = "E03",
         character(0))
}
