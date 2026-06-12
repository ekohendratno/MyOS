#!/bin/bash
for repo in lingmo-core lingmo-dock lingmo-settings lingmo-statusbar LingmoUI; do
  echo "=== Checking $repo ==="
  rm -rf /tmp/"$repo" 2>/dev/null
  git clone --depth 1 "https://github.com/LingmoOS/$repo.git" /tmp/"$repo" 2>&1 | tail -1
  echo "Binary packages:"
  grep '^Package:' /tmp/"$repo"/debian/control
  echo "Build-Depends:"
  grep -A 50 '^Build-Depends:' /tmp/"$repo"/debian/control | head -51 | grep -E '^\s|^Build-Depends'
  echo ""
  rm -rf /tmp/"$repo" 2>/dev/null
done
echo "DONE"
