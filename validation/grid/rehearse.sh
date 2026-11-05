#!/usr/bin/env bash
# E7-M7 rehearsal on the Mac (CLAUDE.md D33): builds the grid environment in a
# clean Linux container exactly as setup_env.sh does on any machine, runs the main toy
# bundle, and compares its leads table with the reference container's.
#   bash validation/grid/rehearse.sh <work dir>
set -euo pipefail
W="$1"; mkdir -p "$W"
docker run --rm -v "$PWD":/src:ro -v "$W":/work docker.io/condaforge/miniforge3:26.7.2-0 bash -c '
  set -euo pipefail; cp -r /src /work/repo; cd /work/repo; rm -rf .validation_env
  export SEQCOMP_ENV=/work/env SLURM_CPUS_PER_TASK=6
  bash validation/grid/setup_env.sh
  source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate /work/env; export R_LIBS_USER=/work/env/Rlib
  Rscript -e "library(seqcompendium); make_toy_bundle(\"/work/toy\"); run_compendium(\"/work/toy\", \"/work/conda_out\")"'
docker run --rm -v "$W":/work seqcompendium:e7 Rscript -e 'library(seqcompendium); make_toy_bundle("/work/toy_ref"); run_compendium("/work/toy_ref", "/work/ref_out")'
docker run --rm -v "$W":/work seqcompendium:e7 Rscript -e '
a <- read.csv("/work/conda_out/05_leads/leads.csv"); b <- read.csv("/work/ref_out/05_leads/leads.csv")
stopifnot(identical(a$lead_id, b$lead_id))
same <- identical(a$status, b$status) && identical(a$tier, b$tier)
num <- intersect(names(a)[vapply(a, is.numeric, TRUE)], c("effect", "ci_low", "ci_high", "p", "q", "p_floor", "min_detectable_effect"))
d <- max(vapply(num, function(k) { x <- a[[k]]; y <- b[[k]]; ok <- is.finite(x) & is.finite(y); if (!any(ok)) 0 else max(abs(x[ok] - y[ok]) / pmax(1e-300, abs(y[ok]))) }, 0))
nas <- all(vapply(num, function(k) identical(is.finite(a[[k]]), is.finite(b[[k]])), TRUE))
cat(sprintf("E7-M7: status and tier identical: %s; largest relative difference %.3g; same missing values: %s; %s\n", same, d, nas, if (same && nas && d <= 1e-6) "PASS" else "FAIL"))'
