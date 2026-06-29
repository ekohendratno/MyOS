#!/bin/bash
# Force IPv4 for apt globally in WSL
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
echo "APT ForceIPv4 configured"

# Create logs dir
mkdir -p ~/mixos/logs

# Start build
cd ~/mixos
./build.sh --no-dry-run > ~/mixos/logs/build.log 2>&1
