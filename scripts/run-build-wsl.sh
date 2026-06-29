#!/bin/bash
# Helper: setup + build mixos ISO
# Force IPv4 for apt (WSL2 IPv6 broken)
echo 'Acquire::ForceIPv4 "true";' | tee /etc/apt/apt.conf.d/99force-ipv4

# Create logs dir
mkdir -p /home/srv/mixos/logs

# Run build
cd /home/srv/mixos
./build.sh --no-dry-run > /home/srv/mixos/logs/build.log 2>&1
echo "BUILD EXIT CODE: $?" >> /home/srv/mixos/logs/build.log
