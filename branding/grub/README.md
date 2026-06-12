# mixos GRUB theme

## Status: Skeleton (asset gambar belum ada)

GRUB theme mixos menggunakan format standar GRUB 2.06+.

## File yang dibutuhkan

1. **background.png** — background gelap (1920×1080, JPG/PNG, <2MB)
2. **selected_\*.png** — highlight untuk item menu yang dipilih
3. **scrollbar_thumb.png** — thumb untuk scrollbar

## Font

Theme ini mereferensikan font **Inter Regular** dan **Hack**. Font ini harus di-install di GRUB dengan `grub-mkfont` untuk menghasilkan `.pf2`:

```bash
grub-mkfont -s 14 -o inter_regular_14.pf2 /usr/share/fonts/truetype/inter/Inter-Regular.ttf
grub-mkfont -s 12 -o hack_12.pf2 /usr/share/fonts/truetype/hack/Hack-Regular.ttf
```

Output `.pf2` harus disimpan di folder theme ini.

## Instalasi

```bash
mkdir -p /boot/grub/themes/mixos
cp -r branding/grub/* /boot/grub/themes/mixos/
# Update /etc/default/grub:
# GRUB_THEME=/boot/grub/themes/mixos/theme.txt
update-grub
```

## Lisensi

- Script: MIT (mixos project)
- Aset gambar: open-source
- Font Inter: SIL OFL 1.1
- Font Hack: SIL OFL 1.1 + BSD
