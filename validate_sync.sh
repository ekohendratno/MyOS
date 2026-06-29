#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
perl -pi -e 's/\r$//' build.sh scripts/build-lingmo-source.sh config/mixos.conf
bash -n build.sh
bash -n scripts/build-lingmo-source.sh
grep -nE 'WINDOWS_OUTPUT_DIR|Moved ISO' config/mixos.conf build.sh
tail -n 3 build.sh | od -An -tx1