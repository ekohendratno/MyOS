#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
stat -c '%y %s %n' logs/overnight-20260617-001326.log
tail -n 160 logs/overnight-20260617-001326.log