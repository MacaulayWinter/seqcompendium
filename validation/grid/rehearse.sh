#!/usr/bin/env bash
# E7-M7 rehearsal on the Mac (CLAUDE.md D33): builds the grid environment in a
# clean Linux container exactly as setup_env.sh does on any machine, runs the main toy
# bundle, and compares its leads table with the reference container's.
# With POLLUTE=1 the shell first points CPATH, LIBRARY_PATH, LD_LIBRARY_PATH and
# PKG_CONFIG_PATH at a second conda prefix with another ICU (as a cluster's conda
# module can), to show the build and the run ignore it (D44).
#   [POLLUTE=1] bash validation/grid/rehearse.sh <work dir>
set -euo pipefail
W="$1"; mkdir -p "$W"
docker run --rm --memory=6g -e POLLUTE="${POLLUTE:-0}" -v "$PWD":/src:ro -v "$W":/work docker.io/condaforge/miniforge3:26.7.2-0 bash -c '
  set -euo pipefail; rm -rf /work/repo /work/toy /work/conda_out; cp -r /src /work/repo; cd /work/repo; rm -rf .validation_env
  if [ "$POLLUTE" = 1 ]; then
    [ -d /work/pollute ] || conda create -q -y -p /work/pollute -c conda-forge "icu=73" freetype fontconfig pkg-config >/dev/null
    export CPATH=/work/pollute/include LIBRARY_PATH=/work/pollute/lib LD_LIBRARY_PATH=/work/pollute/lib PKG_CONFIG_PATH=/work/pollute/lib/pkgconfig
    echo "polluted shell: CPATH=$CPATH LIBRARY_PATH=$LIBRARY_PATH PKG_CONFIG_PATH=$PKG_CONFIG_PATH; ICU there: $(ls /work/pollute/lib/libicuuc.so.* | head -1)"
  fi
  export SEQCOMP_ENV=/work/env SLURM_CPUS_PER_TASK=6
  bash validation/grid/setup_env.sh
  source "$(conda info --base)/etc/profile.d/conda.sh"; conda activate /work/env; ENV_DIR=/work/env; source validation/grid/isolate_env.sh
  Rscript -e "library(seqcompendium); make_toy_bundle(\"/work/toy\"); run_compendium(\"/work/toy\", \"/work/conda_out\")"'
# The reference: the engine container's packages, with this checkout's seqcompendium.
docker run --rm --memory=6g -v "$PWD":/src:ro -v "$W":/work seqcompendium:e7 bash -c 'mkdir -p /tmp/lib && R CMD INSTALL --no-test-load -l /tmp/lib /src >/dev/null 2>&1 && R_LIBS=/tmp/lib Rscript -e "unlink(c(\"/work/toy_ref\", \"/work/ref_out\"), recursive = TRUE); library(seqcompendium); make_toy_bundle(\"/work/toy_ref\"); run_compendium(\"/work/toy_ref\", \"/work/ref_out\")"'
docker run --rm -e POLLUTE="${POLLUTE:-0}" -v "$W":/work seqcompendium:e7 Rscript -e '
a <- read.csv("/work/conda_out/05_leads/leads.csv"); b <- read.csv("/work/ref_out/05_leads/leads.csv")
stopifnot(identical(a$lead_id, b$lead_id))
same <- identical(a$status, b$status) && identical(a$tier, b$tier)
num <- intersect(names(a)[vapply(a, is.numeric, TRUE)], c("effect", "ci_low", "ci_high", "p", "q", "p_floor", "min_detectable_effect"))
d <- max(vapply(num, function(k) { x <- a[[k]]; y <- b[[k]]; ok <- is.finite(x) & is.finite(y); if (!any(ok)) 0 else max(abs(x[ok] - y[ok]) / pmax(1e-300, abs(y[ok]))) }, 0))
nas <- all(vapply(num, function(k) identical(is.finite(a[[k]]), is.finite(b[[k]])), TRUE))
msg <- sprintf("E7-M7: status and tier identical: %s; largest relative difference %.3g; same missing values: %s; %s", same, d, nas, if (same && nas && d <= 1e-6) "PASS" else "FAIL")
cat(msg, "\n"); writeLines(c(msg, sprintf("pollute: %s; run at %s", Sys.getenv("POLLUTE", "0"), format(Sys.time(), "%Y-%m-%d %H:%M %Z"))), "/work/e7m7_summary.txt")'
# The evidence leaves the work folder the moment the run ends (it may be deleted later).
E="$W/evidence"; mkdir -p "$E"
cp "$W/conda_out/05_leads/leads.csv" "$E/leads_conda_env.csv"; cp "$W/ref_out/05_leads/leads.csv" "$E/leads_reference.csv"; cp "$W/e7m7_summary.txt" "$E/"
echo "evidence copied to $E"
