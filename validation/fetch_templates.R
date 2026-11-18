#!/usr/bin/env Rscript
# fetch_templates.R: the data-choice rule, run for real
# (validation/PREREGISTRATION.md §2; CLAUDE.md D33 E7-M3, D36).
#
#   Rscript validation/fetch_templates.R <templates dir>
#
# Chooses the templates, downloads their counts (on the machine that runs the
# validation, never into the repository), fits the simulator to each and
# writes <dir>/<template>.fit.rds plus <dir>/templates.csv (what was chosen,
# from where). Fits the 3 main and the reserve templates (4th, 5th shotgun;
# 3rd 16S) for the fresh-data confirmation of §8.
args <- commandArgs(trailingOnly = TRUE); tdir <- args[1]
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
for (f in c("templates.R", "simulate.R")) source(file.path(here, "R", f))
suppressPackageStartupMessages({ library(curatedMetagenomicData); library(MicrobiomeBenchmarkData) })
stopifnot(packageVersion("curatedMetagenomicData") == "3.20.0", packageVersion("MicrobiomeBenchmarkData") == "1.14.0")
dir.create(tdir, recursive = TRUE, showWarnings = FALSE)
log <- list()

# Shotgun (§2 steps 1-6).
sm <- curatedMetagenomicData::sampleMetadata
rows <- choose_shotgun(sm, how_many = 5)
studies <- unique(rows$study_name)
for (i in seq_along(studies)) {
  r <- rows[rows$study_name == studies[i], ]
  tse <- suppressMessages(curatedMetagenomicData::returnSamples(r, "relative_abundance", counts = TRUE))
  m <- t(as.matrix(SummarizedExperiment::assay(tse)))
  reads <- stats::setNames(r$number_reads, r$sample_id)[rownames(m)]
  nm <- sprintf("shotgun%d", i)
  saveRDS(fit_template(m, reads = reads), file.path(tdir, sprintf("%s.fit.rds", nm)))
  log[[nm]] <- data.frame(template = nm, source = "curatedMetagenomicData 3.20.0", dataset = studies[i], group = "control stool, first sample per subject",
                          samples = nrow(m), features = sum(colSums(m) > 0), denominator = "number_reads", role = if (i <= 3) "main" else "fresh-data reserve")
}

# 16S (§2 steps 1-3). The package's sample table has `sequencing_method`; the
# documentation (extdata/datasets.tsv, column Contrasts) names each dataset's
# contrast in words, and the grouping column is the one sample column whose
# values both sides of the contrast match (D36).
norm <- function(x) gsub("[^a-z0-9]", "", tolower(x))
utils::data("sampleMetadata", package = "MicrobiomeBenchmarkData", envir = environment())
s16 <- sampleMetadata
doc <- utils::read.delim(system.file("extdata/datasets.tsv", package = "MicrobiomeBenchmarkData"), check.names = FALSE)
grouping_of <- function(d) {
  sides <- norm(sub("\\(.*\\)", "", strsplit(sub("\\.$", "", doc$Contrasts[doc$Dataset == d]), " vs ", fixed = TRUE)[[1]]))
  x <- s16[s16$dataset == d, , drop = FALSE]
  hit <- names(x)[vapply(names(x), function(c) {
    v <- norm(unique(stats::na.omit(as.character(x[[c]])))); length(v) >= 2 &&
      all(vapply(sides, function(sd) any(startsWith(v, sd) | startsWith(sd, v)), TRUE)) }, TRUE)]
  if (length(hit) == 1) hit else NA_character_
}
ds <- data.frame(dataset = doc$Dataset, stringsAsFactors = FALSE)
ds$is_16S <- vapply(ds$dataset, function(d) any(grepl("16S", s16$sequencing_method[s16$dataset == d], ignore.case = TRUE)), TRUE)
ds$grouping <- vapply(ds$dataset, function(d) if (ds$is_16S[ds$dataset == d]) grouping_of(d) else NA_character_, "")
names(s16)[names(s16) == "sample_id"] <- "sample"
pick <- choose_16s(ds, s16, how_many = 3)
for (i in seq_along(pick)) {
  d <- names(pick)[i]
  tse <- getBenchmarkData(d, dryrun = FALSE)[[1]]
  m <- t(as.matrix(SummarizedExperiment::assay(tse)))
  m <- m[intersect(pick[[d]]$sample, rownames(m)), , drop = FALSE]
  nm <- sprintf("16S%d", i)
  saveRDS(fit_template(m), file.path(tdir, sprintf("%s.fit.rds", nm)))
  g <- ds$grouping[ds$dataset == d]
  log[[nm]] <- data.frame(template = nm, source = "MicrobiomeBenchmarkData 1.14.0", dataset = d, group = sprintf("%s = %s", g, unique(pick[[d]][[g]])),
                          samples = nrow(m), features = sum(colSums(m) > 0), denominator = "none", role = if (i <= 2) "main" else "fresh-data reserve")
}
utils::write.csv(do.call(rbind, log), file.path(tdir, "templates.csv"), row.names = FALSE)
utils::write.csv(ds, file.path(tdir, "16S_datasets_as_read.csv"), row.names = FALSE)
print(do.call(rbind, log))
