#!/usr/bin/env Rscript
# Writes an invented toy bundle (never research data).
# Usage: make_toy_bundle.R <dir> [main|no_controls|copy_null|planted]
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("Usage: make_toy_bundle.R <dir> [main|no_controls|copy_null|planted]")
seqcompendium::make_toy_bundle(args[1], if (length(args) > 1) args[2] else "main")
cat("Toy bundle written to", args[1], "\n")
