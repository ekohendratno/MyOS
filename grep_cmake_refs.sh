#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
for path in upstream/LingmoOS/shell32/lingmo-shell upstream/LingmoOS/Build_Pkgs/auto upstream/LingmoOS/Build_Pkgs/.build_deb_lingmo/lingmo-shell upstream/LingmoOS/Build_Pkgs/.build_deb_lingmo/lingmo-kwin-plugins-roundedwindow; do
  [ -e "$path" ] || continue
  echo "== $path =="
  grep -RniE 'KDELibs4Support|KWinEffects|lingmo-kwin-plugins-roundedwindow' "$path" | sed -n '1,120p' || true
done