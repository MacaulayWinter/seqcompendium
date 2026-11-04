#!/bin/bash
# V-E6, the residual checks (CLAUDE.md D37). Submit from the repository root:
#   sbatchm --array=1-8 validation/isca/ve6.sbatch
#SBATCH --job-name=seqcomp-ve6
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=02:00:00
#SBATCH --output=%x_%A_%a.log
set -euo pipefail
: "${VAL:?set VAL to the validation work folder}"
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "${SEQCOMP_ENV:-$PWD/.validation_env}"
export R_LIBS_USER="${SEQCOMP_ENV:-$PWD/.validation_env}/Rlib"
read -r FAM FIRST LAST < <(sed -n "${SLURM_ARRAY_TASK_ID}p" "$VAL/tasks_ve6.tsv")
Rscript validation/ve6_diagnostics.R "$FAM" "$FIRST" "$LAST" "$VAL/results"
