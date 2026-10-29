# q2.R: Q2, does within-sample diversity differ? (design §5.2, S1 snapshot row)
#
# Default: Hill numbers q = 0, 1, 2 at equal sample coverage (iNEXT, catalogue
# A02), then a Welch test of each group against the reference level, within
# each timepoint and block (never pooled). Benjamini-Hochberg within each
# contrast x timepoint x block, over the three orders q.
# Not built yet in E1 (stated in every result): the agreement set (rarefied
# plug-in Shannon, DivNet), the fallback ladder, leave-one-out, adjustment for
# batch or a second predictor, paired or longitudinal models (E3, E5, E6).

hill_at_equal_coverage <- function(m) {
  keep <- rowSums(m) > 0
  x <- lapply(which(keep), function(i) as.numeric(m[i, ]))
  names(x) <- rownames(m)[keep]
  # nboot = 0: no bootstrap, so the estimates are deterministic (mark E1-M11).
  est <- iNEXT::estimateD(x, q = c(0, 1, 2), datatype = "abundance", base = "coverage", nboot = 0)
  data.frame(sample = est$Assemblage, q_order = est$Order.q, hill = est$qD, coverage = est$SC, m = est$m, method = est$Method,
             stringsAsFactors = FALSE)
}

q2_alpha <- function(layers, des, cells) {
  st <- des$study; per_sample <- list(); res <- list(); diag <- list(); skipped <- list()
  for (nm in names(layers)) {
    L <- layers[[nm]]
    if (L$spec$unit != "count") {
      skipped[[length(skipped) + 1]] <- data.frame(layer = nm, reason = sprintf("Q2 for unit %s is not built yet (milestone E8).", L$spec$unit))
      next
    }
    m <- wide(L, st$sample)
    empty <- rownames(m)[rowSums(m) == 0]
    h <- hill_at_equal_coverage(m)
    h <- merge(h, cells, by = "sample")
    h <- merge(h, st[, c("sample", des$grouping), drop = FALSE], by = "sample")
    per_sample[[nm]] <- cbind(layer = nm, h)
    for (p in des$grouping) {
      lv <- des$levels_of(p)
      if (!length(lv)) {
        skipped[[length(skipped) + 1]] <- data.frame(layer = nm, reason = sprintf("`%s` has no levels listed in the column guide, so no reference level is declared; add levels (reference first) to compare its groups.", p))
        next
      }
      for (cell in unique(paste(h$timepoint, h$block, sep = "\r"))) {
        tp <- strsplit(cell, "\r", fixed = TRUE)[[1]]
        d <- h[h$timepoint == tp[1] & h$block == tp[2] & !is.na(h[[p]]), , drop = FALSE]
        ref <- lv[1]
        # A subject twice in one cell breaks the Welch test's independence.
        subj <- if (!is.na(des$subject)) st[[des$subject]][match(d$sample[d$q_order == 0], st$sample)] else character(0)
        paired_cell <- any(duplicated(stats::na.omit(subj)))
        for (lvl in setdiff(intersect(lv, unique(d[[p]])), ref)) {
          rows <- list()
          for (qq in c(0, 1, 2)) {
            a <- d$hill[d[[p]] == ref & d$q_order == qq]; b <- d$hill[d[[p]] == lvl & d$q_order == qq]
            r <- data.frame(layer = nm, predictor = p, contrast = sprintf("%s vs %s", lvl, ref), timepoint = tp[1], block = tp[2],
                            q_order = qq, n_reference = length(a), n_level = length(b),
                            mean_reference = if (length(a)) mean(a) else NA, mean_level = if (length(b)) mean(b) else NA,
                            effect = NA_real_, ci_low = NA_real_, ci_high = NA_real_, p = NA_real_, status = NA_character_, reason = NA_character_)
            if (paired_cell) {
              r$status <- "not_testable"; r$reason <- "a subject has more than one sample in this timepoint and block; the paired model is built at milestone E5"
            } else if (length(a) < rule("R-MINGRP") || length(b) < rule("R-MINGRP")) {
              r$status <- "not_testable"; r$reason <- sprintf("a group has fewer than %d samples (rule R-MINGRP)", rule("R-MINGRP"))
            } else {
              r$effect <- mean(b) - mean(a)
              tt <- tryCatch(stats::t.test(b, a, var.equal = FALSE), error = function(e) NULL)
              if (is.null(tt)) {
                # Both groups constant: no variation to test against.
                if (r$effect == 0) { r$p <- 1; r$ci_low <- 0; r$ci_high <- 0 } else { r$status <- "not_testable"; r$reason <- "no variation within either group" }
              } else { r$p <- tt$p.value; r$ci_low <- tt$conf.int[1]; r$ci_high <- tt$conf.int[2] }
            }
            rows[[length(rows) + 1]] <- r
            # Residual checks: recorded in E1, not yet acted on (fallbacks: E3).
            res_all <- c(a - mean(a), b - mean(b))
            sk <- if (length(res_all) > 2 && stats::sd(res_all) > 0) mean(res_all^3) / stats::sd(res_all)^3 else NA
            diag[[length(diag) + 1]] <- data.frame(layer = nm, predictor = p, contrast = r$contrast, timepoint = tp[1], block = tp[2], q_order = qq,
                                                   residual_skewness = sk,
                                                   sd_ratio = if (length(a) > 1 && length(b) > 1 && min(stats::sd(a), stats::sd(b)) > 0) max(stats::sd(a), stats::sd(b)) / min(stats::sd(a), stats::sd(b)) else NA,
                                                   action = "recorded only; the fallback ladder is built at milestone E3")
          }
          rows <- do.call(rbind, rows)
          tested <- !is.na(rows$p)
          rows$q <- NA_real_
          rows$q[tested] <- stats::p.adjust(rows$p[tested], method = "BH")
          rows$status[tested] <- ifelse(rows$q[tested] <= rule("R-FDR"), "lead", "no_evidence")
          res[[length(res) + 1]] <- rows
        }
      }
    }
    if (length(empty)) skipped[[length(skipped) + 1]] <- data.frame(layer = nm, reason = sprintf("%d study sample(s) with no reads were left out of Q2: %s.", length(empty), paste(empty, collapse = ", ")))
  }
  list(per_sample = if (length(per_sample)) do.call(rbind, per_sample) else NULL,
       results = if (length(res)) do.call(rbind, res) else NULL,
       diagnostics = if (length(diag)) do.call(rbind, diag) else NULL,
       skipped = if (length(skipped)) do.call(rbind, skipped) else NULL)
}
