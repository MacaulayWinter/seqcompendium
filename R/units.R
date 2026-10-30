# units.R: the comparisons every per-contrast question makes.
#
# A unit is one layer x grouping predictor x timepoint x block x level, with
# that level and the reference level only. Time and blocks are never pooled
# (X0124). A unit that cannot be tested says why.

contrast_units <- function(layers, des, cells) {
  st <- des$study; out <- list()
  for (nm in names(layers)) for (p in des$grouping) {
    lv <- des$levels_of(p)
    if (!length(lv)) {
      out[[length(out) + 1]] <- list(layer = nm, predictor = p, contrast = NA, timepoint = "all", block = "all",
                                     testable = FALSE, reason = sprintf("`%s` has no levels listed in the column guide, so no reference level is declared", p))
      next
    }
    ce <- merge(cells, st[, c("sample", p, if (!is.na(des$subject)) des$subject), drop = FALSE], by = "sample")
    for (cell in unique(paste(ce$timepoint, ce$block, sep = "\r"))) {
      tb <- strsplit(cell, "\r", fixed = TRUE)[[1]]
      d <- ce[ce$timepoint == tb[1] & ce$block == tb[2] & !is.na(ce[[p]]), , drop = FALSE]
      ref <- lv[1]
      for (lvl in setdiff(intersect(lv, unique(d[[p]])), ref)) {
        a <- sort(d$sample[d[[p]] == ref]); b <- sort(d$sample[d[[p]] == lvl])
        subj <- if (!is.na(des$subject)) d[[des$subject]][d$sample %in% c(a, b)] else character(0)
        reason <- if (any(duplicated(stats::na.omit(subj)))) "a subject has more than one sample in this timepoint and block; the paired model is built at milestone E5"
          else if (min(length(a), length(b)) < rule("R-MINGRP")) sprintf("a group has fewer than %d samples (rule R-MINGRP)", rule("R-MINGRP"))
          else NA_character_
        out[[length(out) + 1]] <- list(layer = nm, predictor = p, contrast = sprintf("%s vs %s", lvl, ref), timepoint = tb[1], block = tb[2],
                                       reference = ref, level = lvl, ref_samples = a, level_samples = b,
                                       testable = is.na(reason), reason = reason)
      }
    }
  }
  out
}

# The unit's counts (samples x features, reference samples first), its group
# factor (reference first) and its denominator (or library size if none).
unit_data <- function(u, layer, des = NULL) {
  s <- c(u$ref_samples, u$level_samples)
  m <- wide(layer, s)[s, , drop = FALSE]
  g <- factor(rep(c(u$reference, u$level), c(length(u$ref_samples), length(u$level_samples))), levels = c(u$reference, u$level))
  # Covariates for this comparison (CLAUDE.md D24); none when des is not given.
  adj <- if (is.null(des)) list(cov = NULL, adjusted_for = "not adjusted") else adjustment_for(s, des, u$predictor, stats::model.matrix(~ g))
  den <- NULL
  if (!is.null(layer$denominators)) {
    col <- names(layer$spec$denominators$columns)[1]
    den <- as.numeric(layer$denominators[[col]][match(s, layer$denominators$sample)])
  }
  list(m = m, g = g, den = den, lib = rowSums(m), samples = s, cov = adj$cov, adjusted_for = adj$adjusted_for)
}

# Features kept for per-feature tests: present in at least R-PREV of the
# samples of at least one of the two groups.
prevalent <- function(m, g) {
  colnames(m)[vapply(seq_len(ncol(m)), function(k) any(tapply(m[, k] > 0, g, mean) >= rule("R-PREV")), TRUE)]
}

unit_key <- function(u) data.frame(layer = u$layer, predictor = u$predictor, contrast = u$contrast %||% NA_character_,
                                   timepoint = u$timepoint, block = u$block, stringsAsFactors = FALSE)

clr <- function(m) { l <- log(m + rule("R-PSEUDO")); l - rowMeans(l) }

seed_for <- function(offset) rule("R-SEED") + offset

# The per-sample offset: the denominator when the layer has one, else library
# size. (Not `%||%`, which keeps only the first element.)
offset_of <- function(ud) if (is.null(ud$den)) ud$lib else ud$den
