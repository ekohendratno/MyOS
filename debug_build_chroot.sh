#!/bin/bash
set -euo pipefail

BUILD_CHROOT="/var/cache/mixos-build-chroot"

echo "=== Deb packages in build chroot ==="
ls "$BUILD_CHROOT/src/"*.deb 2>/dev/null || echo "no debs"

echo "=== Last build attempt log (if any) ==="
ls "$BUILD_CHROOT/src/lingmo-settings/debian/control" 2>/dev/null && echo "control exists" || echo "no control"
ls "$BUILD_CHROOT/src/lingmo-settings/debian/files" 2>/dev/null && cat "$BUILD_CHROOT/src/lingmo-settings/debian/files" || echo "no debian/files"

echo "=== mk-build-deps test ==="
chroot "$BUILD_CHROOT" which mk-build-deps 2>/dev/null || echo "no mk-build-deps"
chroot "$BUILD_CHROOT" which dpkg-buildpackage 2>/dev/null || echo "no dpkg-buildpackage"

echo "=== Installed packages ==="
chroot "$BUILD_CHROOT" dpkg -l 2>/dev/null | grep -E '^ii.*(qt6|lingmo|libicu|libkf)' | head -20 || echo "no matching packages"

echo "=== Check if liblingmo is available in apt ==="
chroot "$BUILD_CHROOT" apt-cache show liblingmo 2>/dev/null | head -5 || echo "liblingmo not in apt cache"

echo "=== apt policy ==="
chroot "$BUILD_CHROOT" apt-cache policy 2>/dev/null | head -10 || echo "apt policy failed"
