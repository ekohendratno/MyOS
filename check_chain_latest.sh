#!/usr/bin/env bash
set -euo pipefail
pgrep -af 'build-lingmo-source.sh --force' || true
pgrep -af 'build.sh --no-dry-run' || true
pgrep -af 'dpkg-buildpackage' || true
pgrep -af 'make build-pkgs' || true
pgrep -af 'lb build' || true