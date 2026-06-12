# mixos Plymouth theme

## Status: Skeleton (asset gambar belum ada)

Plymouth theme mixos menggunakan **script** plugin (Plymouth built-in).

## File yang dibutuhkan

Plymouth theme ini membutuhkan 3 file gambar (PNG):

1. **background.png** — background gradient gelap (1920×1080 atau lebih)
2. **logo.png** — logo mixos dalam format PNG transparan (256×256 disarankan)
3. **spinner.png** — frame spinner (32×32 atau 64×64)

## Aset yang harus dibuat

- Background: gradient biru-ungu gelap (lihat `branding/wallpaper/mixos-dark.svg`).
- Logo: hasil render dari `branding/logo/mixos-logo.svg` ke PNG ukuran 256×256.
- Spinner: lingkaran dengan 8–12 frame untuk animasi, atau gunakan spinner built-in Plymouth (Plymouth sudah punya spinner default yang bisa dipakai).

## Instalasi

Plymouth theme ini akan di-install oleh `hooks/003-apply-branding.sh` ke:
- `/usr/share/plymouth/themes/mixos/`

Aktivasi:
```
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/mixos/mixos.plymouth 100
update-alternatives --set default.plymouth /usr/share/plymouth/themes/mixos/mixos.plymouth
update-initramfs -u
```

## Lisensi

- Script: MIT (mixos project)
- Aset gambar: harus open-source (lihat `docs/LEGAL_NOTES.md`)
