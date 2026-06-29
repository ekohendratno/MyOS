#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
grep -nE 'dbus-x11|libxcb-cursor0|xterm|x11-utils' config/packages.list