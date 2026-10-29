#!/usr/bin/env Rscript
# E1-M1 and E1-M12 in the container: the main toy bundle from end to end,
# with the HTML report rendered. Exits non-zero on any failure.
# Usage: check_toy_end_to_end.R <work_dir>
args <- commandArgs(trailingOnly = TRUE)
w <- if (length(args)) args[1] else tempfile("e2e")
library(seqcompendium)
b <- file.path(w, "bundle"); o <- file.path(w, "compendium")
make_toy_bundle(b)
leads <- run_compendium(b, o)
need <- c("report/compendium_report.html", "report/compendium_report.md", "05_leads/leads.csv", "01_profile/shape_profile.csv",
          "00_input_check/controls.csv", "03_results/Q2_alpha/results.csv", "figures/figures_index.csv", "provenance/session_info.txt")
miss <- need[!file.exists(file.path(o, need))]
if (length(miss)) stop("Missing outputs: ", paste(miss, collapse = ", "))
if (!all(sprintf("Q%d", 0:11) %in% leads$question)) stop("The leads table does not cover Q0-Q11.")
cat(sprintf("End to end passed: %d lead rows, HTML report %s bytes.\n", nrow(leads), file.size(file.path(o, "report/compendium_report.html"))))
