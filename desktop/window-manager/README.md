# Window Manager — gala Config & Patch

## Target macOS-inspired

- **Window controls**: posisi KIRI (close, minimize, maximize)
- **Button style**: macOS traffic light (merah + kuning + hijau dengan gradasi khas)
- **Titlebar**: compact (24–28 px height, font Inter Semibold 10pt)
- **Window snapping**: kiri/kanan setengah layar (via gala already supports)
- **Hot corners**: tidak diaktifkan default
- **Animations**: enabled, duration standard
- **Focus**: follow-mouse (sloppy focus)

## Gala Settings

```
org.pantheon.desktop.gala
├── button-layout = 'close,minimize,maximize:menu'
├── animations = true
├── workspace-count = 4
└── hotcorner-* = '' (disabled)
```

## Patch Kritis: Window Controls Posisi Kiri

Ini adalah **perubahan terbesar** dari upstream. Gala secara default menempatkan
window controls di kanan (seperti GNOME). mixos perlu memindahkannya ke kiri.

File yang perlu dipatch di source gala:

1. **`src/WindowControls.vala`**
   - Ubah `DEFAULT_BUTTON_ORDER` dari `['close', 'maximize', 'minimize']` ke stay sama
   - Ubah `DEFAULT_BUTTON_SPACING` dari 8 ke 6

2. **`src/WindowGtk.vala`** atau file handling dekorasi
   - Balik posisi rendering button dari `end` ke `start`

3. **`src/Prefs.vala`** (jika ada override)
   - Ubah default button layout

Patch sudah disediakan di `patches/gala/` (placeholder).

## Patch: Titlebar Height Compact

Untuk mencapai titlebar setinggi 24px (dari 30px upstream):

1. Di `src/WindowControls.vala`, cari `TITLEBAR_HEIGHT` constant
2. Turunkan dari 30 ke 24
3. Sesuaikan padding icon control
4. Sesuaikan posisi label title

## Build & Install Patch

```bash
cd upstream/gala
git apply ../../patches/gala/window-controls-left.patch
git apply ../../patches/gala/titlebar-compact.patch
meson build
ninja -C build
ninja -C build install
```

## Approach Aman

Untuk tahap awal, jangan compile gala dari source.
Gunakan approach alternatif:

1. Pakai **`gtk-decorations`** custom untuk compile dekorasi terpisah
2. Pakai **Mutter/GNOME Shell** sebagai fallback (bukan gala)
3. **Override CSS** untuk GTK CSD (client-side decoration)

## Status

- Config: Siap di `config/pantheon-settings.sh`
- Patch: Placeholder di `patches/gala/.gitkeep`
- Build: Belum diuji kompilasi
