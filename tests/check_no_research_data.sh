#!/usr/bin/env bash
# E1-M15: the repository holds no data files. Test data are invented by
# make_toy_bundle() at test time and never committed.
set -euo pipefail
# Allowed: the methods catalogue (a table of methods from the literature scan,
# not data; CLAUDE.md D13), and validation results tables (marks, scores, leads)
# under validation/results/<release>/, as PREREGISTRATION.md section 7 requires
# (CLAUDE.md D54). Only plain .csv/.tsv there, each under 1 MB, so no input data
# or saved R objects can slip in that way.
results_re='^validation/results/v[0-9]+\.[0-9]+\.[0-9]+/.+\.(csv|tsv)$'
hits=$(git ls-files | grep -Ei '\.(tsv|csv|txt\.gz|fastq|fq|fasta|fa|fna|bam|sam|biom|rds|rda|rdata|xlsx?|h5|nwk)(\.gz)?$' | grep -vx 'inst/catalogue/methods.csv' | grep -Ev "$results_re" || true)
if [ -n "$hits" ]; then echo "Data files found in the repository:"; echo "$hits"; exit 1; fi
big=$(git ls-files | grep -E "$results_re" | while read -r f; do [ -f "$f" ] && [ "$(wc -c < "$f")" -gt 1048576 ] && echo "$f"; done || true)
if [ -n "$big" ]; then echo "Results tables over 1 MB (too big to be a results table):"; echo "$big"; exit 1; fi
echo "No data files in the repository."
