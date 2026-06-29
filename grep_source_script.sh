#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
grep -nE 'mmdebstrap|debootstrap|sources\.list' scripts/build-lingmo-source.sh