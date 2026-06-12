# BUILD_ON_WINDOWS.md — Membangun ISO mixos di Windows 11

Panduan langkah demi langkah untuk membangun ISO mixos dari Windows 11 menggunakan WSL2 (Windows Subsystem for Linux).

## Prasyarat Sistem

| Requirement | Minimal | Rekomendasi |
|-------------|---------|-------------|
| Windows | Windows 11 (build 22000+) | Windows 11 Pro (build 26200+) |
| RAM | 16 GB | 32 GB |
| Disk kosong | 50 GB | 80 GB |
| Virtualisasi | Enabled di BIOS | Enabled + SLAT |
| Admin rights | Ya (untuk install WSL) | Ya |

Sistem Anda saat ini:
- Windows 11 Pro build 26200 ✅
- RAM 16.5 GB ✅ (cukup)
- Disk kosong: **~43 GB** ⚠️ (perlu minimal 50 GB, HAPUS file tidak perlu dulu)
- Virtualisasi: Enabled ✅
- WSL: **Belum terinstall** ❌

> **⚠️ Lingkungan build**: Semua proses build terjadi di dalam WSL2 Linux virtual machine. Windows host Anda AMAN. Tidak ada perubahan sistem.

## Step 1: Install WSL2 (Sekali)

Jalankan PowerShell **sebagai Administrator**:

```powershell
# 1. Install WSL dan Debian
wsl --install -d Debian

# 2. Restart jika diminta
#    Setelah restart, buka PowerShell lagi sebagai Admin

# 3. Set WSL2 sebagai default
wsl --set-default-version 2

# 4. Cek status
wsl --status
wsl -l -v
```

>Selesaikan setup Debian: buat username dan password (ingat passwordnya, Anda butuh `sudo`).

## Step 2: Clone Project mixos ke WSL

Di PowerShell (sebagai user biasa, bukan admin):

```powershell
# Copy project ke WSL filesystem (lebih cepat)
# Dari folder project Anda:
cd C:\Users\ekohe\OneDrive\Documents\MyOS

# Taruh di home WSL user
wsl cp -r . ~/mixos

# Masuk ke WSL
wsl ~ -u <username>
```

Atau clone langsung dari GitHub (jika sudah di-push):

```bash
# Di dalam WSL
cd ~
git clone https://github.com/<username>/mixos.git
cd mixos
```

## Step 3: Install Build Dependencies di WSL

```bash
# Di dalam WSL Debian
cd ~/mixos

# Update & upgrade
sudo apt update
sudo apt upgrade -y

# Install live-build tools
sudo apt install -y \
  debootstrap \
  live-build \
  xorriso \
  isolinux \
  syslinux-common \
  grub-pc-bin \
  grub-efi-amd64-bin \
  grub-efi-ia32-bin \
  mtools \
  squashfs-tools \
  genisoimage \
  git \
  curl \
  wget

# Cek environment
./scripts/prepare-build-env.sh
```

## Step 4: Clone Upstream elementary OS

```bash
# Di dalam WSL
cd ~/mixos

# Clone elementary/os (akan cek tag 8.1.x otomatis)
./scripts/clone-upstream.sh
```

Ini akan mendownload ~200 MB source ke `~/mixos/upstream/elementary-os/`.

## Step 5: Build ISO

```bash
# Di dalam WSL
cd ~/mixos

# Build actual (bukan dry-run)
# PERINGATAN: Proses ini memakan waktu 2-6 jam dan 50+ GB disk
./build.sh --no-dry-run
```

**Apa yang terjadi saat build:**
1. `debootstrap` membuat base Debian/Ubuntu di chroot
2. `lb config` mengkonfigurasi live-build dengan paket elementary
3. Hooks mixos di-include ke chroot
4. `lb build` menghasilkan file ISO hybrid
5. Output: `~/mixos/builds/mixos-horizon-0.1-amd64.iso`

Jika build terputus di tengah:

