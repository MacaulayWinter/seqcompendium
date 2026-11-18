# need_conda.sh: sourced by every grid script that uses conda (CLAUDE.md D39, D43).
# Stops before anything else is done when conda is not on PATH.
if ! command -v conda >/dev/null 2>&1; then
  echo "conda not found: load or install conda (e.g. Miniforge) in this shell before running or submitting; jobs inherit it with --export=ALL" >&2
  exit 1
fi
