#!/usr/bin/env bash
set -euo pipefail
pgrep -af 'source-force-20260617-002233|build-lingmo-source.sh --force|git .*submodule|timeout 180 git|dpkg-buildpackage|make build-pkgs' || true