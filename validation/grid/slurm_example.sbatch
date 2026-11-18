#!/bin/bash
# An EXAMPLE launcher for SLURM clusters (CLAUDE.md D39). Nothing in the grid
# depends on SLURM: this file only calls run_task.sh once per array index.
# Account, partition and mail settings come from your own sbatch command line
# or defaults, never from this file. Submit from the repository root:
#   VAL=<work folder> sbatch --export=ALL --array=1-<N>%<max at once> validation/grid/slurm_example.sbatch
# (N is printed by make_tasks.R.) Other schedulers: run run_task.sh with each
# number 1..N however they allow (PBS/SGE array jobs, a cloud batch service, a loop).
#SBATCH --job-name=seqcomp-grid
#SBATCH --cpus-per-task=1
#SBATCH --mem=6G
#SBATCH --time=24:00:00
#SBATCH --output=seqcomp-grid_%A_%a.log
set -euo pipefail
source validation/grid/need_conda.sh   # stops here, with a message, if conda is not on PATH
bash validation/grid/run_task.sh "$SLURM_ARRAY_TASK_ID"
