#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/home/srv/mixos}"
cd "${ROOT_DIR}"

mkdir -p logs
log="logs/overnight-chain-$(date +%Y%m%d-%H%M%S).log"

nohup bash -lc '
  set -euo pipefail
  cd /home/srv/mixos
  scripts/build-lingmo-source.sh --force
  echo SOURCE_OK
  ./build.sh --no-dry-run
  echo ISO_OK
' >"${log}" 2>&1 < /dev/null &

pid="$!"
printf 'PID=%s\nLOG=%s\n' "${pid}" "${ROOT_DIR}/${log}"
