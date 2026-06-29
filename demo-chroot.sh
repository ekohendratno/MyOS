#!/bin/bash
set -euo pipefail

CHROOT_DIR="/home/srv/mixos/builds/work-amd64/chroot"
WORK_DIR="/home/srv/mixos/builds/work-amd64"

echo "=== Masuk chroot dan demo perubahan ==="

# 1. Masuk chroot, install paket, ubah setting
chroot "$CHROOT_DIR" /bin/bash <<'CHROOT_EOF'
echo "--- Di dalam chroot ---"
cat /etc/os-release | head -3
echo ""

echo "Contoh 1: Install neofetch"
apt-get install -y neofetch

echo ""
echo "Contoh 2: Setting default wallpaper"
cat > /usr/share/glib-2.0/schemas/90_mixos.gschema.override << 'SCHEMA'
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/mixos/mixos-default.svg'
picture-uri-dark='file:///usr/share/backgrounds/mixos/mixos-dark.svg'
SCHEMA
glib-compile-schemas /usr/share/glib-2.0/schemas/

echo ""
echo "Contoh 3: Tambah alias ke /etc/skel"
echo "alias ll='ls -lah'" >> /etc/skel/.bashrc
echo "alias la='ls -A'" >> /etc/skel/.bashrc

echo ""
echo "Selesai perubahan di chroot"
CHROOT_EOF

echo ""
echo "=== Semua perubahan sudah diterapkan ==="
echo ""
echo "Lanjutkan build (binary+ISO) dengan:"
echo "cd $WORK_DIR"
echo "sudo lb build --force 2>&1 | tee build-resume.log"
echo ""
echo "Build akan lanjut dari binary stage (tidak perlu download ulang)"
