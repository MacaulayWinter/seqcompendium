#!/usr/bin/env bash
# run_task.sh: runs ONE numbered task of the validation grid, on any machine
# (CLAUDE.md D39). Every launcher (run_local.sh, the SLURM example, or any
# scheduler that can loop over numbers) only calls this.
#   VAL=<work folder> bash validation/grid/run_task.sh <task number>
# Tasks 1..N are the lines of $VAL/tasks.tsv (grid runs), then the lines of
# $VAL/tasks_ve6.tsv. Uses the environment built by setup_env.sh.
set -euo pipefail
source validation/grid/need_conda.sh   # stops here, with a message, if conda is not on PATH
: "${VAL:?set VAL to the validation work folder (templates/, tasks.tsv, results/)}"
i="$1"; ENV_DIR="${SEQCOMP_ENV:-$VAL/env}"
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate "$ENV_DIR"
source validation/grid/isolate_env.sh   # only the environment's own libraries (D44)
export R_LIBS_USER="$ENV_DIR/Rlib" OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
n=$(wc -l < "$VAL/tasks.tsv")
if [ "$i" -le "$n" ]; then
  read -r S FIRST LAST < <(sed -n "${i}p" "$VAL/tasks.tsv")
  Rscript validation/run.R "$S" "$FIRST" "$LAST" "$VAL/templates" "$VAL/results" ${FRESH:+fresh}
else
  read -r FAM FIRST LAST < <(sed -n "$((i - n))p" "$VAL/tasks_ve6.tsv")
  Rscript validation/ve6_diagnostics.R "$FAM" "$FIRST" "$LAST" "$VAL/results"
fi
