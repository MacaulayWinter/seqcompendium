#!/usr/bin/env bash
# install_engine.sh: installs this checkout's seqcompendium into its own folder,
# leaving the environment's library (and any task running from it) untouched
# (CLAUDE.md D49). Tasks use it when SEQCOMP_ENGINE_LIB points at that folder.
#   VAL=<work folder> bash validation/grid/install_engine.sh <folder>
set -euo pipefail
source validation/grid/need_conda.sh   # stops here, with a message, if conda is not on PATH
: "${VAL:?set VAL}"; ENV_DIR="${SEQCOMP_ENV:-$VAL/env}"; LIB="${1:?give the folder to install into}"
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "$ENV_DIR"
source validation/grid/isolate_env.sh   # only the environment's own libraries (D44)
mkdir -p "$LIB"; R CMD INSTALL --no-test-load -l "$LIB" .
R_LIBS="$LIB" Rscript -e 'library(seqcompendium); cat("seqcompendium", as.character(packageVersion("seqcompendium")), "from", find.package("seqcompendium"), "ready\n")'
