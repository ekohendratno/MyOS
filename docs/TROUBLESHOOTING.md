# TROUBLESHOOTING — Panduan Troubleshooting mixos (Placeholder)

> **Status**: Placeholder. Akan diisi berdasarkan pengalaman build aktual.

## Topik Troubleshooting yang Mungkin

### Build Gagal
- debootstrap error.
- Paket tidak ditemukan.
- Mirror tidak bisa diakses.
- Disk penuh saat build.
- Hook script error (exit code non-zero).

### ISO Tidak Boot
- ISO corrupt (verify SHA256).
- GRUB tidak terpasang.
- Hybrid boot record salah.
- Plymouth gagal.

### Desktop Tidak Muncul
- Gala crash.
- wingpanel crash.
- Compositor Gagal (driver GPU).
- X11 session error.

### Patch Tidak Bekerja
- Patch conflict dengan upstream.
- Build cache tidak clean.
- Schema tidak ter-generate.
- File yang dipatch tidak ada.

### Network/Tools Bermasalah
- NetworkManager tidak start.
- AppArmor block.
- Flatpak portal tidak tersedia.

## TODO

- [ ] Kumpulkan log error umum dari build.
- [ ] Tulis solusi untuk masing-masing.
- [ ] Tulis strategi recovery.
- [ ] Tambah link ke upstream docs.
