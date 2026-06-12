#!/bin/bash
echo "=== Mounts under build chroot ==="
mount | grep "/var/cache/mixos-build-chroot" | awk '{print $1}' || true

echo "=== Apt sources ==="
cat /var/cache/mixos-build-chroot/etc/apt/sources.list.d/*.list 2>/dev/null | head -10

echo "=== Stub debs ==="
ls /var/cache/mixos-build-chroot/tmp/pkgs/*.deb 2>/dev/null | head -5 || echo "no debs"

echo "=== Installed lingmo pkgs ==="
chroot /var/cache/mixos-build-chroot /bin/bash -c "dpkg -l liblingmo lingmoui3 2>/dev/null | grep -E '^ii'" 2>/dev/null || echo "not installed or chroot issue"

echo "=== Last build log ==="
cat /var/cache/mixos-build-chroot/src/lingmo-settings/build.log 2>/dev/null | tail -20
ls /var/cache/mixos-build-chroot/src/*.deb 2>/dev/null || echo "no built debs"
