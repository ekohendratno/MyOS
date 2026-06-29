#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
log="logs/source-force-$(date +%Y%m%d-%H%M%S).log"
( scripts/build-lingmo-source.sh --force >"$log" 2>&1 && echo "SOURCE_OK" >>"$log" && ./build.sh --no-dry-run >>"$log" 2>&1 && echo "ISO_OK" >>"$log" ) &
echo "$! $log"
sleep 2
tail -n 60 "$log"