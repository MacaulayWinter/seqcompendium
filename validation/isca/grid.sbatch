#!/bin/bash
# One block of the v0.1.0 validation grid (CLAUDE.md D33, D34). Submit from
# the repository root, after setup_env.sbatch and fetch.sbatch have finished:
#   sbatchm --array=1-$(wc -l < "$VAL/tasks.tsv")%200 validation/isca/grid.sbatch
# Account and partition come from your own sbatch defaults or command line,
# never from this file.
#SBATCH --job-name=seqcomp-grid
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=24:00:00
#SBATCH --output=%x_%A_%a.log
set -euo pipefail
: "${VAL:?set VAL to the validation work folder (templates/, tasks.tsv, results/)}"
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "${SEQCOMP_ENV:-$PWD/.validation_env}"
export R_LIBS_USER="${SEQCOMP_ENV:-$PWD/.validation_env}/Rlib"
read -r S FIRST LAST < <(sed -n "${SLURM_ARRAY_TASK_ID}p" "$VAL/tasks.tsv")
Rscript validation/run.R "$S" "$FIRST" "$LAST" "$VAL/templates" "$VAL/results" ${FRESH:+fresh}
