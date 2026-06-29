#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
log="logs/manual-$(date +%Y%m%d-%H%M%S).log"
( echo 'srV@1234' | sudo -S ./build.sh --no-dry-run >"$log" 2>&1; echo "done:$log" ) >/dev/null 2>&1 &
echo $!
sleep 1
ls -lt logs | head -5