#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
log="logs/overnight-chain-$(date +%Y%m%d-%H%M%S).log"
nohup bash -lc "cd /home/srv/mixos && scripts/build-lingmo-source.sh --force && echo SOURCE_OK && ./build.sh --no-dry-run && echo ISO_OK" >"$log" 2>&1 < /dev/null &
echo "$! $log"
sleep 3
tail -n 60 "$log"