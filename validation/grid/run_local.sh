#!/usr/bin/env bash
# run_local.sh: the whole grid (or a range of it) on one machine, J tasks at
# a time (CLAUDE.md D39). Finished tasks are skipped, so it can be restarted.
#   VAL=<work folder> J=4 bash validation/grid/run_local.sh [first] [last]
set -euo pipefail
: "${VAL:?set VAL}"; J="${J:-2}"
N=$(( $(wc -l < "$VAL/tasks.tsv") + $(wc -l < "$VAL/tasks_ve6.tsv") ))
mkdir -p "$VAL/logs"
seq "${1:-1}" "${2:-$N}" | xargs -P "$J" -I{} bash -c '[ -e "$VAL/logs/{}.done" ] || { bash validation/grid/run_task.sh {} > "$VAL/logs/{}.log" 2>&1 && touch "$VAL/logs/{}.done"; }'
echo "done: $(ls "$VAL/logs" | grep -c '\.done$') of $N tasks"
