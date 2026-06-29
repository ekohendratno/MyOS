#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
printf '== config refs ==\n'
grep -RniE 'LINGMO_SOURCE_EXCLUDE_DIRS|lingmo-shell|lingmo-dock|lingmo-launcher|statusbar|libshell|global|plugins' config scripts build.sh | sed -n '1,220p' || true
printf '== source dirs ==\n'
find upstream/LingmoOS -maxdepth 4 -type d | grep -Ei 'shell|dock|launcher|status|global|panel|desktop' | sed -n '1,220p' || true
printf '== cached debs ==\n'
find artifacts/lingmo-source-debs -maxdepth 1 -type f -name '*.deb' -printf '%f\n' | sort | grep -Ei 'shell|dock|launcher|status|global|desktop|lingmo' | sed -n '1,220p' || true