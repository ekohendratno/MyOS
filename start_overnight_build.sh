#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
log="logs/overnight-$(date +%Y%m%d-%H%M%S).log"
./build.sh --no-dry-run >"$log" 2>&1 &
echo "$! $log"
sleep 2
tail -n 40 "$log"