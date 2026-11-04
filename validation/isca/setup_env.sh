#!/usr/bin/env bash
# Builds the validation environment on ISCA (CLAUDE.md D33 E7-M7, D34h).
# Run once, as a job, from the repository root:
#   sbatchm validation/isca/setup_env.sbatch
# Creates the conda environment, restores every R package of
# validation/renv-validation.lock (renv.lock plus the two template packages)
# from source at the 2026-10-14 snapshot, and
# fails unless every installed version equals the locks.
set -euo pipefail
ENV_DIR="${SEQCOMP_ENV:-$PWD/.validation_env}"
if [ ! -d "$ENV_DIR" ]; then conda env create -p "$ENV_DIR" -f validation/isca/environment.yml; fi
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "$ENV_DIR"
export R_LIBS_USER="$ENV_DIR/Rlib"; mkdir -p "$R_LIBS_USER"
Rscript validation/isca/restore.R validation/renv-validation.lock
R CMD INSTALL --no-test-load .
Rscript -e 'library(seqcompendium); cat("seqcompendium", as.character(packageVersion("seqcompendium")), "ready\n")'
