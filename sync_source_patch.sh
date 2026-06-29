#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
cp /mnt/c/MyOS/scripts/build-lingmo-source.sh scripts/build-lingmo-source.sh
chmod +x scripts/build-lingmo-source.sh
bash -n scripts/build-lingmo-source.sh
grep -nE 'libkdecorations|patch_auto_package_controls' scripts/build-lingmo-source.sh