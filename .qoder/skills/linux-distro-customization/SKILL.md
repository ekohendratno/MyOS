---
name: linux-distro-customization
description: Membangun, meng-customize, dan memelihara custom Linux distro berbasis Ubuntu 24.04 LTS Noble dengan target look-and-feel elementary OS Pantheon. Mencakup build pipeline (debootstrap, Cubic, live-build), package selection, branding, repository custom, ISO generation, dan release workflow. Gunakan skill ini saat user ingin membuat remaster Ubuntu, custom ISO, branded distro, atau memilih strategi build yang tepat.
---

# Linux Distro Customization — Ubuntu 24.04 LTS Base

Skill ini fokus pada **build pipeline** untuk custom Ubuntu-based distro. Default base: **Ubuntu 24.04 LTS Noble Numbat** (support sampai 2029, point release tiap 6 bulan). Asumsi: DE target adalah Pantheon-inspired (lihat skill `desktop-environment-engineering`).

## Kapan Pakai Skill Ini

- Membuat custom ISO Ubuntu untuk distro branded
- Remaster Ubuntu (tambah/hapus package, ubah default, branding)
- Memilih strategi build: dari nol (debootstrap) vs GUI tool (Cubic) vs automated (live-build)
- Setup custom repository & package mirror
- Branding: bootloader (GRUB), Plymouth, wallpapers, default session
- Otomasi build dengan CI/CD (GitHub Actions, GitLab CI)
- Release management: versioning, signing, checksum, mirror

**Jangan pakai skill ini** untuk: desain visual/UX (pakai `os-ui-ux-design`), stack DE engineering (pakai `desktop-environment-engineering`), security policy (pakai `os-security-hardening`).

## Memilih Strategi Build

Ada 4 strategi utama. Pilih berdasarkan skala, skill tim, dan reproducibility requirement:

### 1. Cubic (Custom Ubuntu ISO Creator) — **Recommended untuk pemula & solo dev**

GUI tool, customisasi ISO Ubuntu existing. Paling cepat dari 0 → ISO.

**Pros**:
- GUI, minim learning curve
- Langsung pakai repo Ubuntu official (binary compatibility 100%)
- Bisa chroot environment untuk testing

**Cons**:
- Kurang reproducible (klik-klik manual di GUI)
- Hard untuk di-automate
- Tidak scalable untuk multi-variant

**Use case**: prototyping, distro personal, single-maintainer project.

### 2. live-build (Debian official) — **Recommended untuk reproducible & CI-friendly**

Command-line tool dari Debian. Bisa build dari `debootstrap` root, atau dari `lb config` recipes.

**Pros**:
- Reproducible (semua konfigurasi di file teks)
- Bisa diotomasi penuh dengan CI
- Standard industri, banyak reference
- Multi-architecture (amd64, arm64, dll) tinggal ubah config

**Cons**:
- Learning curve curam
- Default menghasilkan Debian-style (perlu adjust untuk Ubuntu)
- Dokumentasi fokus ke Debian, Ubuntu-specific tweaks harus diutak-atik

**Use case**: serious distro project, multi-variant, release management proper.

### 3. debootstrap + custom scripts — **Paling fleksibel, paling banyak kerja**

Bootstrapping minimal Ubuntu dari nol, lalu layer customization di atasnya.

**Pros**:
- Full control, tidak ada "bloat" bawaan tool
- Bisa minim image size
- Bagus untuk container/embedded use case

**Cons**:
- Banyak kerja manual (kernel, bootloader, initramfs, package selection)
- Tidak ada reproducibility tool bawaan, harus DIY
- Tinggi maintenance cost

**Use case**: container OS, embedded, niche requirement (misal: read-only rootfs).

### 4. Distrobox/Toolbox style — **Bukan untuk full distro, untuk dev environment**

Rebuild user-space di atas host. Bukan untuk shipping ISO, tapi untuk development/testing.

**Use case**: dev workflow, testing package combo, CI test environment.

**Default rekomendasi**: mulai dengan **Cubic** untuk prototype, migrasi ke **live-build** saat siap release serius. debootstrap hanya kalau ada kebutuhan khusus.

## Default Tech Stack

