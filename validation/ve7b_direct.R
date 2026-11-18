#!/usr/bin/env Rscript
# ve7b_direct.R: V-E7b's diagnosis (CLAUDE.md D52), minutes rather than a full run.
# Builds the same bundle as ve7b_nearing.R, follows the engine's own steps to its
# Q4 unit (bundle check, design, unit, prevalence rule R-PREV), then runs the
# engine's own ALDEx2, Wilcoxon-on-CLR and LEfSe functions, and beside each the
# variant that differs in one setting only, so each difference from the paper
# can be put down to one cause: the engine, or how the comparison counts.
#
#   Rscript validation/ve7b_direct.R <Hackathon/Studies folder> <source_data_all.xlsx> <results dir> [data set]
args <- commandArgs(trailingOnly = TRUE); sdir <- args[1]; xlsx <- args[2]; rdir <- args[3]
d <- if (length(args) > 3) args[4] else "ArcticFireSoils"
suppressPackageStartupMessages(library(seqcompendium))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "R", "ve7b_bits.R"))
e <- asNamespace("seqcompendium")
dir.create(rdir, recursive = TRUE, showWarnings = FALSE)
paper <- as.data.frame(readxl::read_excel(xlsx, sheet = "Figure1B_counts (filt)", .name_repair = "minimal")); names(paper)[1] <- "method"
s <- VE7B_SETS[[d]]; pp <- function(meth) paper[[s$label]][paper$method == meth]
stamp <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")

b <- file.path(tempfile(d), "bundle"); m <- ve7b_write_bundle(sdir, d, s, b)
stamp(d, ":", ncol(m), "samples,", nrow(m), "features after the paper's 10% filter")
# The engine's own steps up to its Q4 unit (R/run.R).
bb <- e$read_bundle(b); gc <- e$check_guide(bb$md, bb$guide); lc <- e$check_layers(bb$layers, gc$md)
if (length(c(gc$stops, lc$stops))) stop(paste(c(gc$stops, lc$stops), collapse = "; "))
des <- e$read_design(gc$md, bb$guide, gc$info); cells <- e$design_cells(des)
units <- Filter(function(u) isTRUE(u$testable), e$contrast_units(lc$layers, des, cells))
u <- units[[1]]; ud <- e$unit_data(u, lc$layers[[u$layer]], des)
feats <- e$prevalent(ud$m, ud$g); all_f <- colnames(ud$m)
stamp("engine unit:", nrow(ud$m), "samples; groups", paste(sprintf("%s %d", levels(ud$g), as.vector(table(ud$g))), collapse = ", "),
      "; features", length(all_f), "; after R-PREV =", e$rule("R-PREV"), ":", length(feats))
bh <- function(p) { p <- p[is.finite(p)]; sum(stats::p.adjust(p, "BH") < 0.05) }
rows <- list(); add <- function(method, variant, n, note = "") {
  rows[[length(rows) + 1]] <<- data.frame(dataset = d, method = method, variant = variant, engine_count = n, paper = pp(method), note = note)
  stamp(method, "|", variant, "|", n, "vs paper", pp(method), if (nzchar(note)) paste("|", note) else "") }

# ALDEx2: the engine's call (fit_aldex2: same seed, 128 Monte Carlo instances,
# denom all, t-test), run once; counted the engine's way (BH of we.ep) and the
# way ALDEx2 users and Nearing 2022 count (its own we.eBH, and wi.eBH).
set.seed(e$seed_for(41))
x <- suppressMessages(ALDEx2::aldex(as.data.frame(t(ud$m[, feats, drop = FALSE])), as.character(ud$g), mc.samples = 128, test = "t", effect = TRUE, denom = "all", verbose = FALSE))
add("ALDEx2", "engine: BH over we.ep (what V-E7b counted)", bh(x$we.ep))
add("ALDEx2", "ALDEx2's own we.eBH < 0.05 (Welch)", sum(x$we.eBH < 0.05, na.rm = TRUE))
add("ALDEx2", "ALDEx2's own wi.eBH < 0.05 (Wilcoxon)", sum(x$wi.eBH < 0.05, na.rm = TRUE))
add("ALDEx2", "smallest we.ep / we.eBH", NA, sprintf("%.3g / %.3g", min(x$we.ep, na.rm = TRUE), min(x$we.eBH, na.rm = TRUE)))

# Wilcoxon on CLR: the engine's function on the R-PREV features, then on every
# feature of the paper's filtered table; then CLR with pseudocount 1 (one setting each).
w <- e$fit_wilcoxon_clr(ud, feats); add("Wilcoxon (CLR)", "engine: R-PREV features, pseudocount R-PSEUDO", bh(w$p))
if (length(feats) < length(all_f)) add("Wilcoxon (CLR)", "every feature of the filtered table", bh(e$fit_wilcoxon_clr(ud, all_f)$p))
z1 <- log(ud$m + 1); z1 <- z1 - rowMeans(z1); a <- ud$g == levels(ud$g)[1]
add("Wilcoxon (CLR)", "pseudocount 1, every feature", bh(vapply(all_f, function(f) suppressWarnings(stats::wilcox.test(z1[!a, f], z1[a, f])$p.value), 0)))

# LEfSe: the engine's describe_lefse, then lefser called the same way but with
# its error shown in full (the engine keeps it in the note).
lf <- e$describe_lefse(ud, feats)
add("LEfSe", "engine: describe_lefse", length(unique(stats::na.omit(lf$feature))), lf$note[1])
rel <- t(ud$m[, feats, drop = FALSE] / pmax(rowSums(ud$m), 1))
se <- SummarizedExperiment::SummarizedExperiment(assays = list(rel = rel), colData = S4Vectors::DataFrame(g = ud$g, row.names = ud$samples))
set.seed(e$seed_for(44))
r <- tryCatch(lefser::lefser(se, classCol = "g", assay = "rel"), error = function(err) paste("error:", conditionMessage(err)), warning = function(wn) paste("warning:", conditionMessage(wn)))
add("LEfSe", "lefser, messages shown", if (is.character(r)) NA else nrow(r), if (is.character(r)) r else "")
if (is.character(r) && grepl("warning", r)) {
  set.seed(e$seed_for(44)); r2 <- suppressWarnings(lefser::lefser(se, classCol = "g", assay = "rel"))
  add("LEfSe", "lefser after its warning", nrow(r2))
}
res <- do.call(rbind, rows)
utils::write.csv(res, file.path(rdir, sprintf("ve7b_direct_%s.csv", d)), row.names = FALSE)
utils::write.csv(data.frame(package = c("seqcompendium", "ALDEx2", "lefser", "R"), version = c(as.character(utils::packageVersion("seqcompendium")), as.character(utils::packageVersion("ALDEx2")), as.character(utils::packageVersion("lefser")), as.character(getRversion()))),
                 file.path(rdir, sprintf("ve7b_direct_%s_versions.csv", d)), row.names = FALSE)
stamp("wrote", file.path(rdir, sprintf("ve7b_direct_%s.csv", d)))
