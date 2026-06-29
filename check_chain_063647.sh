#!/usr/bin/env bash
set -euo pipefail
sleep 35
pgrep -af 'build-lingmo-source.sh --force' || true
pgrep -af 'dpkg-buildpackage' || true
pgrep -af 'make build-pkgs' || true
pgrep -af 'build.sh --no-dry-run' || true