#!/usr/bin/env bash
set -euo pipefail
cd /home/srv/mixos
root=builds/work-amd64/chroot
printf '== binaries ==\n'
find "$root/usr/bin" "$root/usr/lib" "$root/usr/libexec" -maxdepth 4 \( -type f -o -type l \) 2>/dev/null | grep -Ei '/(lingmo|start|kwin|session|plasma|sddm|dock|shell|desktop)' | sort | sed -n '1,240p'
printf '== sessions ==\n'
find "$root/usr/share/xsessions" "$root/usr/share/wayland-sessions" -type f -maxdepth 1 2>/dev/null -print -exec sed -n '1,80p' {} \;
printf '== autostart ==\n'
find "$root/etc/xdg/autostart" "$root/usr/share/lingmo" -maxdepth 3 -type f 2>/dev/null | grep -Ei 'lingmo|dock|shell|desktop|panel|launcher' | sort | sed -n '1,160p'