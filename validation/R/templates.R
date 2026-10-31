# templates.R: the data-choice rule (validation/PREREGISTRATION.md §2).
#
# The choosers take the sources' tables as arguments, so they can be tested on
# invented tables with known answers (CLAUDE.md D33, E7-M3). A step the source
# cannot supply stops, naming the step: that is a data doubt for the user, and
# it is never patched by choosing other data.

doubt <- function(...) stop(structure(class = c("data_doubt", "error", "condition"),
                                      list(message = paste0("Data doubt (goes to the user): ", sprintf(...)), call = NULL)))

need_cols <- function(x, cols, step) {
  miss <- setdiff(cols, names(x))
  if (length(miss)) doubt("%s needs column(s) %s, which the table does not have.", step, paste(miss, collapse = ", "))
}

c_sort <- function(x) { old <- Sys.getlocale("LC_COLLATE"); on.exit(Sys.setlocale("LC_COLLATE", old)); Sys.setlocale("LC_COLLATE", "C"); sort(x) }
c_order <- function(...) { old <- Sys.getlocale("LC_COLLATE"); on.exit(Sys.setlocale("LC_COLLATE", old)); Sys.setlocale("LC_COLLATE", "C"); order(...) }

# Shotgun templates (§2, steps 1-5). sm: curatedMetagenomicData's sampleMetadata.
# Returns the chosen rows, with their study, in study order.
choose_shotgun <- function(sm, how_many = 3, skip = 0) {
  need_cols(sm, c("body_site", "study_condition", "number_reads", "subject_id", "days_from_first_collection", "sample_id", "study_name"), "Shotgun step 2-4")
  x <- sm[sm$body_site %in% "stool" & sm$study_condition %in% "control" & !is.na(sm$number_reads), , drop = FALSE]   # step 2
  d <- x$days_from_first_collection; d[is.na(d)] <- 0
  x <- x[c_order(x$subject_id, d, x$sample_id), , drop = FALSE]                                                      # step 3
  x <- x[!duplicated(paste(x$study_name, x$subject_id, sep = "\r")), , drop = FALSE]
  n <- table(x$study_name); keep <- names(n)[n >= 20]                                                                # step 4
  studies <- c_sort(keep)                                                                                            # step 5
  if (length(studies) < skip + how_many) doubt("Shotgun step 5 asks for %d studies (after skipping %d), but only %d have at least 20 control stool subjects.", how_many, skip, length(studies))
  studies <- studies[skip + seq_len(how_many)]
  x <- x[x$study_name %in% studies, , drop = FALSE]
  x[c_order(match(x$study_name, studies), x$sample_id), , drop = FALSE]
}

# 16S templates (§2, steps 1-3). datasets: one row per dataset with columns
# dataset, is_16S (from the package documentation) and grouping (the
# documentation's grouping column); samples: the sample metadata, with a
# `dataset` column. Returns, per chosen dataset, the samples of its largest group.
choose_16s <- function(datasets, samples, how_many = 2, skip = 0) {
  need_cols(datasets, c("dataset", "is_16S", "grouping"), "16S step 1-2")
  need_cols(samples, c("dataset", "sample"), "16S step 2")
  d <- datasets[datasets$is_16S %in% TRUE, , drop = FALSE]                                                            # step 1
  pick <- list()
  for (i in seq_len(nrow(d))) {                                                                                       # step 2
    s <- samples[samples$dataset == d$dataset[i], , drop = FALSE]
    if (nrow(s) < 20) next     # no grouping can give a group of 20, so step 2 drops it whatever the column (D36)
    g <- d$grouping[i]
    if (is.na(g) || !nzchar(g)) doubt("16S step 2: the documentation names no grouping column for dataset %s.", d$dataset[i])
    if (!g %in% names(s)) doubt("16S step 2: dataset %s's grouping column `%s` is not in its sample metadata.", d$dataset[i], g)
    tb <- table(s[[g]]); if (!length(tb)) next
    top <- c_sort(names(tb)[tb == max(tb)])[1]     # ties: the first level in C-locale order
    if (max(tb) >= 20) pick[[d$dataset[i]]] <- s[s[[g]] %in% top, , drop = FALSE]
  }
  names_ok <- c_sort(names(pick))                                                                                     # step 3
  if (length(names_ok) < skip + how_many) doubt("16S step 3 asks for %d datasets (after skipping %d), but only %d have a group of at least 20.", how_many, skip, length(names_ok))
  pick[names_ok[skip + seq_len(how_many)]]
}
