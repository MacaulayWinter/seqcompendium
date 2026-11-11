#!/usr/bin/env Rscript
# ve7b_direct2.R: V-E7b diagnosis, second pass (CLAUDE.md D52). Follows ve7b_direct.R.
#  1. ALDEx2 exactly as the full engine runs it (q4_agreement -> FITS$D04), with any
#     error shown instead of swallowed, and its memory use; why did V-E7b count 0?
#  2. LEfSe: the engine's call fails ("constant within groups"); candidate fixes,
#     each changing one thing, counted on the same table.
#
#   Rscript validation/ve7b_direct2.R <Hackathon/Studies folder> <results dir> [data set]
args <- commandArgs(trailingOnly = TRUE); sdir <- args[1]; rdir <- args[2]
d <- if (length(args) > 2) args[3] else "ArcticFireSoils"
part <- if (length(args) > 3) args[4] else "all"   # aldex | lefse | all (ALDEx2 alone peaks near 5.6 GB, so on a 6 GB machine run the parts apart)
suppressPackageStartupMessages(library(seqcompendium))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "R", "ve7b_bits.R"))
e <- asNamespace("seqcompendium"); dir.create(rdir, recursive = TRUE, showWarnings = FALSE)
stamp <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")
rows <- list(); add <- function(what, n, note = "") { rows[[length(rows) + 1]] <<- data.frame(dataset = d, what = what, count = n, note = substr(note, 1, 400)); stamp(what, "|", n, "|", substr(note, 1, 200)) }
bh <- function(p) { p <- p[is.finite(p)]; sum(stats::p.adjust(p, "BH") < 0.05) }

s <- VE7B_SETS[[d]]; b <- file.path(tempfile(d), "bundle"); m <- ve7b_write_bundle(sdir, d, s, b)
bb <- e$read_bundle(b); gc <- e$check_guide(bb$md, bb$guide); lc <- e$check_layers(bb$layers, gc$md)
des <- e$read_design(gc$md, bb$guide, gc$info); cells <- e$design_cells(des)
u <- Filter(function(u) isTRUE(u$testable), e$contrast_units(lc$layers, des, cells))[[1]]
ud <- e$unit_data(u, lc$layers[[u$layer]], des); feats <- e$prevalent(ud$m, ud$g)
L <- lc$layers[[u$layer]]
add("agreement set for this layer", NA, paste(e$agreement_ids("Q4", L), collapse = " "))
add("covariates in the unit (NULL = none)", NA, if (is.null(ud$cov)) "none" else paste(names(ud$cov), collapse = " "))

# 1. ALDEx2 the engine's way, error shown.
if (part %in% c("aldex", "all")) {
invisible(gc(reset = TRUE)); t0 <- proc.time()[["elapsed"]]
r <- tryCatch(e$FITS$D04(ud, feats), error = function(err) conditionMessage(err))
mem <- sum(gc()[, 6])
if (is.character(r)) add("ALDEx2 via FITS$D04: ERROR", NA, r) else add("ALDEx2 via FITS$D04: BH(we.ep) < 0.05", bh(r$p), sprintf("%.0f s, R peak %.0f MB", proc.time()[["elapsed"]] - t0, mem))
ag <- e$q4_agreement(ud, feats, "D04")
add("ALDEx2 via q4_agreement (what Q4.csv holds): calls", sum(ag$call, na.rm = TRUE), paste(unique(ag$note), collapse = "; "))
}

# 2. LEfSe. The engine's input: relative abundance per sample.
if (part %in% c("lefse", "all")) {
rel <- t(ud$m[, feats, drop = FALSE] / pmax(rowSums(ud$m), 1))
lef <- function(x, label) {
  se <- SummarizedExperiment::SummarizedExperiment(assays = list(rel = x), colData = S4Vectors::DataFrame(g = ud$g, row.names = ud$samples))
  set.seed(e$seed_for(44))
  r <- tryCatch(withCallingHandlers(lefser::lefser(se, classCol = "g", assay = "rel"), warning = function(w) invokeRestart("muffleWarning"), message = function(m) invokeRestart("muffleMessage")),
                error = function(err) paste("error:", conditionMessage(err)))
  if (is.character(r)) add(label, NA, r) else add(label, nrow(r))
}
const_in_group <- apply(rel, 1, function(v) any(tapply(v, ud$g, function(z) stats::var(z) == 0)))
add("features constant (zero variance) within at least one group", sum(const_in_group), sprintf("of %d", nrow(rel)))
lef(rel, "LEfSe as the engine calls it")
lef(rel * 1e6, "LEfSe, relative abundance scaled to 1e6 (as Python LEfSe does)")
lef(rel[!const_in_group, , drop = FALSE], "LEfSe, features constant within a group dropped before LEfSe")
lef(rel[!const_in_group, , drop = FALSE] * 1e6, "LEfSe, dropped + scaled to 1e6")
}
utils::write.csv(do.call(rbind, rows), file.path(rdir, sprintf("ve7b_direct2_%s_%s.csv", d, part)), row.names = FALSE)
stamp("wrote", file.path(rdir, sprintf("ve7b_direct2_%s_%s.csv", d, part)), "; lefser", as.character(utils::packageVersion("lefser")), "; ALDEx2", as.character(utils::packageVersion("ALDEx2")))
