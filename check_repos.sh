#!/bin/bash
for repo in lingmo-dock lingmo-settings lingmo-statusbar LingmoUI; do
  echo "=== Checking $repo ==="
  rm -rf /tmp/"$repo" 2>/dev/null
  git clone --depth 1 "https://github.com/LingmoOS/$repo.git" /tmp/"$repo" 2>&1 | tail -1
  grep -i 'qt6\|Qt6' /tmp/"$repo"/CMakeLists.txt 2>/dev/null | head -3
  grep 'Build-Depends' /tmp/"$repo"/debian/control 2>/dev/null | head -3
  rm -rf /tmp/"$repo" 2>/dev/null
done
echo "DONE"