- **Base**: Ubuntu 24.04 LTS Noble (amd64 primary, arm64 secondary)
- **Build tool**: live-build (untuk release), Cubic (untuk eksperimen)
- **Init system**: systemd
- **Display server**: Wayland only (lihat skill `desktop-environment-engineering`)
- **DE**: Pantheon stack (dari elementary OS 8 repo) atau custom DE
- **Package manager**: APT + flatpak (untuk proprietary & sandbox apps)
- **Installer**: ubiquity (Ubuntu) atau calamares (lebih customizable)
- **Bootloader**: GRUB2
- **Initramfs**: initramfs-tools (Ubuntu default) atau dracut
- **Compression**: zstd (Ubuntu 24.04 default) untuk image & packages

## Branding & Identity

Setiap distro butuh identity yang konsisten. Setup ini diawal, jangan ditunda.

### File-file branding yang harus disiapkan

```
branding/
├── distro-name                  # "MyDistro"
├── distro-version               # "1.0 LTS"
├── distro-codename              # "lunar-bear" (semester-themed)
├── logo.svg / logo.png          # logo 256x256 minimum
├── logo-text.svg                # logo + wordmark
├── plymouth/                    # boot splash theme
│   ├── mydistro.plymouth
│   └── ...
├── wallpaper/                   # 6-8 default wallpapers
│   ├── 01-light-abstract.png    # 3840x2160 minimum
│   └── ...
├── grub/                        # bootloader theme
│   ├── theme.txt
│   └── background.png
├── icon-theme/                  # custom icon theme
└── cursor-theme/                # custom cursor
```

### Identifier penting

- **OS ID** (`/etc/os-release`): `ID=mydistro`, `PRETTY_NAME="MyDistro 1.0 LTS"`, `ID_LIKE=debian ubuntu`
- **Issue**: `/etc/issue` & `/etc/issue.net` untuk login prompt
- **Hostname default**: `mydistro-{uuid}` atau biarkan user set saat install
- **Paket**: prefix `mydistro-` untuk semua custom package (e.g., `mydistro-settings`, `mydistro-wallpapers`)

### Plymouth (boot splash)

Custom boot splash Plymouth supaya branded. Contoh minimal theme:

```ini
# /usr/share/plymouth/themes/mydistro/mydistro.plymouth
[Plymouth Theme]
Name=Mydistro
Description=Custom theme for Mydistro
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/mydistro
ScriptFile=/usr/share/plymouth/themes/mydistro/mydistro.script
```

Lihat dokumentasi Plymouth untuk script syntax lengkap.

### GRUB theme

Custom GRUB theme via `grub-theme-mydistro` package. File `theme.txt` di `/boot/grub/themes/mydistro/`. Generate `background.png` dari wallpaper.

## Package Selection Strategy

### Base packages (WAJIB)

```bash
# System core
ubuntu-base
linux-generic
linux-firmware
initramfs-tools
systemd
systemd-sysv
udev

# Network
network-manager
wpasupplicant
modemmanager

# Display & input
wayland-protocols
libwayland-client0
xwayland                       # X11 fallback untuk legacy app
input-utils

# User-facing essentials
sudo
adduser
locales
console-setup
keyboard-configuration
```

### DE packages (Pantheon-inspired)

```bash
# Core Pantheon
pantheon-session                # meta-package
pantheon-shell                  # window manager + shell
gala                            # window manager
wingpanel                       # top bar
plank                            # dock
slingshot-launcher              # app launcher
switchboard                     # settings
switchboard-plug-*              # settings modules
pantheon-files                  # file manager (Files)
pantheon-terminal               # terminal
pantheon-calculator             # calculator
pantheon-mail                   # email
pantheon-music                  # music player
pantheon-photos                 # photo viewer
pantheon-videos                 # video player
pantheon-camera                 # camera
pantheon-screenshot             # screenshot tool
pantheon-default-settings       # default settings bundle
elementary-icon-theme           # icon theme
elementary-theme                # GTK theme
elementary-wallpapers
elementary-sound-theme
```

Note: elementary OS 8 mungkin belum fully support Ubuntu 24.04. **Validate compatibility** sebelum commit. Alternatif: pakai upstream Pantheon dari elementary PPA, atau build custom DE (lihat skill `desktop-environment-engineering`).

