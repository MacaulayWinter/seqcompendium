# bundle.R: reading the bundle (design §2).
#
# A bundle is one folder: manifest.yaml, metadata/ (study_metadata.tsv and
# column_guide.csv), layers/ (one long table per layer, its feature table, and
# optional denominators). The manifest says what each file is, so the engine
# never works it out. E1 reads shapes S1 and S2 (counts, proportions); the
# other shapes' files are recognised and reported as not built yet.

UNITS <- c("count", "proportion", "presence", "coverage", "length_normalised", "fraction_with_depth")
FEATURE_ROLES <- c("label", "hierarchy", "set", "length", "flag", "describe")

#' Read a bundle
#'
#' Reads the manifest and every file it names. Problems with the files
#' themselves (missing, malformed) are collected and stop the run together.
#' Nothing is checked against the column guide here; run_compendium() does that.
#'
#' @param bundle the bundle folder (manifest.yaml, metadata/, layers/).
#' @return a list: path, manifest, md (the metadata, as text), guide (or NULL),
#'   layers (each with spec, data, features, denominators), inputs.
#' @export
read_bundle <- function(bundle) {
  stops <- character(0); stop_if <- function(cond, msg) if (isTRUE(cond)) stops <<- c(stops, msg)
  mf <- file.path(bundle, "manifest.yaml")
  if (!file.exists(mf)) stop_engine(sprintf("No manifest.yaml in %s: a bundle starts with its manifest (design section 2.1).", bundle))
  man <- yaml::read_yaml(mf)
  path <- function(p) file.path(bundle, p)
  exists_or_stop <- function(p, what) { ok <- !is.null(p) && file.exists(path(p)); stop_if(!ok, sprintf("The manifest names %s `%s`, but that file is not in the bundle.", what, p %||% "(none given)")); ok }

  md_ok <- exists_or_stop(man$metadata$table, "the metadata table")
  guide_given <- !is.null(man$metadata$column_guide)
  guide_ok <- guide_given && exists_or_stop(man$metadata$column_guide, "the column guide")
  stop_if(!length(man$layers), "The manifest lists no layers: a bundle needs at least one data table.")
  layers <- list()
  for (L in man$layers) {
    nm <- L$name %||% "(unnamed)"
    stop_if(is.null(L$name), "A layer in the manifest has no `name`.")
    stop_if(!L$unit %in% UNITS, sprintf("Layer `%s`: unit '%s' is not one of: %s.", nm, L$unit %||% "", paste(UNITS, collapse = ", ")))
    f_ok <- exists_or_stop(L$file, sprintf("layer `%s`'s data file", nm))
    a_ok <- exists_or_stop(L$features, sprintf("layer `%s`'s feature table", nm))
    d_ok <- if (!is.null(L$denominators)) exists_or_stop(L$denominators$file, sprintf("layer `%s`'s denominators", nm)) else TRUE
    for (role in unlist(L$feature_columns)) stop_if(!role %in% FEATURE_ROLES, sprintf("Layer `%s`: feature-column role '%s' is not one of: %s.", nm, role, paste(FEATURE_ROLES, collapse = ", ")))
    if (f_ok && a_ok && d_ok)
      layers[[nm]] <- list(spec = L, data = read_table(path(L$file)), features = read_table(path(L$features)),
                           denominators = if (!is.null(L$denominators)) read_table(path(L$denominators$file)) else NULL)
  }
  if (length(stops)) stop_engine(paste0("The bundle is incomplete. Nothing has been assumed.\n  - ", paste(stops, collapse = "\n  - ")))
  md <- read_table(path(man$metadata$table), keep_none = TRUE)
  if (!"sample" %in% names(md)) stop_engine("The metadata table has no `sample` column, so its rows cannot be matched to the data.")
  md <- md[, c("sample", setdiff(names(md), "sample")), drop = FALSE]
  guide <- if (guide_ok) read_guide(path(man$metadata$column_guide)) else NULL
  inputs <- c("manifest.yaml", man$metadata$table, if (guide_ok) man$metadata$column_guide,
              unlist(lapply(man$layers, function(L) c(L$file, L$features, L$denominators$file))))
  list(path = bundle, manifest = man, md = md, guide = guide, layers = layers, inputs = unique(inputs))
}

