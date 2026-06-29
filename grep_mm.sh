#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
grep -nE 'sources\.list|mmdebstrap|Deb822|Types:|Type:' build.sh scripts/*.sh