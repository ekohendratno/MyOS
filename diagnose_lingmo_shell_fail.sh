#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
printf '== failure lines ==\n'
grep -nE 'Failed to build|Build failed|Some packages failed|Error:|error:|make\[[0-9]+\]: \*\*\*|dpkg-buildpackage: error' logs/overnight-chain-20260617-063647.log | tail -n 180 || true
printf '== shell artifacts ==\n'
find upstream/LingmoOS/Build_Pkgs/.build_deb_lingmo -maxdepth 1 -type f -name '*lingmo-shell*' -printf '%f\n' | sort || true
printf '== deb artifacts important ==\n'
find upstream/LingmoOS/Build_Pkgs/.build_deb_lingmo -maxdepth 1 -type f -name '*.deb' -printf '%f\n' | sort | grep -Ei 'lingmo-shell|lingmo-dock|lingmo-launcher|lingmo-statusbar|lingmo-kwin|lingmo-watchdog' || true
printf '== dirs around shell ==\n'
find upstream/LingmoOS/Build_Pkgs/.build_deb_lingmo -maxdepth 1 -type d -printf '%f\n' | sort | grep -Ei 'shell|dock|launcher|status|kwin|watchdog' || true