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
  idx <- if (length(index)) do.call(rbind, index) else data.frame(figure = character(0), source_csv = character(0), caption = character(0))
  write_csv(idx, file.path(figdir, "figures_index.csv"))
  invisible(idx)
}