# Checks each layer against the metadata: units, explicit zeros, sample and
# feature IDs. Returns the checked layers (numeric values) and the stops.
check_layers <- function(layers, md) {
  stops <- character(0); stop_if <- function(cond, msg) if (isTRUE(cond)) stops <<- c(stops, msg)
  notes <- list()
  for (nm in names(layers)) {
    L <- layers[[nm]]; d <- L$data; unit <- L$spec$unit
    miss <- setdiff(c("sample", "feature", "value"), names(d))
    if (length(miss)) { stop_if(TRUE, sprintf("Layer `%s` needs the columns sample, feature and value; missing: %s.", nm, q(miss))); next }
    stop_if(!"feature" %in% names(L$features), sprintf("Layer `%s`: its feature table has no `feature` column.", nm))
    nonnum <- d$value[!is.na(d$value) & !is_num(d$value)]
    stop_if(length(nonnum) > 0, sprintf("Layer `%s`: value '%s' is not a number.", nm, nonnum[1]))
    stop_if(anyNA(d$value), sprintf("Layer `%s`: %d empty value(s) (e.g. sample %s, feature %s). Write 0 for measured-and-none; a missing measurement is not allowed in a layer.",
                                    nm, sum(is.na(d$value)), d$sample[is.na(d$value)][1], d$feature[is.na(d$value)][1]))
    x <- suppressWarnings(as.numeric(d$value))
    if (unit == "count") {
      bad <- which(!is.na(x) & (x < 0 | x != round(x)))
      stop_if(length(bad) > 0, sprintf("Layer `%s` is declared unit count, but sample %s, feature %s has the value '%s', which is not a whole number 0 or more.", nm, d$sample[bad[1]], d$feature[bad[1]], d$value[bad[1]]))
    }
    if (unit == "proportion") {
      bad <- which(!is.na(x) & (x < 0 | x > 1))
      stop_if(length(bad) > 0, sprintf("Layer `%s` is declared unit proportion, but sample %s, feature %s has '%s', outside 0 to 1.", nm, d$sample[bad[1]], d$feature[bad[1]], d$value[bad[1]]))
    }
    key <- paste(d$sample, d$feature, sep = "\r")
    dup <- which(duplicated(key))
    stop_if(length(dup) > 0, sprintf("Layer `%s`: sample %s, feature %s appears more than once.", nm, d$sample[dup[1]], d$feature[dup[1]]))
    s <- unique(d$sample); f <- unique(d$feature)
    full <- outer(s, f, paste, sep = "\r")
    gone <- setdiff(full, key)
    if (length(gone)) {
      p <- strsplit(gone[1], "\r", fixed = TRUE)[[1]]
      stop_if(TRUE, sprintf("Layer `%s`: %d sample x feature row(s) are missing (e.g. sample %s, feature %s). Zeros must be written explicitly: a missing row is not read as zero.", nm, length(gone), p[1], p[2]))
    }
    unknown_s <- setdiff(s, md$sample)
    stop_if(length(unknown_s) > 0, sprintf("Layer `%s` has sample(s) not in the metadata: %s.", nm, paste(utils::head(unknown_s, 5), collapse = ", ")))
    unknown_f <- setdiff(f, L$features$feature)
    stop_if(length(unknown_f) > 0, sprintf("Layer `%s` has feature(s) not in its feature table: %s.", nm, paste(utils::head(unknown_f, 5), collapse = ", ")))
    absent <- setdiff(md$sample, s)
    if (length(absent)) notes[[length(notes) + 1]] <- data.frame(check = sprintf("layer %s", nm), status = "note",
      message = sprintf("%d sample(s) in the metadata have no data in layer `%s` and are left out of it: %s.", length(absent), nm, paste(absent, collapse = ", ")))
    layers[[nm]]$data$value <- x
  }
  list(layers = layers, stops = stops, notes = if (length(notes)) do.call(rbind, notes) else NULL)
}
