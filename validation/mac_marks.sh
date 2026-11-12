#!/usr/bin/env bash
# mac_marks.sh: run one phase of validation/mac_marks.R in the validation container,
# with this checkout's engine installed, one container at a time, 6 GB memory.
#
#   bash validation/mac_marks.sh <phase> /path/to/work
#
# /path/to/work must hold templates/ (from fetch_templates.R); results go to
# /path/to/work/mac_marks/. Run from the repository root.
set -euo pipefail
phase="$1"; W="$(cd "$2" && pwd)"
# A file named PAUSE in the work folder holds the next phase back (the Mac runs one heavy container at a time).
while [ -e "$W/PAUSE" ]; do sleep 30; done
docker run --rm --memory=6g -v "$PWD":/src:ro -v "$W":/work seqcompendium-validation:e7 bash -c "
  set -e; mkdir -p /tmp/lib && R CMD INSTALL --no-test-load -l /tmp/lib /src >/dev/null 2>&1
  R_LIBS=/tmp/lib Rscript /src/validation/mac_marks.R $phase /work/templates /work/mac_marks"
