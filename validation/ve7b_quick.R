#!/usr/bin/env Rscript
# ve7b_quick.R: an early, interim V-E7b count for one data set (CLAUDE.md D56),
# while the full engine run on the cluster gives the final one.
#
# It runs the three methods V-E7b counts (ALDEx2, Wilcoxon on CLR, LEfSe) the way
# the engine's Q4 does: the same bundle (ve7b_write_bundle), the same input
# checks, the same unit and prevalent features (q4_unit: unit_data + prevalent),
# then q4_agreement for ALDEx2 and Wilcoxon and describe_lefse for LEfSe, counted
# with ve7b_engine_count, as validation/ve7b_nearing.R counts the engine's tables.
# What it skips: everything else in run_compendium, including the override check
# (most of the run time). If that check moved Q4's default to ALDEx2 or Wilcoxon,
# the engine's agreement table would not list that method; the full run shows
# whether that happened. The result is interim and never replaces the full run.
#
#   Rscript validation/ve7b_quick.R <Hackathon/Studies folder> <source_data_all.xlsx> <results dir> <data set> <part>
#   part: aldex (ALDEx2 alone: it needs most of an 8 GB container) | wilcoxon_lefse
args <- commandArgs(trailingOnly = TRUE); sdir <- args[1]; xlsx <- args[2]; rdir <- args[3]; d <- args[4]; part <- args[5]
stopifnot(part %in% c("aldex", "wilcoxon_lefse"), d %in% c("ArcticFireSoils", "ArcticFreshwaters"))
suppressPackageStartupMessages(library(seqcompendium))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "R", "ve7b_bits.R"))
e <- asNamespace("seqcompendium"); dir.create(rdir, recursive = TRUE, showWarnings = FALSE)
stamp <- function(...) cat(format(Sys.time(), "%F %H:%M:%S"), ..., "\n")
METHODS <- c(D04 = "ALDEx2", D17 = "Wilcoxon (CLR)", D19 = "LEfSe")
paper <- as.data.frame(readxl::read_excel(xlsx, sheet = "Figure1B_counts (filt)", .name_repair = "minimal")); names(paper)[1] <- "method"

s <- VE7B_SETS[[d]]; b <- file.path(tempfile(d), "bundle")
stamp(d, part, ": writing the bundle")
m <- ve7b_write_bundle(sdir, d, s, b); rm(m); invisible(gc())
bb <- e$read_bundle(b); gcheck <- e$check_guide(bb$md, bb$guide); lc <- e$check_layers(bb$layers, gcheck$md)
des <- e$read_design(gcheck$md, bb$guide, gcheck$info); cells <- e$design_cells(des)
units <- Filter(function(u) isTRUE(u$testable), e$contrast_units(lc$layers, des, cells))
if (length(units) != 1) stop("expected exactly one testable comparison, found ", length(units))
u <- units[[1]]; L <- lc$layers[[u$layer]]
ud <- e$unit_data(u, L, des); feats <- e$prevalent(ud$m, ud$g)
agr <- e$agreement_ids("Q4", L)
stamp(sprintf("%d samples (%s), %d prevalent features; Q4 agreement set: %s", nrow(ud$m), paste(sprintf("%s %d", levels(ud$g), tabulate(ud$g)), collapse = ", "), length(feats), paste(agr, collapse = " ")))

ids <- if (part == "aldex") "D04" else c("D17", "D19")
rows <- list()
for (id in ids) {
  t0 <- proc.time()[["elapsed"]]
  ag <- ds <- NULL
  if (id == "D19") ds <- cbind(method_id = "D19", e$describe_lefse(ud, feats)) else ag <- e$q4_agreement(ud, feats, id)
  n <- ve7b_engine_count(id, ag, ds); why <- ve7b_engine_failure(id, ag, ds)
  rows[[id]] <- data.frame(dataset = d, method = METHODS[[id]], samples = nrow(ud$m), features = length(feats),
                           engine_quick = n, paper = paper[[s$label]][paper$method == METHODS[[id]]], equal = isTRUE(n == paper[[s$label]][paper$method == METHODS[[id]]]),
                           method_failed = nzchar(why), method_note = why, in_q4_agreement_set = id %in% agr | id == "D19",
                           seconds = round(proc.time()[["elapsed"]] - t0), engine_commit_note = "interim count (D56): the full engine run on the cluster is final")
  stamp(METHODS[[id]], ": ", n, " (paper ", rows[[id]]$paper, ")", if (nzchar(why)) paste(" FAILED:", why) else "")
}
out <- file.path(rdir, sprintf("ve7b_quick_%s_%s.csv", d, part))
utils::write.csv(do.call(rbind, rows), out, row.names = FALSE)
stamp("wrote", out, "; ALDEx2", as.character(utils::packageVersion("ALDEx2")), "; lefser", as.character(utils::packageVersion("lefser")))
