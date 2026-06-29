#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
log="logs/root-$(date +%Y%m%d-%H%M%S).log"
./build.sh --no-dry-run >"$log" 2>&1 &
echo $!
sleep 2
ls -lt logs | head -5