# figures.R: figures only read the CSVs (X0124). draw_figures() is given the
# output folder and nothing else; it never sees the bundle or a model object.
#
# Every figure is written for a reader with no statistics background
# (methods-reporting design §3.8): axis titles say what is measured and which
# way is "more", captions define each term at first use, and colour is never
# the only cue (Okabe-Ito colours, which stay distinct under the common forms
# of colour blindness, plus a different shape per group).

# Okabe & Ito (2008) colour-blind-safe palette; yellow last, as it is faint on white.
OKABE_ITO <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9", "#000000", "#F0E442")
GROUP_SHAPES <- c(16, 17, 15, 18, 1, 2, 0, 5)
# Above this share of negative eigenvalues (relative to the positive ones), the
# PCoA's per-axis shares are called approximate in the caption.
PCOA_NEGATIVE_NOTE <- 0.05

group_scales <- function(lv, title) {
  n <- length(lv)
  list(ggplot2::scale_colour_manual(values = stats::setNames(rep_len(OKABE_ITO, n), lv), name = title),
       ggplot2::scale_shape_manual(values = stats::setNames(rep_len(GROUP_SHAPES, n), lv), name = title))
}

wrap_caption <- function(cap, width = 110) paste(strwrap(cap, width), collapse = "\n")

# Plain words for each Hill order, used wherever q_order is shown.
hill_label <- function(q) {
  lab <- c(`0` = "q = 0 (number of features)", `1` = "q = 1 (typical number, Shannon-like)", `2` = "q = 2 (number of dominant features)")
  out <- unname(lab[as.character(q)]); out[is.na(out)] <- sprintf("q = %s", q[is.na(out)])
  factor(out, levels = unique(c(lab, out)[c(lab, out) %in% out]))
}
HILL_DEFINITION <- paste("A Hill number is an effective number of features: q = 0 counts every feature present,",
                         "q = 1 weights features by their abundance (like the Shannon index), and q = 2 counts only the dominant ones.")

# Plain words for a Q4 effect unit, read from the CSV's effect_unit column.
effect_unit_words <- function(u) {
  ifelse(grepl("log2 fold change", u), "log2 fold change (1 = twice as much, -1 = half)",
  ifelse(grepl("CLR", u), "difference in centred log-ratio, CLR (0 = no difference)", u))
}

# A panel's comparison in one line: timepoint, block (when there is one), contrast.
comparison_label <- function(x) paste0(x$timepoint, ifelse(x$block %in% c("none", ""), "", paste0(", block ", x$block)), ", ", x$contrast)

# Q3 panel label: the comparison, then each axis's share of the differences.
q3_panel_label <- function(x) sprintf("%s\nAxis 1: %.0f%%, Axis 2: %.0f%%", comparison_label(x), 100 * x$axis1_share, 100 * x$axis2_share)

# The Q3 figure for one layer and predictor, from ordination.csv rows only.
q3_plot <- function(x, p, nm, src) {
  x$panel <- q3_panel_label(x)
  x$group <- factor(x$group, levels = unique(x$group))
  neg <- unique(x[, c("panel", "negative_eigen_share")])
  neg <- neg[is.finite(neg$negative_eigen_share) & neg$negative_eigen_share > PCOA_NEGATIVE_NOTE, , drop = FALSE]
  cap <- paste0(
    "Each dot is one sample; dots close together have a similar make-up (which features they contain, in what proportions). ",
    "The picture is a PCoA (principal coordinates analysis) of the robust Aitchison distance, a distance suited to proportions; ",
    "each panel is drawn on its own. The % in each panel title is the share of all differences between samples that each axis shows, ",
    "so the rest is not visible here. Whether the groups differ is decided by the PERMANOVA test (03_results/Q3_composition/results.csv), not by eye.",
    if (nrow(neg)) sprintf(" In %d panel(s) the distances cannot be drawn exactly (negative eigenvalues up to %.0f%% of the positive ones), so the shares there are approximate.",
                           nrow(neg), 100 * max(neg$negative_eigen_share)) else "",
    sprintf(" Comparison: %s. Source: %s (layer %s).", p, src, nm))
  g <- ggplot2::ggplot(x, ggplot2::aes(x = .data$axis1, y = .data$axis2, colour = .data$group, shape = .data$group)) +
    ggplot2::geom_point(size = 2.2) +
    ggplot2::facet_wrap(~ panel, scales = "free") +
    group_scales(levels(x$group), p) +
    ggplot2::labs(x = "Axis 1", y = "Axis 2 (no units: only distances between dots matter)",
                  title = sprintf("Q3 overall make-up of each sample: %s", nm), caption = wrap_caption(cap)) +
    ggplot2::theme_bw(base_size = 10) + ggplot2::theme(plot.caption = ggplot2::element_text(hjust = 0))
  list(plot = g, caption = cap)
}

