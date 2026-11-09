#!/usr/bin/env bash
# prepare_ve7b.sh: downloads the data V-E7b needs (CLAUDE.md D41, D42): the
# Nearing et al. 2022 data sets (figshare 14531724) and the paper's Source Data.
# Keeps only the six tables V-E7b reads (the rarefied tables only for their sample lists) and checks every download's checksum.
# Needs internet; run once, from the repository root:
#   VAL=<work folder> bash validation/grid/prepare_ve7b.sh
# Afterwards: $VAL/nearing/Hackathon/Studies/<data set>/ and $VAL/nearing/source_data_all.xlsx
set -euo pipefail
: "${VAL:?set VAL}"; N="$VAL/nearing"; mkdir -p "$N/raw"
get() {  # url, file, sha256
  [ -s "$N/raw/$2" ] || curl -fL --retry 3 -o "$N/raw/$2" "$1"
  echo "$3  $N/raw/$2" | sha256sum -c - 2>/dev/null || echo "$3  $N/raw/$2" | shasum -a 256 -c -
}
get https://ndownloader.figshare.com/files/27857901 DA_COMPARE_DATA_21_03_08.tar.gz 53337642e26735fc138ed17089f6a467135719413bafbd1f9e5bff048c164b84
get "https://static-content.springer.com/esm/art%3A10.1038%2Fs41467-022-28034-z/MediaObjects/41467_2022_28034_MOESM6_ESM.zip" MOESM6_ESM.zip 22f1a5319385852a5f5ac318d0ab876ae2e35148918e122054e2114515c8c1a9
tar -xzf "$N/raw/DA_COMPARE_DATA_21_03_08.tar.gz" -C "$N" \
  Hackathon/Studies/ArcticFireSoils/ArcticFireSoils_ASVs_table.tsv Hackathon/Studies/ArcticFireSoils/ArcticFireSoils_meta.tsv \
  Hackathon/Studies/ArcticFireSoils/ArcticFireSoils_ASVs_table_rare.tsv \
  Hackathon/Studies/ArcticFreshwaters/ArcticFreshwaters_ASVs_table.tsv Hackathon/Studies/ArcticFreshwaters/ArcticFreshwaters_meta.tsv \
  Hackathon/Studies/ArcticFreshwaters/ArcticFreshwaters_ASVs_table_rare.tsv
unzip -o -q "$N/raw/MOESM6_ESM.zip" source_data_all.xlsx -d "$N"
echo "3e7d420ca826bbee733c051384c516cfeb4947f614739cde500e085da1da42c8  $N/source_data_all.xlsx" | sha256sum -c - 2>/dev/null || echo "3e7d420ca826bbee733c051384c516cfeb4947f614739cde500e085da1da42c8  $N/source_data_all.xlsx" | shasum -a 256 -c -
echo "V-E7b data ready in $N (the raw downloads in $N/raw can be deleted)"
