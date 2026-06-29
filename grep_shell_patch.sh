#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
grep -nE 'LINGMO_SOURCE_EXCLUDE_DIRS|LINGMO_SOURCE_REQUIRED_DEBS|Missing required Lingmo|did not produce required' scripts/build-lingmo-source.sh build.sh || true