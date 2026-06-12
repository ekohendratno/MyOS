# mixos — macOS-inspired Linux desktop (LingmoOS base)

> Berbasis [LingmoOS 3.0](https://github.com/LingmoOS/LingmoOS) / Debian 12 (Bookworm).
> Proyek ini tidak mengandung aset Apple atau merek dagang terdaftar.

## Build ISO

Build menggunakan live-build di WSL2 Debian/Ubuntu.

```bash
# 1. Copy project dari Windows ke WSL2
#    Dari PowerShell/CMD:
wsl rm -rf ~/mixos
wsl cp -r /mnt/c/Users/ekohe/OneDrive/Documents/MyOS ~/mixos

# 2. Buka WSL2, install dependencies (sekali saja)
sudo apt update
sudo apt install -y debootstrap live-build xorriso isolinux syslinux-common \
  grub-pc-bin grub-efi-amd64-bin grub-efi-ia32-bin mtools squashfs-tools \
  genisoimage git curl wget rsync

# 3. Build ISO (2-6 jam)
cd ~/mixos
sudo rm -rf builds/work-amd64 upstream/live-build-config
sudo ./build.sh --no-dry-run
```

Output ISO di `builds/`.

## Test ISO

### Via VirtualBox (dari Windows)
```powershell
wsl cp ~/mixos/builds/*.iso "$env:USERPROFILE\Desktop\"
```
Buat VM: Linux → Debian 12 (64-bit), RAM 4GB, disk 20GB, mount ISO.

## Development Workflow

**Edit di VM, porting ke project, build ulang hanya untuk rilis final.**

1. Build ISO → install di VM → edit langsung di VM
2. Catat perubahan file/config/paket
3. Backport ke `config/`, `hooks/`, `branding/`
4. Build ulang untuk rilis bersih

Tools capture: `dpkg-repack`, `diff -r`, `etckeeper`, snapshot VM.

## Project Structure

```
├── build.sh                  # Orchestrator build ISO
├── clean.sh                  # Clean artifacts
├── test-vm.sh                # QEMU test
├── config/
│   ├── mixos.conf            # Project metadata
│   ├── packages.list         # Additional packages
│   └── ...
├── scripts/                  # Helper scripts
├── hooks/                    # Chroot hook templates
├── branding/                 # Logo, wallpaper, GRUB, Plymouth
├── themes/                   # GTK, icon, cursor themes
├── desktop/                  # Panel, dock, WM configs
├── upstream/live-build-config/  # LingmoOS upstream (build-time)
├── builds/                   # Output ISO
└── docs/                     # Documentation
```

