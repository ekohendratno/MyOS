# MyOS — macOS-inspired Linux desktop

> **Peringatan:** Proyek ini tidak mengandung aset Apple atau elementary OS. Lihat [LEGAL_NOTES](docs/LEGAL_NOTES.md).

## Build ISO

Build menggunakan live-build di WSL2 Debian/Ubuntu.

```bash
# 1. Copy project dari Windows ke WSL2 filesystem
#    Dari PowerShell/CMD:
wsl rm -rf ~/mixos
wsl cp -r /mnt/c/Users/ekohe/OneDrive/Documents/MyOS ~/mixos

# 2. Buka WSL2 dan install dependencies (sekali saja)
sudo apt update
sudo apt install -y debootstrap live-build xorriso isolinux syslinux-common \
  grub-pc-bin grub-efi-amd64-bin grub-efi-ia32-bin mtools squashfs-tools \
  genisoimage git curl wget rsync

sudo ln -sfn /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/noble
gpg --recv-keys F6ECB3762474EDA9D21B7022871920D1991BC93C

# 3. Build ISO (2-6 jam)
cd ~/mixos
sudo rm -rf builds/work-amd64
sudo ./build.sh --no-dry-run
```

Output ISO di `builds/`.

## Test ISO

### Via QEMU (dari WSL)
```bash
cd ~/mixos
./test-vm.sh --iso=$(ls builds/*.iso | head -1)
```

### Via VirtualBox (dari Windows)
```powershell
# Copy ISO ke Windows Desktop dari PowerShell
wsl cp ~/mixos/builds/*.iso "$env:USERPROFILE\Desktop\"
```
Buat VM baru: Linux → Ubuntu 24.04 (64-bit), RAM 4GB, disk 20GB, mount ISO.

## Development Workflow

Build ulang 2-6 jam setiap edit UI tidak feasible. Workflow yang benar:

1. **Build ISO sekali** sampai jadi
2. **Install di VM** (VirtualBox/QEMU)
3. **Edit langsung di VM** — theme, CSS, config, ekstensi
4. **Catat perubahan** — file mana saja yg diubah
5. **Backport ke project** — update `config/`, `hooks/`, `branding/`
6. **Build ulang** hanya sekali di akhir untuk rilis bersih

Tools untuk capture perubahan dari VM:
- `dpkg-repack` — buat `.deb` dari paket yg dimodifikasi
- `diff -r` — bandingkan direktori config
- `etckeeper` — git untuk `/etc/`
- Snapshot VM sebelum eksperimen

## Project Structure

```
├── build.sh                  # Orchestrator build ISO
├── clean.sh                  # Hapus artifacts build
├── test-vm.sh                # Jalankan ISO di QEMU
├── config/                   # Konfigurasi build & packages
│   ├── mixos.conf            # Project metadata
│   ├── packages.list         # Paket tambahan
│   └── ...
├── scripts/                  # Build helper scripts
├── hooks/                    # Chroot hook templates
├── branding/                 # Logo, wallpaper, GRUB, Plymouth
├── themes/                   # GTK, icon, cursor themes
├── patches/                  # Pantheon patches
├── desktop/                  # Panel, dock, WM configs
├── upstream/                 # Clone elementary/os (build-time)
├── builds/                   # Output ISO
└── docs/                     # Panduan & catatan
```

## Catatan

- Bahasa Indonesia untuk komentar & dokumentasi
- Semua script menggunakan `set -euo pipefail`
- Build harus dijalankan di WSL2/Linux (bukan langsung di Windows host)
- Disk minimal 50 GB free

