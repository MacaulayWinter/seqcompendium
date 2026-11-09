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
if [ -d "$ENV_DIR/conda-meta" ]; then conda env update -p "$ENV_DIR" -f validation/grid/environment.yml
else conda env create -p "$ENV_DIR" -f validation/grid/environment.yml; fi
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "$ENV_DIR"
source validation/grid/isolate_env.sh   # only the environment's own libraries (D44)
# Every pkg-config entry in the environment must resolve, or a package's configure
# gets empty flags and fails later with a confusing error (D45).
bad=""; for pc in "$ENV_DIR"/lib/pkgconfig/*.pc "$ENV_DIR"/share/pkgconfig/*.pc; do
  [ -e "$pc" ] || continue; n=$(basename "$pc" .pc)
  pkg-config --cflags --libs --static "$n" >/dev/null 2>&1 || bad="$bad $n"
done
if [ -n "$bad" ]; then echo "pkg-config cannot resolve:$bad (a development package is missing from environment.yml)" >&2; exit 1; fi
export R_LIBS_USER="$ENV_DIR/Rlib"; mkdir -p "$R_LIBS_USER"
Rscript validation/grid/restore.R validation/renv-validation.lock
R CMD INSTALL --no-test-load .
Rscript -e 'library(seqcompendium); cat("seqcompendium", as.character(packageVersion("seqcompendium")), "ready\n")'
