#!/usr/bin/env bash
# prepare.sh: chooses, downloads and fits the templates (PREREGISTRATION.md §2),
# then writes the task list (CLAUDE.md D36, D39). Needs internet; run once.
#   VAL=<work folder> RUNS_PER_TASK=2 bash validation/grid/prepare.sh
set -euo pipefail
source validation/grid/need_conda.sh   # stops here, with a message, if conda is not on PATH
: "${VAL:?set VAL}"; ENV_DIR="${SEQCOMP_ENV:-$VAL/env}"
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "$ENV_DIR"
export R_LIBS_USER="$ENV_DIR/Rlib" EXPERIMENT_HUB_CACHE="$VAL/hubcache"
Rscript validation/fetch_templates.R "$VAL/templates"
Rscript validation/grid/make_tasks.R "$VAL" "${RUNS_PER_TASK:-2}"
