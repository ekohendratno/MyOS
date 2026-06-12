#!/bin/bash
set -euo pipefail

WORK_DIR="/home/srv/mixos/builds/work-amd64"

# Unmount everything under work directory
cat /proc/mounts | grep "$WORK_DIR" | awk '{print $2}' | sort -r | while read m; do
  umount -lf "$m" 2>/dev/null || true
done

sleep 2

# Remove chroot and cache
rm -rf "$WORK_DIR/chroot"
rm -rf "$WORK_DIR/cache/bootstrap"
rm -f "$WORK_DIR/.build/chroot_*"
rm -f "$WORK_DIR/.build/bootstrap*"

# Verify
echo "chroot: $(ls -d $WORK_DIR/chroot 2>/dev/null || echo 'gone')"
echo "cache: $(ls -d $WORK_DIR/cache/bootstrap 2>/dev/null || echo 'gone')"
echo "stamps: $(ls $WORK_DIR/.build/chroot_* $WORK_DIR/.build/bootstrap* 2>/dev/null || echo 'all cleared')"
