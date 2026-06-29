#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
for d in lingmo-shell lingmo-kwin-plugins-roundedwindow; do
  echo "== $d cmake errors =="
  for f in \
    "upstream/LingmoOS/Build_Pkgs/.build_deb_lingmo/$d/obj-x86_64-linux-gnu/CMakeCache.txt" \
    "upstream/LingmoOS/Build_Pkgs/.build_deb_lingmo/$d/obj-x86_64-linux-gnu/CMakeFiles/CMakeError.log" \
    "upstream/LingmoOS/Build_Pkgs/.build_deb_lingmo/$d/obj-x86_64-linux-gnu/CMakeFiles/CMakeOutput.log"; do
    [ -f "$f" ] || continue
    echo "--- $f"
    grep -nE 'NOTFOUND|Could NOT find|CMake Error|required package|Config\.cmake|not found|No package' "$f" | sed -n '1,160p' || true
  done
done