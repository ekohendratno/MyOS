#!/usr/bin/env bash
set -euo pipefail
ps -ef | grep -E 'build.sh|build-lingmo-source|mmdebstrap|debootstrap|lb build' | grep -v grep || true