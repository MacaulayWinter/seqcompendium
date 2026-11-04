#!/bin/bash
# Chooses and fetches the templates and fits the simulator to each
# (PREREGISTRATION.md §2; CLAUDE.md D36):
#   sbatchm validation/isca/fetch.sbatch
#SBATCH --job-name=seqcomp-fetch
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=06:00:00
#SBATCH --output=%x_%j.log
set -euo pipefail
: "${VAL:?set VAL to the validation work folder}"
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "${SEQCOMP_ENV:-$PWD/.validation_env}"
export R_LIBS_USER="${SEQCOMP_ENV:-$PWD/.validation_env}/Rlib"
export EXPERIMENT_HUB_CACHE="$VAL/hubcache"
Rscript validation/fetch_templates.R "$VAL/templates"
Rscript validation/isca/make_tasks.R "$VAL" "${RUNS_PER_TASK:-2}"
