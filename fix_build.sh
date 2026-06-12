#!/bin/bash
set -x
find /home/srv/mixos/builds/work-amd64/.build -name 'binary_*' -delete
sed -i 's/LB_MEMTEST="memtest86+"/LB_MEMTEST="none"/g' /home/srv/mixos/builds/work-amd64/config/binary /home/srv/mixos/builds/work-amd64/config/common 2>/dev/null
grep LB_MEMTEST /home/srv/mixos/builds/work-amd64/config/common || echo "not found in common"
grep LB_MEMTEST /home/srv/mixos/builds/work-amd64/config/binary || echo "not found in binary"
echo "=== done ==="