#' Draw the compendium's figures from its CSV tables
#'
#' @param out the compendium output folder written by run_compendium().
#' @return the figure index (figure, source_csv, caption), invisibly.
#' @export
draw_figures <- function(out) {
  figdir <- file.path(out, "figures"); dir.create(figdir, showWarnings = FALSE, recursive = TRUE)
  index <- list()
  save <- function(g, stem, w, h, src, cap) {
    ggplot2::ggsave(file.path(figdir, paste0(stem, ".pdf")), g, width = w, height = h)
    if (capabilities("png")) ggplot2::ggsave(file.path(figdir, paste0(stem, ".png")), g, width = w, height = h, dpi = 120)
    index[[length(index) + 1]] <<- data.frame(figure = paste0("figures/", stem, ".pdf"), source_csv = src, caption = cap)
  }
  left <- ggplot2::theme(plot.caption = ggplot2::element_text(hjust = 0))
  src <- "03_results/Q2_alpha/per_sample.csv"
  f <- file.path(out, src)
  if (file.exists(f)) {
    d <- utils::read.csv(f, stringsAsFactors = FALSE)
    preds <- setdiff(names(d), c("layer", "sample", "q_order", "hill", "coverage", "m", "method", "timepoint", "block"))
    for (nm in unique(d$layer)) for (p in preds) {
      x <- d[d$layer == nm & !is.na(d[[p]]), , drop = FALSE]
      if (!nrow(x)) next
      x$q_label <- hill_label(x$q_order)
      x[[p]] <- factor(x[[p]], levels = unique(x[[p]]))
      cap <- paste(HILL_DEFINITION,
                   sprintf("Each dot is one sample and the bar is the group's mean; samples are compared at equal sample coverage (%.3f: the share of each sample's community its reads are estimated to cover).",
                           min(x$coverage)),
                   sprintf("Compared by %s, at each timepoint. Source: %s (layer %s).", p, src, nm))
      g <- ggplot2::ggplot(x, ggplot2::aes(x = .data[[p]], y = .data$hill, colour = .data[[p]], shape = .data[[p]])) +
        ggplot2::geom_point(position = ggplot2::position_jitter(width = 0.1, height = 0, seed = 1), size = 2, alpha = 0.8) +
        ggplot2::stat_summary(fun = mean, geom = "crossbar", width = 0.4, linewidth = 0.3, colour = "grey30") +
        ggplot2::facet_grid(q_label ~ timepoint + block, scales = "free_y", labeller = ggplot2::labeller(q_label = ggplot2::label_wrap_gen(22), .default = ggplot2::label_both)) +
        group_scales(levels(x[[p]]), p) + ggplot2::guides(colour = "none", shape = "none") +
        ggplot2::labs(x = p, y = "Hill number (effective number of features)", title = sprintf("Q2 within-sample diversity: %s", nm),
                      caption = wrap_caption(cap)) +
        ggplot2::theme_bw(base_size = 10) + left
      save(g, sprintf("Q2_alpha_%s_%s", nm, p), 7, 6.5, src, cap)
    }
  }
  src3 <- "03_results/Q3_composition/ordination.csv"
  if (file.exists(file.path(out, src3))) {
    d <- utils::read.csv(file.path(out, src3), stringsAsFactors = FALSE)
    for (nm in unique(d$layer)) for (p in unique(d$predictor[d$layer == nm])) {
      q3 <- q3_plot(d[d$layer == nm & d$predictor == p, , drop = FALSE], p, nm, src3)
      save(q3$plot, sprintf("Q3_pcoa_%s_%s", nm, p), 8, 5.5, src3, q3$caption)
    }
  }
  src4 <- "03_results/Q4_differential/results.csv"
  if (file.exists(file.path(out, src4))) {
    d <- utils::read.csv(file.path(out, src4), stringsAsFactors = FALSE)
    d <- d[is.finite(d$effect) & is.finite(d$q), , drop = FALSE]
    fdr <- rule("R-FDR"); fdr_lab <- sprintf("q = %.2f", fdr)
    for (nm in unique(d$layer)) for (p in unique(d$predictor[d$layer == nm])) {
      x <- d[d$layer == nm & d$predictor == p, , drop = FALSE]; if (!nrow(x)) next
      x$unit <- effect_unit_words(x$effect_unit)
      units <- unique(x$unit); mixed <- length(units) > 1
      x$status <- factor(gsub("_", " ", x$status))
      cap <- paste0("Each dot is one feature. Left-right: how much it differs between the groups; positive means more in the first group named in the panel title. ",
                    "Up-down: the evidence that it differs, from its q-value (a p-value corrected for testing many features at once); ",
                    sprintf("dots above the dashed line (%s) are leads. ", fdr_lab),
                    if (any(grepl("CLR", x$unit))) "CLR, the centred log-ratio, compares a feature's abundance with the sample's typical feature. " else "",
                    if (mixed) "Panels differ in unit because some features needed a fallback method; the unit is in each panel title. " else "",
                    sprintf("Source: %s (layer %s).", src4, nm))
      x$panel <- if (mixed) paste0(comparison_label(x), "\n", x$unit) else comparison_label(x)
      g <- ggplot2::ggplot(x, ggplot2::aes(x = .data$effect, y = -log10(.data$q), colour = .data$status, shape = .data$status)) +
        ggplot2::geom_point(size = 1.8, alpha = 0.8) +
        ggplot2::geom_hline(yintercept = -log10(fdr), linetype = "dashed") +
        ggplot2::annotate("text", x = -Inf, y = -log10(fdr), label = fdr_lab, hjust = -0.1, vjust = -0.4, size = 3) +
        ggplot2::facet_wrap(~ panel) +
        group_scales(levels(x$status), "Result") +
        ggplot2::labs(x = if (mixed) "Difference between groups (unit in each panel title)" else paste0("Difference between groups: ", units),
                      y = "Evidence of a difference: -log10(q) (higher = stronger)",
                      title = sprintf("Q4 features that differ in abundance: %s, by %s", nm, p), caption = wrap_caption(cap)) +
        ggplot2::theme_bw(base_size = 10) + left
      save(g, sprintf("Q4_effects_%s_%s", nm, p), 8, 5.5, src4, cap)
    }
  }
  src6 <- "03_results/Q6_change/alpha.csv"
  if (file.exists(file.path(out, src6))) {
    d <- utils::read.csv(file.path(out, src6), stringsAsFactors = FALSE)
    for (nm in unique(d$layer)) for (p in unique(d$predictor[d$layer == nm])) {
      x <- d[d$layer == nm & d$predictor == p, , drop = FALSE]; if (!nrow(x)) next
      x$q_label <- hill_label(x$q_order)
      x$group <- factor(x$group, levels = unique(x$group))
      cap <- paste("Each point is a group's average change in diversity from the first timepoint; the grey line at 0 means no change,",
                   "and the bars are 95% intervals (the range of values the data support), where the model gives them.",
                   HILL_DEFINITION, sprintf("Source: %s (layer %s).", src6, nm))
      g <- ggplot2::ggplot(x, ggplot2::aes(x = .data$change, y = .data$effect, colour = .data$group, shape = .data$group)) +
        ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
        ggplot2::geom_pointrange(ggplot2::aes(ymin = .data$ci_low, ymax = .data$ci_high), position = ggplot2::position_dodge(width = 0.4), na.rm = TRUE) +
        ggplot2::facet_wrap(~ q_label, scales = "free_y") +
        group_scales(levels(x$group), p) +
        ggplot2::labs(x = "Change from the first timepoint", y = "Change in Hill number\n(effective number of features)",
                      title = sprintf("Q6 change in diversity over time: %s", nm), caption = wrap_caption(cap)) +
        ggplot2::theme_bw(base_size = 10) + left
      save(g, sprintf("Q6_alpha_change_%s_%s", nm, p), 8, 4.5, src6, cap)
    }
  }
  idx <- if (length(index)) do.call(rbind, index) else data.frame(figure = character(0), source_csv = character(0), caption = character(0))
  write_csv(idx, file.path(figdir, "figures_index.csv"))
  invisible(idx)
}
