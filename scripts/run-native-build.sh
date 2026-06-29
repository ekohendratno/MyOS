#!/usr/bin/env bash
set -euo pipefail

cd /home/srv/mixos
mkdir -p logs

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export MAKEFLAGS="-j$(nproc)"
export DEB_BUILD_OPTIONS="parallel=$(nproc)"

exec > >(tee logs/build-native.out.log) 2> >(tee logs/build-native.err.log >&2)

echo "Starting native WSL build at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Cache mode: incremental reuse"
./build.sh --no-dry-run
