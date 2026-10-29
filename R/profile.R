# profile.R: the shape profile (design §3.1) and the controls table (§2.10).
# Study samples only: control samples are counted separately, never as data.

wide <- function(layer, samples) {
  d <- layer$data[layer$data$sample %in% samples, , drop = FALSE]
  f <- sort(unique(layer$data$feature))
  m <- matrix(0, nrow = length(samples), ncol = length(f), dimnames = list(samples, f))
  m[cbind(match(d$sample, samples), match(d$feature, f))] <- d$value
  m[samples %in% unique(d$sample), , drop = FALSE]
}

shape_profile <- function(layers, des, cells) {
  rows <- list(); add <- function(layer, property, value, source) rows[[length(rows) + 1]] <<- data.frame(layer = layer, property = property, value = as.character(value), source = source)
  st <- des$study
  for (nm in names(layers)) {
    L <- layers[[nm]]; m <- wide(L, st$sample)
    shape <- switch(L$spec$unit, count = "S1 counts", proportion = "S2 proportions", presence = "S3 presence/absence", "S2 non-count values")
    add(nm, "shape", shape, "manifest")
    add(nm, "unit", L$spec$unit, "manifest, checked against data")
    add(nm, "feature_level", L$spec$feature_level %||% "not stated", "manifest")
    add(nm, "n_study_samples", nrow(m), "data")
    add(nm, "n_features", ncol(m), "data")
    grp <- if (length(des$grouping)) st[[des$grouping[1]]][match(rownames(m), st$sample)] else rep("all", nrow(m))
    prev_ok <- vapply(seq_len(ncol(m)), function(k) any(tapply(m[, k] > 0, grp, mean) >= rule("R-PREV"), na.rm = TRUE), TRUE)
    add(nm, "n_features_passing_prevalence_rule", sum(prev_ok), sprintf("data + rule R-PREV (%s of samples in at least one group of `%s`)", rule("R-PREV"), des$grouping[1] %||% "all"))
    add(nm, "zeros_percent", sprintf("%.1f", 100 * mean(m == 0)), "data")
    if (L$spec$unit == "count") {
      lib <- rowSums(m)
      add(nm, "library_size_min", min(lib), "data"); add(nm, "library_size_median", stats::median(lib), "data"); add(nm, "library_size_max", max(lib), "data")
      add(nm, "library_size_max_over_min", if (min(lib) > 0) sprintf("%.2f", max(lib) / min(lib)) else "Inf (a sample has no reads)", "data")
    }
    add(nm, "denominators", if (is.null(L$spec$denominators)) "none" else paste(names(L$spec$denominators$columns), collapse = ", "), "manifest")
    add(nm, "tree", L$spec$tree %||% "none", "manifest")
    add(nm, "paired_layer", L$spec$paired_with %||% "none", "manifest")
  }
  add("design", "design_class", des$class, "guide")
  for (p in des$grouping) add("design", sprintf("predictor_%s", p), sprintf("levels: %s; reference: %s", paste(des$levels_of(p), collapse = "|"), des$levels_of(p)[1] %||% "none declared"), "guide")
  for (p in des$continuous) add("design", sprintf("predictor_%s", p), "continuous covariate", "guide")
  ce <- merge(cells, st, by = "sample")
  for (p in des$grouping) {
    tb <- table(ce[[p]], paste(ce$timepoint, ce$block))
    add("design", sprintf("smallest_group_%s", p), min(tb[tb > 0]), "guide + data (per group, timepoint and block)")
    n <- min(tb[tb > 0])
    add("design", sprintf("exact_rank_test_p_floor_%s", p), signif(2 / choose(2 * n, n), 3), "computed: two-sided exact Wilcoxon, smallest group vs a group of the same size")
  }
  add("design", "subjects", if (is.na(des$subject)) "no subject_id column" else length(unique(stats::na.omit(st[[des$subject]]))), "guide + data")
  add("design", "timepoints", if (is.na(des$time)) "no time column" else paste(des$time_order, collapse = ", "), "guide + data")
  add("design", "blocks", if (length(des$block)) paste(des$block, collapse = ", ") else "none", "guide")
  add("design", "batch", if (length(des$batch)) paste(des$batch, collapse = ", ") else "none", "guide")
  add("design", "outcomes", if (length(des$outcome)) paste(des$outcome, collapse = ", ") else "none", "guide")
  kinds <- table(des$controls$kind)
  add("design", "controls_by_kind", if (length(kinds)) paste(sprintf("%s %d", names(kinds), as.vector(kinds)), collapse = ", ") else "none (warning: no controls)", "guide (sample_control, F8)")
  do.call(rbind, rows)
}

controls_table <- function(layers, des) {
  ct <- des$controls
  if (!nrow(ct)) return(data.frame(sample = character(0), kind = character(0), layer = character(0), total = numeric(0),
                                   features_detected = integer(0), mock_recovery = character(0)))
  out <- list()
  for (nm in names(layers)) {
    m <- wide(layers[[nm]], ct$sample)
    k <- ct$kind[match(rownames(m), ct$sample)]
    out[[nm]] <- data.frame(sample = rownames(m), kind = k, layer = nm, total = rowSums(m), features_detected = rowSums(m > 0),
                            mock_recovery = ifelse(k == "positive_mock", "not run (E4: needs the mock's known composition in the manifest)", "not applicable"))
  }
  no_data <- setdiff(ct$sample, unlist(lapply(out, `[[`, "sample")))
  res <- do.call(rbind, out)
  if (length(no_data)) res <- rbind(res, data.frame(sample = no_data, kind = ct$kind[match(no_data, ct$sample)], layer = "none", total = NA,
                                                    features_detected = NA, mock_recovery = "no data in any layer"))
  rownames(res) <- NULL
  res
}

# Q1: what is there, per feature, group, timepoint and block. Description only.
q1_describe <- function(layers, des, cells) {
  st <- des$study; out <- list()
  preds <- if (length(des$grouping)) des$grouping else NA_character_
  for (nm in names(layers)) {
    m <- wide(layers[[nm]], st$sample)
    for (p in preds) {
      grp <- if (is.na(p)) rep("all", nrow(m)) else st[[p]][match(rownames(m), st$sample)]
      ce <- cells[match(rownames(m), cells$sample), ]
      key <- paste(grp, ce$timepoint, ce$block, sep = "\r")
      for (k in unique(key[!is.na(grp)])) {
        idx <- which(key == k); parts <- strsplit(k, "\r", fixed = TRUE)[[1]]
        out[[length(out) + 1]] <- data.frame(layer = nm, predictor = p %||% "none", group = parts[1], timepoint = parts[2], block = parts[3],
                                             feature = colnames(m), n_samples = length(idx),
                                             prevalence = colMeans(m[idx, , drop = FALSE] > 0),
                                             median = apply(m[idx, , drop = FALSE], 2, stats::median),
                                             mean = colMeans(m[idx, , drop = FALSE]), row.names = NULL)
      }
    }
  }
  res <- do.call(rbind, out)
  res[order(res$layer, res$predictor, res$feature, res$timepoint, res$block, res$group), ]
}
