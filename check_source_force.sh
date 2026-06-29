#!/usr/bin/env bash
set -euo pipefail
pgrep -af 'build-lingmo-source.sh --force' || true
pgrep -af 'dpkg-buildpackage' || true
pgrep -af 'make build-pkgs' || true
pgrep -af 'apt-get' || true