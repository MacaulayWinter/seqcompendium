#!/bin/bash
# Builds the validation environment once (CLAUDE.md D33 E7-M7, D34h):
#   sbatchm validation/isca/setup_env.sbatch
#SBATCH --job-name=seqcomp-setup
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=08:00:00
#SBATCH --output=%x_%j.log
set -euo pipefail
bash validation/isca/setup_env.sh
