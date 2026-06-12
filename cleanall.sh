#!/bin/bash
mount | grep "/home/srv/mixos/builds/work-amd64" | awk '{print $1}' | while read m; do
  umount -lf "$m" 2>/dev/null
done
sleep 2
rm -rf /home/srv/mixos/builds/work-amd64/chroot
rm -rf /home/srv/mixos/builds/work-amd64/cache/bootstrap
rm -f /home/srv/mixos/builds/work-amd64/.build/chroot_*
rm -f /home/srv/mixos/builds/work-amd64/.build/bootstrap*
echo "done"
