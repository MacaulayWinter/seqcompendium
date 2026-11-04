# Restores the locks from source (P3M's Linux binaries are built for Ubuntu,
# not for ISCA's system), then checks every version against the locks.
locks <- commandArgs(trailingOnly = TRUE)
s <- "2026-10-14"
repos <- c(CRAN = sprintf("https://p3m.dev/cran/%s", s),
           BioCsoft = sprintf("https://p3m.dev/bioconductor/%s/packages/3.23/bioc", s),
           BioCann = sprintf("https://p3m.dev/bioconductor/%s/packages/3.23/data/annotation", s),
           BioCexp = sprintf("https://p3m.dev/bioconductor/%s/packages/3.23/data/experiment", s))
options(repos = repos, Ncpus = as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "4")))
lib <- Sys.getenv("R_LIBS_USER"); .libPaths(c(lib, .libPaths()))
for (p in c("renv", "jsonlite")) if (!requireNamespace(p, quietly = TRUE)) install.packages(p, lib = lib)   # restore then puts the locked versions in place
want <- list()
for (lf in locks) {
  j <- jsonlite::read_json(lf)
  j$R$Repositories <- lapply(names(repos), function(n) list(Name = n, URL = repos[[n]]))
  for (p in names(j$Packages)) if (identical(j$Packages[[p]]$Source, "Repository")) j$Packages[[p]]$Repository <- NULL
  tmp <- tempfile(fileext = ".lock"); jsonlite::write_json(j, tmp, auto_unbox = TRUE, pretty = TRUE)
  options(renv.config.ppm.enabled = FALSE)
  renv::restore(lockfile = tmp, library = lib, prompt = FALSE, rebuild = FALSE)
  for (p in names(j$Packages)) want[[p]] <- j$Packages[[p]]$Version
}
got <- vapply(names(want), function(p) tryCatch(as.character(utils::packageVersion(p, lib.loc = lib)), error = function(e) "missing"), "")
bad <- names(want)[got != unlist(want)]
bad <- setdiff(bad, c("base", "compiler", "graphics", "grDevices", "grid", "methods", "parallel", "splines", "stats", "stats4", "tcltk", "tools", "utils"))
if (length(bad)) stop("Versions differ from the locks: ", paste(sprintf("%s (want %s, got %s)", bad, unlist(want)[bad], got[bad]), collapse = "; "))
cat(length(want), "packages, every version equal to the locks; R", as.character(getRversion()), "\n")