### Yang harus di-remove dari default Ubuntu

```bash
# Remove (kalau ada)
ubuntu-desktop                   # default GNOME Ubuntu
firefox                          # ganti ke Epiphany/Geary atau custom default
gnome-shell
gnome-terminal
nautilus                         # ganti ke pantheon-files
gedit                            # ganti ke pantheon-text (Code)
cheese                           # ganti ke pantheon-camera
rhythmbox                        # ganti ke pantheon-music
totem                            # ganti ke pantheon-videos
evolution                        # ganti ke pantheon-mail
snapd                            # OPSIONAL: banyak orang non-snap
```

**Penting**: ini daftar default. Adjust sesuai kebutuhan. Test setiap removal — beberapa dependency mungkin dipakai komponen lain.

### Flatpak (untuk sandbox & proprietary)

Setup Flatpak + Flathub sebagai default second source:

```bash
# Install flatpak
apt install flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Pre-install (opsional)
flatpak install flathub com.spotify.Client
flatpak install flathub org.videolan.VLC
```

Setup `flatpak-spawn` di PATH agar desktop integration jalan (untuk case user klik "Open" di file manager Flatpak).

## Custom Repository

Buat repo sendiri untuk paket-paket yang di-fork dari elementary/Ubuntu, atau paket distro-only.

### Tools: reprepro

```bash
# Setup reprepro
apt install reprepro gnupg

# /etc/reprepro/mydistro.conf
Origin: Mydistro
Label: Mydistro
Suite: noble
Codename: noble
Architectures: amd64 arm64
Components: main
SignWith: ABCD1234...

# Incoming dir
incomingdir: /srv/reprepro/incoming

# Run
reprepro -b /srv/reprepro export
reprepro -b /srv/reprepro includedeb noble /path/to/package.deb
```

Expose via HTTP (nginx) di `https://repo.mydistro.id/`. Client config:

```
# /etc/apt/sources.list.d/mydistro.list
deb [signed-by=/usr/share/keyrings/mydistro-archive-keyring.gpg] https://repo.mydistro.id noble main
```

Pakai `apt-key` sudah deprecated. Pakai `signed-by` dengan keyring file.

## Build Pipeline (live-build)

### Setup project

```bash
mkdir -p mydistro-build && cd mydistro-build
lb config \
  --distribution noble \
  --archive-areas "main restricted universe multiverse" \
  --debian-installer none \
  --bootappend-live "quiet splash" \
  --firmware-binary true \
  --firmware-chroot true \
  --mode ubuntu \
  --security true \
  --updates true
```

### Layer customization

```bash
# config/package-lists/mydistro.list.chroot
mydistro-meta
pantheon-session
pantheon-shell
gala
wingpanel
plank
slingshot-launcher
switchboard
elementary-icon-theme
elementary-theme
# ... dst
```

```bash
# config/hooks/live/0010-branding.hook.chroot
#!/bin/sh
set -e
cp -r /branding/wallpaper/* /usr/share/backgrounds/
cp /branding/os-release /etc/os-release
# ... dst
```

### Build

```bash
sudo lb build 2>&1 | tee build.log
# Output: live-image-amd64.img + iso
```

## CI/CD Otomasi

Pakai GitHub Actions atau GitLab CI untuk build otomatis per push ke `main`:

```yaml
# .github/workflows/build-iso.yml
name: Build ISO
on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Install deps
        run: sudo apt install -y live-build
      - name: Build
        run: sudo lb build
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: mydistro-iso
          path: live-image-*.iso
```

Untuk reproducibility, pakai `live-build` `--build-with-chroot-squashfs` dan commit semua config ke git.

## Release Management

### Versioning scheme

Pakai **Semantic Versioning + Ubuntu codename**:
- Format: `<major>.<minor>.<patch>-<codename>` (e.g., `1.0.0-noble`)
- LTS release: major bump tiap 2 tahun (sync dengan Ubuntu LTS)
- Point release: minor bump tiap 6 bulan
- Hotfix: patch bump

### Signing

Sign ISO & repo dengan GPG key. Simpan private key offline (atau di secret manager CI). Publish public key di:
- Website distro
- `https://repo.mydistro.id/key.asc`
- `MASTODON/forum` profile

