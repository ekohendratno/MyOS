#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
grep -nE 'mmdebstrap|0000main\.sources|sources\.list\.d|Deb822|\.sources|packages\.list|lingmo_pkg\.list|zz-sources\.list' build.sh scripts/*.sh | head -120