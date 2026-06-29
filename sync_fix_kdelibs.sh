#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
cp /mnt/c/MyOS/scripts/build-lingmo-source.sh scripts/build-lingmo-source.sh
chmod +x scripts/build-lingmo-source.sh
bash -n scripts/build-lingmo-source.sh
# Run only the same dependency patch logic by sourcing functions safely is awkward;
# apply the exact removal now to verify the control file shape before next build.
sed -Ei -e '/^[[:space:]]*libkf5kdelibs4support-dev([[:space:]]*\([^)]*\))?,?[[:space:]]*$/d' upstream/LingmoOS/shell32/lingmo-shell/debian/control
if grep -n 'libkf5kdelibs4support-dev' upstream/LingmoOS/shell32/lingmo-shell/debian/control; then
  echo 'still present' >&2
  exit 1
fi
grep -nE 'libkaccounts|libksysguard|plasma-workspace|kdelibs4support|patch_source_tree_controls' scripts/build-lingmo-source.sh upstream/LingmoOS/shell32/lingmo-shell/debian/control | sed -n '1,120p' || true