#!/usr/bin/env bash
set -u
cd /home/srv/mixos
root=builds/work-amd64/chroot
printf '== lingmo packages ==\n'
chroot "$root" dpkg-query -W -f='${Package}\t${Version}\n' '*lingmo*' 2>/dev/null | sort
printf '== likely desktop files ==\n'
find "$root/usr/share/applications" -maxdepth 1 -type f 2>/dev/null | grep -Ei 'lingmo|dock|launcher|settings|filemanager|terminal|kwin' | sort | sed -n '1,200p'
printf '== xdg autostart ==\n'
find "$root/etc/xdg/autostart" -maxdepth 1 -type f 2>/dev/null -print | sort | sed -n '1,200p'
printf '== desktop executable deps ==\n'
for b in kwin_x11 lingmo-desktop lingmo-appmotor lingmo-filemanager lingmo-settings; do command_path="$root/usr/bin/$b"; [ -e "$command_path" ] && echo "-- $b" && chroot "$root" ldd "/usr/bin/$b" 2>&1 | grep -E 'not found|=>' | grep 'not found' || true; done