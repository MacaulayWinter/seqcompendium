#!/usr/bin/env Rscript
# Builds renv.lock (CLAUDE.md D3, D12): installs every package the engine
# needs from the dated snapshots, and DivNet from GitHub at a fixed commit,
# then records the exact versions. Run inside the base image only, e.g.
#   docker run --rm -v "$PWD":/src -w /src <base image> Rscript inst/scripts/make_lockfile.R
# The snapshot date and the DivNet commit are the only two pins; everything
# else follows from them.
SNAPSHOT <- "2026-10-14"
DIVNET <- "adw96/DivNet@57fbdc2bd47b715965cb71be2c48e7cfa12c494c"   # 2026-06-16
repos <- c(CRAN = sprintf("https://p3m.dev/cran/__linux__/noble/%s", SNAPSHOT),
           BioCsoft = sprintf("https://p3m.dev/bioconductor/__linux__/noble/%s/packages/3.23/bioc", SNAPSHOT),
           BioCann = sprintf("https://p3m.dev/bioconductor/__linux__/noble/%s/packages/3.23/data/annotation", SNAPSHOT),
           BioCexp = sprintf("https://p3m.dev/bioconductor/__linux__/noble/%s/packages/3.23/data/experiment", SNAPSHOT))
options(repos = repos, Ncpus = 4)
pkgs <- c(
  # CRAN
  "yaml", "iNEXT", "ggplot2", "digest", "vegan", "MicrobiomeStat", "mvabund", "logistf", "DHARMa", "MASS", "pscl", "MIDASim", "glmmTMB", "geepack", "lme4", "lmerTest",
  "rmarkdown", "testthat", "pkgload", "remotes", "renv",
  # Bioconductor 3.23
  "DESeq2", "ANCOMBC", "microbiome", "ALDEx2", "decontam", "fgsea", "limma", "lefser", "SummarizedExperiment", "TreeSummarizedExperiment")
install.packages(pkgs)
miss <- pkgs[!vapply(pkgs, function(p) tryCatch({ loadNamespace(p); TRUE }, error = function(e) { message(p, ": ", conditionMessage(e)); FALSE }), TRUE)]
if (length(miss)) stop("Not installed: ", paste(miss, collapse = ", "))
remotes::install_github(DIVNET, upgrade = "never", dependencies = TRUE)
library(DivNet)
lib <- .libPaths()[1]
renv::snapshot(project = tempfile("lock"), lockfile = "renv.lock", library = .libPaths(), type = "all", prompt = FALSE, force = TRUE,
               repos = repos)
cat("renv.lock written:", length(jsonlite::read_json("renv.lock")$Packages), "packages\n")
