#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
log="logs/source-force-$(date +%Y%m%d-%H%M%S).log"
( scripts/build-lingmo-source.sh --force; echo "SOURCE_BUILD_EXIT=0" ) >"$log" 2>&1 || echo "SOURCE_BUILD_EXIT=$?" >>"$log"
echo "$log"
tail -n 120 "$log"