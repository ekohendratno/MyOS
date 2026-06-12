# BUILD_GUIDE — Panduan Build ISO mixos

> **Status**: Panduan siap. Build aktual diuji di WSL2 atau Linux VM.
> **Lokasi dokumentasi lengkap**: `docs/BUILD_ON_WINDOWS.md` (khusus Windows 11 + WSL2).

## Prasyarat

| Tool | Minimal | Catatan |
|------|---------|---------|
| OS | Debian 12, Ubuntu 22.04, atau WSL2 | Build TIDAK dijalankan di host Windows |
| RAM | 16 GB | 8 GB minimal, 16 GB rekomendasi |
| Disk | 50 GB kosong | Build debootstrap + squashfs butuh besar |
| Tools | `debootstrap`, `live-build`, `xorriso`, `git` | Lihat detail di bawah |

## Pendekatan Build

mixos menggunakan **live-build** dari Debian untuk menghasilkan ISO hybrid (BIOS + UEFI). Struktur upstream `elementary/os` menyediakan:

- `live-build/config/` — konfigurasi packages, hooks, repo
- `live-build/hooks/` — script chroot
- `live-build/auto/` — preset untuk `lb config`

mixos menambahkan layer di atas upstream:
- `config/` — override packages, branding, settings
- `hooks/` — hook tambahan untuk branding, theme, layout
- `branding/` — asset visual mixos
- `themes/` — GTK, icon, cursor theme

## Langkah Build

### Di Linux / WSL2

```bash
# 1. Install dependencies
sudo apt update
sudo apt install -y debootstrap live-build xorriso isolinux \
  syslinux-common grub-pc-bin grub-efi-amd64-bin grub-efi-ia32-bin \
  mtools squashfs-tools genisoimage git curl

# 2. Clone upstream
./scripts/clone-upstream.sh

# 3. Build ISO
./build.sh --no-dry-run

# 4. Output di:
ls -lh builds/*.iso
```

### Di Windows 11 (via WSL2)

Lihat dokumen khusus: **`BUILD_ON_WINDOWS.md`**

## Struktur Output

```
builds/
├── mixos-horizon-0.1-amd64.iso    # ISO hybrid
├── mixos-horizon-0.1-amd64.iso.zsync  # zsync metadata (opsional)
└── SHA256SUMS                     # Checksum
```

## Verifikasi

```bash
./scripts/verify-iso.sh --iso=builds/mixos-*.iso
./test-vm.sh --iso=builds/mixos-*.iso --ram=2048
```

## Troubleshooting

Lihat `docs/TROUBLESHOOTING.md` untuk masalah umum:

- Build gagal "disk penuh"
- ISO tidak boot
- Package tidak ditemukan
- Patch tidak apply

## Timeline

| Fase | Durasi |
|------|--------|
| Setup lingkungan | 15–30 menit |
| Clone upstream | 2–5 menit |
| **Build ISO** | **2–6 jam** |
| Verify + test | 10–20 menit |

## Catatan

- Build TIDAK boleh dijalankan di host utama (langsung). Gunakan WSL2/container/VM.
- mixos menggunakan PPA elementary yang perlu diakses saat build.
- Build reproducibility belum 100% dijamin di tahap awal.
