# figures.R: figures only read the CSVs (X0124). draw_figures() is given the
# output folder and nothing else; it never sees the bundle or a model object.

#' Draw the compendium's figures from its CSV tables
#'
#' @param out the compendium output folder written by run_compendium().
#' @return the figure index (figure, source_csv, caption), invisibly.
#' @export
draw_figures <- function(out) {
  figdir <- file.path(out, "figures"); dir.create(figdir, showWarnings = FALSE, recursive = TRUE)
  index <- list()
  src <- "03_results/Q2_alpha/per_sample.csv"
  f <- file.path(out, src)
  if (file.exists(f)) {
    d <- utils::read.csv(f, stringsAsFactors = FALSE)
    preds <- setdiff(names(d), c("layer", "sample", "q_order", "hill", "coverage", "m", "method", "timepoint", "block"))
    for (nm in unique(d$layer)) for (p in preds) {
      x <- d[d$layer == nm & !is.na(d[[p]]), , drop = FALSE]
      if (!nrow(x)) next
      x$q_label <- factor(sprintf("q = %d", x$q_order))
      x[[p]] <- factor(x[[p]], levels = unique(x[[p]]))
      cap <- sprintf("Hill numbers at equal sample coverage (%.3f) per study sample, by %s, at each timepoint. Source: %s (layer %s).",
                     min(x$coverage), p, src, nm)
      g <- ggplot2::ggplot(x, ggplot2::aes(x = .data[[p]], y = .data$hill)) +
        ggplot2::geom_point(position = ggplot2::position_jitter(width = 0.1, height = 0, seed = 1), size = 2, alpha = 0.8) +
        ggplot2::stat_summary(fun = mean, geom = "crossbar", width = 0.4, linewidth = 0.3) +
        ggplot2::facet_grid(q_label ~ timepoint + block, scales = "free_y", labeller = ggplot2::labeller(q_label = ggplot2::label_value, .default = ggplot2::label_both)) +
        ggplot2::labs(x = p, y = "Hill number (effective number of features)", title = sprintf("Q2 alpha diversity: %s", nm),
                      caption = paste(strwrap(cap, 110), collapse = "\n")) +
        ggplot2::theme_bw(base_size = 10)
      stem <- sprintf("Q2_alpha_%s_%s", nm, p)
      ggplot2::ggsave(file.path(figdir, paste0(stem, ".pdf")), g, width = 7, height = 6)
      if (capabilities("png")) ggplot2::ggsave(file.path(figdir, paste0(stem, ".png")), g, width = 7, height = 6, dpi = 120)
      index[[length(index) + 1]] <- data.frame(figure = paste0("figures/", stem, ".pdf"), source_csv = src, caption = cap)
    }
  }
  src3 <- "03_results/Q3_composition/ordination.csv"
  if (file.exists(file.path(out, src3))) {
    d <- utils::read.csv(file.path(out, src3), stringsAsFactors = FALSE)
    for (nm in unique(d$layer)) for (p in unique(d$predictor[d$layer == nm])) {
      x <- d[d$layer == nm & d$predictor == p, , drop = FALSE]
      cap <- sprintf("PCoA of robust Aitchison distance, per comparison (%s) and timepoint; each panel is ordinated on its own. Source: %s (layer %s).", p, src3, nm)
      g <- ggplot2::ggplot(x, ggplot2::aes(x = .data$axis1, y = .data$axis2, colour = .data$group)) + ggplot2::geom_point(size = 2) +
        ggplot2::facet_wrap(~ timepoint + block + contrast, scales = "free", labeller = ggplot2::label_both) +
        ggplot2::labs(x = "PCoA axis 1", y = "PCoA axis 2", colour = p, title = sprintf("Q3 composition: %s", nm), caption = paste(strwrap(cap, 110), collapse = "\n")) +
        ggplot2::theme_bw(base_size = 10)
      stem <- sprintf("Q3_pcoa_%s_%s", nm, p)
      ggplot2::ggsave(file.path(figdir, paste0(stem, ".pdf")), g, width = 8, height = 5)
      if (capabilities("png")) ggplot2::ggsave(file.path(figdir, paste0(stem, ".png")), g, width = 8, height = 5, dpi = 120)
      index[[length(index) + 1]] <- data.frame(figure = paste0("figures/", stem, ".pdf"), source_csv = src3, caption = cap)
    }
  }
  src4 <- "03_results/Q4_differential/results.csv"
  if (file.exists(file.path(out, src4))) {
    d <- utils::read.csv(file.path(out, src4), stringsAsFactors = FALSE)
    d <- d[is.finite(d$effect) & is.finite(d$q), , drop = FALSE]
    for (nm in unique(d$layer)) for (p in unique(d$predictor[d$layer == nm])) {
      x <- d[d$layer == nm & d$predictor == p, , drop = FALSE]; if (!nrow(x)) next
      cap <- sprintf("Q4: each feature's effect against its q-value, per comparison and timepoint (dashed line: q = %s). Source: %s (layer %s).", rule("R-FDR"), src4, nm)
      g <- ggplot2::ggplot(x, ggplot2::aes(x = .data$effect, y = -log10(.data$q), colour = .data$status)) + ggplot2::geom_point(size = 1.8, alpha = 0.8) +
        ggplot2::geom_hline(yintercept = -log10(rule("R-FDR")), linetype = "dashed") +
        ggplot2::facet_wrap(~ contrast + timepoint + block, labeller = ggplot2::label_both) +
        ggplot2::labs(x = "effect (see effect_unit in the CSV)", y = "-log10(q)", colour = "status", title = sprintf("Q4 differential abundance: %s, by %s", nm, p),
                      caption = paste(strwrap(cap, 110), collapse = "\n")) + ggplot2::theme_bw(base_size = 10)
      stem <- sprintf("Q4_effects_%s_%s", nm, p)
      ggplot2::ggsave(file.path(figdir, paste0(stem, ".pdf")), g, width = 8, height = 5)
      if (capabilities("png")) ggplot2::ggsave(file.path(figdir, paste0(stem, ".png")), g, width = 8, height = 5, dpi = 120)
      index[[length(index) + 1]] <- data.frame(figure = paste0("figures/", stem, ".pdf"), source_csv = src4, caption = cap)
    }
  }
  src6 <- "03_results/Q6_change/alpha.csv"
  if (file.exists(file.path(out, src6))) {
    d <- utils::read.csv(file.path(out, src6), stringsAsFactors = FALSE)
    for (nm in unique(d$layer)) for (p in unique(d$predictor[d$layer == nm])) {
      x <- d[d$layer == nm & d$predictor == p, , drop = FALSE]; if (!nrow(x)) next
      x$q_label <- factor(sprintf("q = %d", x$q_order))
      cap <- sprintf("Q6: change in Hill number from the first timepoint, per group, with 95%% intervals where the model gives them. Source: %s (layer %s).", src6, nm)
      g <- ggplot2::ggplot(x, ggplot2::aes(x = .data$change, y = .data$effect, colour = .data$group)) +
        ggplot2::geom_hline(yintercept = 0, colour = "grey60") +
        ggplot2::geom_pointrange(ggplot2::aes(ymin = .data$ci_low, ymax = .data$ci_high), position = ggplot2::position_dodge(width = 0.4), na.rm = TRUE) +
        ggplot2::facet_wrap(~ q_label, scales = "free_y") +
        ggplot2::labs(x = "change", y = "change in Hill number", colour = p, title = sprintf("Q6 change over time: %s", nm), caption = paste(strwrap(cap, 110), collapse = "\n")) +
        ggplot2::theme_bw(base_size = 10)
      stem <- sprintf("Q6_alpha_change_%s_%s", nm, p)
      ggplot2::ggsave(file.path(figdir, paste0(stem, ".pdf")), g, width = 8, height = 4)
      if (capabilities("png")) ggplot2::ggsave(file.path(figdir, paste0(stem, ".png")), g, width = 8, height = 4, dpi = 120)
      index[[length(index) + 1]] <- data.frame(figure = paste0("figures/", stem, ".pdf"), source_csv = src6, caption = cap)
    }
  }
  idx <- if (length(index)) do.call(rbind, index) else data.frame(figure = character(0), source_csv = character(0), caption = character(0))
  write_csv(idx, file.path(figdir, "figures_index.csv"))
  invisible(idx)
}
