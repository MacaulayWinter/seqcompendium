#!/usr/bin/env Rscript
# ve7b_nearing.R: V-E7 (b), the engine against Nearing et al. 2022
# (doi:10.1038/s41467-022-28034-z) on its first two public datasets in C-locale
# order, ArcticFireSoils ("Soil - Fires") and ArcticFreshwaters ("Freshwater -
# Arctic"); validation/PREREGISTRATION.md §5, CLAUDE.md D41, D42.
#
#   Rscript validation/ve7b_nearing.R <Hackathon/Studies folder> <source_data_all.xlsx> <results dir> [data set]
#
# With a data set name (ArcticFireSoils or ArcticFreshwaters) only that one is
# run, so the two can run as separate tasks (validation/grid/run_ve7b.sh).
# Each writes ve7b_<data set>.csv; once both exist, the combined table
# ve7b_nearing.csv and the mark ve7b_marks.csv are written.
#
# The data are downloaded on the user's machine (validation/grid/prepare_ve7b.sh:
# figshare 14531724 and the paper's Source Data), never committed. For every
# method the engine shares with the paper (ALDEx2, Wilcoxon on CLR, LEfSe), the
# number of significant features is compared with the paper's filtered table
# (Figure 1B: features in fewer than 10% of samples removed), counted as the
# paper counts them: BH q < 0.05 (LEfSe: the features it reports). Equal
# passes; a difference is reported with the settings and package versions that differ.
args <- commandArgs(trailingOnly = TRUE); sdir <- args[1]; xlsx <- args[2]; rdir <- args[3]
only <- if (length(args) > 3) args[4] else NULL
suppressPackageStartupMessages(library(seqcompendium))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "R", "ve7b_bits.R"))   # read_asvs, ve7b_engine_count, ve7b_keep_engine_files (tested: validation/tests/test-ve7b.R)
dir.create(rdir, recursive = TRUE, showWarnings = FALSE)
SETS <- VE7B_SETS
if (!is.null(only) && !only %in% names(SETS)) stop("unknown data set ", only, "; use one of ", paste(names(SETS), collapse = ", "))
METHODS <- c(D04 = "ALDEx2", D17 = "Wilcoxon (CLR)", D19 = "LEfSe")
paper <- as.data.frame(readxl::read_excel(xlsx, sheet = "Figure1B_counts (filt)", .name_repair = "minimal")); names(paper)[1] <- "method"   # first column: the method, unnamed

for (d in if (is.null(only)) names(SETS) else only) {
  s <- SETS[[d]]; w <- tempfile(d); b <- file.path(w, "bundle"); rows <- list()
  m <- ve7b_write_bundle(sdir, d, s, b)
  cat(d, ": ", ncol(m), " samples, ", nrow(m), " features after the filter; engine starting ", format(Sys.time()), "\n", sep = "")
  o <- file.path(w, "out"); t0 <- proc.time()[["elapsed"]]
  # On an error the call stack is printed, so the log names the failing step.
  err <- tryCatch(withCallingHandlers({ suppressMessages(suppressWarnings(run_compendium(b, o))); NA_character_ },
                                      error = function(e) { cat("engine error:", conditionMessage(e), "\ncall stack:\n"); print(utils::head(rev(sys.calls()), 25)) }),
                  error = function(e) conditionMessage(e))
  secs <- proc.time()[["elapsed"]] - t0
  ag <- if (is.na(err)) utils::read.csv(file.path(o, "04_agreement", "Q4.csv")) else NULL
  ds <- if (is.na(err) && file.exists(file.path(o, "04_agreement", "Q4_describe_only.csv"))) utils::read.csv(file.path(o, "04_agreement", "Q4_describe_only.csv")) else NULL
  for (id in names(METHODS)) {
    n_engine <- if (!is.na(err)) NA else ve7b_engine_count(id, ag, ds)
    n_paper <- paper[[s$label]][paper$method == METHODS[[id]]]
    rows[[length(rows) + 1]] <- data.frame(dataset = d, paper_label = s$label, method = METHODS[[id]], samples = ncol(m), features = nrow(m),
                                           engine = n_engine, paper = n_paper, equal = isTRUE(n_engine == n_paper), seconds = round(secs), error = err)
  }
  # The engine's own tables and notes are kept (a few MB), so a difference can be traced without rerunning.
  if (dir.exists(o)) ve7b_keep_engine_files(o, file.path(rdir, sprintf("ve7b_%s_engine", d)))
  unlink(w, recursive = TRUE)
  res <- do.call(rbind, rows)
  res$differences <- "paper: R 4.0-era package versions, its own pre-processing scripts; engine: Bioconductor 3.23 versions, ALDEx2 and CLR as the engine runs them (pseudocount R-PSEUDO = 0.5), both groups' samples only"
  # A failed run is kept apart (ve7b_<data set>.failed.csv), so the mark is never
  # built from it; a later successful run replaces both files.
  ok_file <- file.path(rdir, sprintf("ve7b_%s.csv", d)); bad_file <- file.path(rdir, sprintf("ve7b_%s.failed.csv", d))
  if (is.na(err)) { utils::write.csv(res, ok_file, row.names = FALSE); unlink(bad_file) } else { utils::write.csv(res, bad_file, row.names = FALSE); unlink(ok_file) }
  print(res[, c("dataset", "method", "samples", "features", "engine", "paper", "equal", "seconds", "error")], row.names = FALSE)
  if (!is.na(err)) { cat("V-E7b: the engine run on", d, "stopped with an error; this task fails.\n"); quit(save = "no", status = 1) }
}

done <- file.path(rdir, sprintf("ve7b_%s.csv", names(SETS)))
if (!all(file.exists(done))) { cat("waiting for:", basename(done[!file.exists(done)]), "\n"); quit(save = "no") }
res <- do.call(rbind, lapply(done, utils::read.csv))
utils::write.csv(res, file.path(rdir, "ve7b_nearing.csv"), row.names = FALSE)
utils::write.csv(data.frame(mark = "V-E7", scenario = sprintf("(b) Nearing 2022, %s: %d of %d method counts equal the paper's", paste(names(SETS), collapse = " and "), sum(res$equal), nrow(res)),
                            number = mean(res$equal), threshold = "every count equal (published counts are whole numbers)", pass = all(res$equal), runs = nrow(res)),
                 file.path(rdir, "ve7b_marks.csv"), row.names = FALSE)
cat("wrote", file.path(rdir, "ve7b_marks.csv"), "\n")
