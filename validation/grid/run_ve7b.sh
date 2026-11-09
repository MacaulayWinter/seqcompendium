#!/usr/bin/env bash
# run_ve7b.sh: runs ONE V-E7b task on any machine (CLAUDE.md D41, D42):
# task 1 = ArcticFireSoils, task 2 = ArcticFreshwaters. Uses the environment
# built by setup_env.sh and the data fetched by prepare_ve7b.sh.
#   VAL=<work folder> bash validation/grid/run_ve7b.sh <1|2>
set -euo pipefail
source validation/grid/need_conda.sh   # stops here, with a message, if conda is not on PATH
: "${VAL:?set VAL}"; ENV_DIR="${SEQCOMP_ENV:-$VAL/env}"
case "$1" in 1) D=ArcticFireSoils ;; 2) D=ArcticFreshwaters ;; *) echo "task must be 1 or 2" >&2; exit 2 ;; esac
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "$ENV_DIR"
source validation/grid/isolate_env.sh   # only the environment's own libraries (D44)
export R_LIBS_USER="$ENV_DIR/Rlib" OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
Rscript validation/ve7b_nearing.R "$VAL/nearing/Hackathon/Studies" "$VAL/nearing/source_data_all.xlsx" "$VAL/results_ve7b" "$D"
