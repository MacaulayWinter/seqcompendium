#!/usr/bin/env bash
# E2-M5: the pre-registration cannot change silently. Its checksum is
# recorded in validation/PREREGISTRATION.sha256; a change to the file without
# a matching change to the checksum fails CI, so every change to a mark shows
# up in a pull request (and needs the user's approval, logged in CLAUDE.md).
set -euo pipefail
cd "$(dirname "$0")/.."
if shasum -a 256 -c validation/PREREGISTRATION.sha256 >/dev/null 2>&1 || sha256sum -c validation/PREREGISTRATION.sha256 >/dev/null 2>&1; then
  echo "Pre-registration unchanged."
else
  echo "validation/PREREGISTRATION.md does not match its recorded checksum. A pass mark was changed: record the user's approval in CLAUDE.md and update validation/PREREGISTRATION.sha256."
  exit 1
fi
