# branding/ATTRIBUTION.md — Atribusi aset open-source mixos

## Aset Buatan Sendiri (mixos project)

| Aset | File Sumber | Lisensi |
|------|-------------|---------|
| Logo utama (SVG) | `branding/logo/mixos-logo.svg` | MIT |
| Icon (SVG, 128px) | `branding/logo/mixos-icon.svg` | MIT |
| Text logo | `branding/logo/mixos-text.svg` | MIT |
| Wallpaper default | `branding/wallpaper/mixos-default.svg` | MIT |
| Wallpaper dark | `branding/wallpaper/mixos-dark.svg` | MIT |
| Plymouth theme script | `branding/plymouth/mixos/mixos.script` | MIT |
| GRUB theme | `branding/grub/theme.txt` | MIT |
| About content | `branding/about/mixos-about.json` | MIT |

## Aset yang DIRENCANAKAN (akan dibuat/disource)

| Aset | Status | Rencana |
|------|--------|---------|
| Logo PNG (raster) | TODO | Render dari SVG via librsvg |
| Wallpaper JPG/PNG | TODO | Render dari SVG via librsvg, kompres ke <5MB |
| Plymouth background.png | TODO | Render dari wallpaper-dark.svg |
| Plymouth logo.png | TODO | Render dari mixos-logo.svg |
| Plymouth spinner.png | TODO | Generate dengan ImageMagick atau download dari open-source |
| GRUB background.png | TODO | Render dari wallpaper.svg |
| GRUB font .pf2 | TODO | Convert dari Inter dan Hack dengan grub-mkfont |

## Aset Open-Source yang AKAN Digunakan (Tahap 4+)

| Aset | Sumber | Lisensi | Catatan |
|------|--------|---------|---------|
| Inter font | rsms.me/inter | SIL OFL 1.1 | Typography utama |
| Hack font | sourcefoundry.org/hack | SIL OFL 1.1 + BSD | Monospace |
| Cantarell font | GNOME | SIL OFL 1.1 | Fallback |
| Noto fonts | Google | SIL OFL 1.1 | CJK dan simbol |
| (icon theme) | Papirus / TBD | GPL-3.0 / MIT | Akan di-pick di Tahap 4 |
| (cursor theme) | Bibata / Capitaine | MIT | Akan di-pick di Tahap 4 |

## Aset yang DILARANG

Sesuai `docs/LEGAL_NOTES.md`, aset berikut **TIDAK BOLEH** disertakan:

- Aset proprietary Apple (logo Apple, wallpaper macOS, icon Finder, font San Francisco).
- Aset proprietary elementary (logo "e" lingkaran, wallpaper elementary).
- Font proprietary (Helvetica kecuali LTSF, Segoe UI, San Francisco).
- Wallpaper proprietary OS pihak ketiga.
- Soundscape proprietary.

## Catatan Render

Untuk render SVG ke PNG, gunakan librsvg:

```bash
# Logo
rsvg-convert -w 1024 -h 1024 -o mixos-logo.png mixos-logo.svg

# Wallpaper (kompres)
rsvg-convert -w 5120 -h 2880 mixos-default.svg | \
  cairo-surface write-to-png mixos-default.png

# Atau dengan ImageMagick:
convert -density 96 -resize 5120x2880 mixos-default.svg mixos-default.png
```

## TODO

- [x] Buat SVG logo mixos.
- [x] Buat SVG icon mixos.
- [x] Buat SVG text logo.
- [x] Buat SVG wallpaper default.
- [x] Buat SVG wallpaper dark.
- [x] Buat Plymouth theme skeleton.
- [x] Buat GRUB theme skeleton.
- [x] Buat About content.
- [ ] Render SVG ke PNG.
- [ ] Generate Plymouth .png asset.
- [ ] Convert font ke .pf2.
- [ ] Update `licenses/THIRD_PARTY_LICENSES.txt` setelah asset final.
- [ ] Tulis lisensi MIT di LICENSE file.
