#!/usr/bin/env bash
set -euo pipefail
apt-cache search 'kaccounts|kdelibs4support|sysguard|plasma-workspace.*dev|workspace-dev' | sed -n '1,160p'
cd /home/srv/mixos
for f in upstream/LingmoOS/Build_Pkgs/auto/lingmo-shell/debian/control upstream/LingmoOS/shell32/lingmo-shell/debian/control; do
  [ -f "$f" ] || continue
  echo "--- $f"
  grep -nE 'libkaccounts-dev|libkf5kdelibs4support-dev|libkf5sysguard-dev|lingmo-workspace-dev|plasma-workspace-dev|libplasma-dev' "$f" || true
done