```bash
# Bersihkan cache build yang corrupt
./clean.sh

# Coba lagi
./build.sh --no-dry-run
```

## Step 6: Copy ISO ke Windows

Setelah build selesai, copy ISO keluar dari WSL:

```bash
# Di dalam WSL
ls -lh ~/mixos/builds/*.iso

# Copy ke Windows Desktop
cp ~/mixos/builds/mixos-*.iso /mnt/c/Users/ekohe/Desktop/
```

Atau dari PowerShell:

```powershell
wsl cp ~/mixos/builds/mixos-*.iso C:\Users\ekohe\Desktop\
```

## Step 7: Generate Checksum

```bash
./scripts/make-checksum.sh --iso=builds/mixos-*.iso
```

## Step 8: Uji Coba ISO

### Opsi A: QEMU di WSL (Rekomendasi)

```bash
# Install QEMU di WSL
sudo apt install -y qemu-system-x86 qemu-utils

# Test ISO
./test-vm.sh --iso=builds/mixos-*.iso --ram=2048 --kvm
```

**Catatan**: KVM di WSL2 tidak langsung bisa. Untuk performa lebih baik, test ISO di:

- **VirtualBox** di Windows (gratis, performa bagus)
- **VMware Workstation Player** di Windows (gratis)
- **QEMU** di WSL2 (tanpa KVM, lambat)

### Opsi B: VirtualBox di Windows

1. Install [VirtualBox](https://www.virtualbox.org/)
2. Buat VM baru:
   - Type: Linux, Version: Debian 64-bit
   - RAM: 4096 MB
   - Disk: 20 GB
   - Storage: attach ISO mixos
3. Boot dan install

### Opsi C: Ventoy USB Boot

1. Install [Ventoy](https://www.ventoy.net/) ke USB drive
2. Copy ISO mixos ke USB
3. Boot dari USB

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `wsl --install` error | Enable virtualization di BIOS + enable "Virtual Machine Platform" di Windows Features |
| Build gagal "disk full" | Hapus file sampah Windows: `cleanmgr` / Hapus `~/mixos/builds/`, `~/mixos/upstream/` |
| Build terlalu lambat | WSL2 di Windows 11 punya performa build decent. Tambah RAM via `.wslconfig` |
| Package `elementary` not found | Ada di PPA. Pastikan repo Ubuntu jammy ditambahkan dengan benar |
| ISO tidak boot | Coba verify: `./scripts/verify-iso.sh --iso=builds/mixos-*.iso` |

## .wslconfig Optimization

Buat file `C:\Users\ekohe\.wslconfig`:

```ini
[wsl2]
memory=8GB
processors=4
localhostForwarding=true
swap=4GB
```

Terapkan: `wsl --shutdown` lalu buka WSL lagi.

## Estimasi Waktu

| Tahap | Durasi | Keterangan |
|-------|--------|------------|
| Install WSL + Debian | 10–20 menit | Sekali saja |
| Install deps | 5–10 menit | Sekali saja |
| Clone upstream | 2–5 menit | Tergantung internet |
| **Build ISO** | **2–6 jam** | Proses terlama |
| Test ISO | 5–15 menit | Boot di VM |

## Catatan Keamanan

- Build ISO TIDAK mengubah Windows host Anda
- Semua perubahan hanya terjadi di dalam WSL2 VM
- Setelah selesai, hapus WSL: `wsl --terminate Debian`
- Atau hapus distro: `wsl --unregister Debian`

## TODO Checklist

- [ ] Step 1: Install WSL2 (admin PowerShell)
- [ ] Step 2: Setup Debian user
- [ ] Step 3: Clone project ke WSL
- [ ] Step 4: Install build deps
- [ ] Step 5: Clone upstream
- [ ] Step 6: RUN BUILD (2-6 jam, pastikan laptop tercharger)
- [ ] Step 7: Verify ISO
- [ ] Step 8: Test di VirtualBox/QEMU
