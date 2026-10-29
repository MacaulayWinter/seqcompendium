#!/usr/bin/env bash
# E1-M15: the repository holds no data files. Test data are invented by
# make_toy_bundle() at test time and never committed.
set -euo pipefail
# Allowed: the methods catalogue (a table of methods from the literature scan,
# not data; CLAUDE.md D13).
hits=$(git ls-files | grep -Ei '\.(tsv|csv|txt\.gz|fastq|fq|fasta|fa|fna|bam|sam|biom|rds|rda|rdata|xlsx?|h5|nwk)(\.gz)?$' | grep -vx 'inst/catalogue/methods.csv' || true)
if [ -n "$hits" ]; then echo "Data files found in the repository:"; echo "$hits"; exit 1; fi
echo "No data files in the repository."
