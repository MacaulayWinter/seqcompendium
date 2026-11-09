#!/bin/bash
# An EXAMPLE SLURM launcher for V-E7b (CLAUDE.md D41, D42): two tasks, one per
# Nearing data set, run at the same time. Account, partition and mail settings
# come from your own sbatch command line or defaults, never from this file.
# Submit from the repository root:
#   VAL=<work folder> sbatch --export=ALL --array=1-2 validation/grid/slurm_ve7b_example.sbatch
# One engine run on either data set is expected to take tens of hours (most of
# it the override check's 100 simulated data sets), hence the long time limit;
# lower it if your partition's maximum is shorter, and rerun any task that times out.
#SBATCH --job-name=seqcomp-ve7b
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=7-00:00:00
#SBATCH --output=seqcomp-ve7b_%A_%a.log
set -euo pipefail
source validation/grid/need_conda.sh   # stops here, with a message, if conda is not on PATH
bash validation/grid/run_ve7b.sh "$SLURM_ARRAY_TASK_ID"
