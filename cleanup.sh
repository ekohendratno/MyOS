#!/bin/bash
mount | grep "/home/srv/mixos/builds/work-amd64/chroot" | awk '{print $1}' | while read mnt; do
  umount -lf "$mnt" 2>/dev/null || true
done
sleep 1
rm -rf /home/srv/mixos/builds/work-amd64/chroot 2>/dev/null
if [ -d /home/srv/mixos/builds/work-amd64/chroot ]; then
  echo "chroot STILL EXISTS"
else
  echo "chroot gone"
fi
