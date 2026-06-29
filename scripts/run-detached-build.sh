#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p logs

for mount_path in \
  builds/work-amd64/chroot/dev/pts \
  builds/work-amd64/chroot/proc \
  builds/work-amd64/chroot/sys \
  builds/work-amd64/chroot/dev
do
  if mountpoint -q "$mount_path"; then
    umount -lf "$mount_path" || true
  fi
done

log="logs/auto-build-detached-$(date +%Y%m%d-%H%M%S).log"
setsid -f bash -lc "cd '$ROOT' && stdbuf -oL -eL ./build.sh --no-dry-run >'$ROOT/$log' 2>&1" </dev/null >/dev/null 2>&1
sleep 1
pid="$(pgrep -af './build.sh --no-dry-run' | awk 'NR==1{print $1}')"
printf '%s %s\n' "${pid:-unknown}" "$log"