```bash
# Sign ISO
gpg --armor --detach-sign --signing-key ABCD1234 mydistro-1.0.0-noble-amd64.iso

# Generate checksum
sha256sum mydistro-1.0.0-noble-amd64.iso > SHA256SUMS
gpg --sign SHA256SUMS
```

### Mirror strategy

Mirror ISO ke beberapa lokasi:
- **Primary**: server sendiri atau VPS (e.g., Hetzner, OVH)
- **Secondary**: GitHub Releases (untuk artifact, bukan direct serve ISO)
- **Community mirrors**: ajak komunitas host mirror

## Testing

Sebelum release, test di:

### Hardware matrix minimum

- [ ] VM (QEMU/KVM) — basic smoke test
- [ ] VM (VirtualBox) — testing proprietary modules
- [ ] Laptop mainstream (Intel iGPU) — most users
- [ ] Laptop AMD Ryzen — AMD GPU driver
- [ ] Laptop Nvidia Optimus — `nvidia-prime` / Wayland session
- [ ] Desktop dengan GPU diskrit Nvidia
- [ ] ARM board (misal: Raspberry Pi 5) — kalau support
- [ ] Old hardware (Core 2 Duo, 4GB RAM) — performance floor

### Test scenarios

- [ ] Install fresh → boot → login → desktop
- [ ] Wi-Fi connect, Ethernet connect
- [ ] Audio output, audio input (mic)
- [ ] Suspend & resume
- [ ] Hibernate (kalau support)
- [ ] Multi-monitor (hotplug)
- [ ] Bluetooth pairing
- [ ] Printer (CUPS) install
- [ ] Flatpak install & launch
- [ ] Update & upgrade
- [ ] Reboot after kernel update
- [ ] Recovery mode (jika perlu)
- [ ] LUKS-encrypted install (jika default)

## Maintenance & Update Policy

- **Security updates**: auto-apply dalam 24 jam (unattended-upgrades)
- **Point release update**: weekly batch (apply semua point release, test di staging)
- **LTS major update**: biarkan user opt-in via `do-release-upgrade`

```bash
# /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
```

## Anti-Pattern yang Harus Dihindari

- ❌ **Hardcode repo Ubuntu langsung** — selalu lewat variabel (`$distro_codename`), biar mudah di-fork ke base lain.
- ❌ **Skip testing matrix** — "jalan di laptop gw" ≠ jalan di semua user. Test hardware matrix minimal.
- ❌ **ISO tanpa signature** — user harus bisa verify integrity. Selalu sign.
- ❌ **Custom package tanpa metadata** — `Description`, `Maintainer`, `Section` harus diisi. `lintian` clean.
- ❌ **Modify /etc/os-release sembarangan** — beberapa tool baca `$ID` & `$ID_LIKE` untuk behavior, jangan bohongi.
- ❌ **Bloat default** — ship minimal, biarkan user install sendiri via Software Center.
- ❌ **Snap-only atau Flatpak-only** — dukung keduanya. Jangan lock-in.

## Output Skill Ini

Saat user minta:
- **"Gimana cara mulai bikin distro custom?"** → kasih: strategi build comparison, rekomendasi untuk use case mereka, quickstart langkah pertama.
- **"Build script / hook"** → kasih: file yang relevan lengkap, dengan inline comment.
- **"Package selection"** → kasih: list package grouped by purpose, plus justifikasi include/exclude.
- **"Branding setup"** → kasih: file tree, contoh file, dan checklist.
- **"ISO build error"** → kasih: cara baca log `lb build`, common error + fix.
- **"Release planning"** → kasih: timeline, versioning scheme, signing, mirror.

## Referensi Belajar

- Ubuntu Customization Kit: https://help.ubuntu.com/community/InstallCDCustomization
- live-build manual: https://live-team.pages.debian.net/live-manual/
- Cubic: https://github.com/PJ-Singh-001/Cubic
- elementary OS source: https://github.com/elementary
- Ubuntu 24.04 LTS Release Notes: https://discourse.ubuntu.com/t/noble-numbat-release-notes/
- Debian Reproducible Builds: https://reproducible-builds.org/
- reprepro manual: https://wiki.debian.org/DebianRepository/SetupWithReprepro
