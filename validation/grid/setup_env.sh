#!/usr/bin/env bash
# Builds the validation environment on any Linux or macOS machine (CLAUDE.md D33
# E7-M7, D34h, D39): its own conda R and every R package pinned, so nothing
# preinstalled on a shared machine is used.
# Run once, as a job, from the repository root:
#   VAL=<work folder> bash validation/grid/setup_env.sh   (once; as a job on a cluster)
# Creates the conda environment, restores every R package of
# validation/renv-validation.lock (renv.lock plus the two template packages)
# from source at the 2026-10-14 snapshot, and
# fails unless every installed version equals the locks.
set -euo pipefail
source validation/grid/need_conda.sh   # stops here, with a message, if conda is not on PATH
ENV_DIR="${SEQCOMP_ENV:-${VAL:?set VAL}/env}"
if [ ! -d "$ENV_DIR" ]; then conda env create -p "$ENV_DIR" -f validation/grid/environment.yml; fi
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "$ENV_DIR"
export R_LIBS_USER="$ENV_DIR/Rlib"; mkdir -p "$R_LIBS_USER"
Rscript validation/grid/restore.R validation/renv-validation.lock
R CMD INSTALL --no-test-load .
Rscript -e 'library(seqcompendium); cat("seqcompendium", as.character(packageVersion("seqcompendium")), "ready\n")'
