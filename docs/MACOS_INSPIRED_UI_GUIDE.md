# MACOS_INSPIRED_UI_GUIDE — Panduan UX Target mixos

Dokumen ini menjelaskan target UX mixos yang **terinspirasi** dari macOS, dengan batasan teknologi Linux/Pantheon. Bukan spesifikasi pixel-perfect, melainkan pedoman desain.

## 1. Filosofi Desain

mixos mengikuti tiga prinsip:

1. **Tenang dan konsisten**: warna netral, padding longgar, animasi halus.
2. **Konten di atas chrome**: panel dan dock sekecil mungkin, tidak mendominasi.
3. **Open-source first**: tidak ada cloning proprietary 1:1; adaptasi yang menghormati lisensi.

## 2. Zona Desktop

```
+-----------------------------------------------------------+
|  [logo]  App Name       File   Edit   View       [icon][icon][icon]   <- Menu bar (top panel)
+-----------------------------------------------------------+
|                                                            |
|                                                            |
|                  Desktop wallpaper                         |
|                                                            |
|                                                            |
+-----------------------------------------------------------+
|     [icon][icon][icon][icon][icon][icon][icon]      [trash]   <- Dock (bottom, center)
+-----------------------------------------------------------+
```

- **Top panel (wingpanel)**: tinggi 24–28 px, font 9–10pt, padding horizontal 8 px.
- **Dock (plank)**: tinggi 56–64 px, icon 32–40 px, hidden by default (autohide), muncul saat cursor di area bawah.
- **Window**: titlebar 28–32 px, font 10pt.
- **Wallpaper**: gradient halus atau foto natural, bukan full color block.

## 3. Typography

| Elemen | Font | Size |
|--------|------|------|
| Titlebar | Inter Semibold | 10pt |
| Menu bar (panel atas) | Inter Regular | 9.5pt |
| Menu item | Inter Regular | 10pt |
| Body text | Inter Regular | 10.5pt |
| Code/terminal | JetBrains Mono | 10pt |
| Button label | Inter Medium | 10pt |

Font fallback ke `Cantarell` (default GNOME) atau `DejaVu Sans` jika Inter tidak tersedia. **JANGAN** pakai font proprietary (San Francisco, Helvetica kecuali versi LTSF, Segoe UI).

## 4. Warna

mixos default palette (dark mode):

| Token | Hex | Penggunaan |
|-------|-----|------------|
| `--bg-primary` | `#1e1e1e` | Background utama window |
| `--bg-secondary` | `#2a2a2a` | Sidebar, panel |
| `--bg-tertiary` | `#353535` | Hover, elevated surface |
| `--fg-primary` | `#f5f5f5` | Text utama |
| `--fg-secondary` | `#a0a0a0` | Text sekunder |
| `--accent` | `#0a84ff` | Selection, link, focus |
| `--success` | `#30d158` | OK, connected |
| `--warning` | `#ff9f0a` | Warning |
| `--error` | `#ff453a` | Error |
| `--border` | `#3a3a3a` | Separator |

Light mode palette juga disediakan (untuk toggle). Detail di `themes/mixos-gtk/`.

## 5. Window Decoration

- **Tombol window**: posisi **kiri** (close, minimize, maximize).
- **Tombol close**: lingkaran merah muda `#ff5f57` (mirip macOS, tetapi OK karena kombinasi 3 warna hijau-kuning-merah sudah generik).
- **Tombol minimize**: lingkaran kuning `#febc2e`.
- **Tombol maximize**: lingkaran hijau `#28c840`.
- **Titlebar centered** atau left-aligned (tergantung app), default **centered** untuk app mixos.
- **Titlebar button hover**: glow halus, opacity 0.85 → 1.0.
- **Titlebar font**: Semibold, 10pt.

## 6. Dock Behavior

- **Posisi**: bottom, center-aligned.
- **Style**: glossy reflect di bawah icon (default plank), atau flat (opsional).
- **Icon size**: 32–40 px.
- **Hover effect**: bounce + zoom 120%.
- **Autohide**: aktif, muncul dengan delay 200 ms.
- **Indicator running app**: dot kecil di bawah icon.
- **Trash**: item terakhir di kanan dengan separator.
- **Drag & drop**: file/folder ke dock icon app membuka dengan app tersebut.

## 7. Menu Bar (Top Panel)

- **App indicator**: ikon kecil + nama app aktif (mis. "Finder" → "Files" di mixos untuk menghindari trademark).
- **App menu**: File, Edit, View, Window, Help (jika global menu aktif).
- **System indicator** kanan: bluetooth, network, sound, battery, clock.
- **Clock format**: `Sen 7 Jun 22:14` (locale Indonesia) atau `Sen 7 Jun` + tooltip full date.
- **Calendar popup**: klik jam → popup dengan kalender dan agenda.

## 8. File Manager (Finder-inspired)

Target layout:

```
+-----------------------------------------------------------+
| [<] [>]    [path bar]    [search]    [view] [menu] [...] |
+----+------------------------------------------------------+
|    |                                                      |
| FAV|  Icon grid atau list view                            |
| LOC|                                                      |
| TAG|  (preview panel opsional di kanan)                  |
|    |                                                      |
+----+------------------------------------------------------+
|  12 items, 24 GB free                       [status bar]  |
+-----------------------------------------------------------+
```

- **Sidebar kiri**: Favorites (Home, Documents, Downloads, Pictures, Music, Videos), Locations (Drive partitions, Network), Tags.
- **Path bar**: editable, breadcrumb saat klik kanan.
- **View toggle**: icon view / list view.
- **Status bar bawah**: jumlah item, kapasitas kosong.
- **Shortcuts**: `Space` preview (jika patch mendukung), `Enter` rename, `Cmd+L` path, `Cmd+1/2/3` view mode.

## 9. System Settings (Switchboard)

Target layout:

```
+-----------------------------------------------------------+
|  mixos Settings                                  [search] |
+----+------------------------------------------------------+
|    |                                                      |
| APP|   Title (kategori)                                  |
| DES|   Subtitle                                          |
| NET|                                                      |
| BLU|   [Control widget]                                  |
| SND|   [Control widget]                                  |
| KBD|                                                      |
| MOU|                                                      |
| USR|                                                      |
| PRV|                                                      |
| UPD|                                                      |
+----+------------------------------------------------------+
```

- **Sidebar kategori kiri**: icon + label.
- **Detail kanan**: judul besar, kontrol besar, penjelasan sekunder kecil.
- **Search bar atas**: filter plugin/plug.
- **Back button**: kembali ke daftar kategori (mirip iOS Settings).

## 10. Icon

- **Style**: flat dengan sedikit gradient, outline tipis opsional.
- **Size**: 32×32 px untuk panel, 64×64 px untuk file manager, 128×128 px untuk app grid.
- **Format**: SVG untuk theme, PNG fallback.
- **Asal**: buatan sendiri atau Papirus/Numix (open-source).

## 11. Wallpaper

- **Default**: gradient biru-ungu gelap, atau foto natural (gunung, langit, air) dengan tone tenang.
- **Format**: 5120×2880 atau lebih besar, JPG/PNG, ukuran < 5 MB.
- **Asal**: buatan sendiri, atau open-source dari Unsplash/Pexels/Wikimedia dengan lisensi CC0/CC-BY.
- **Jangan**: wallpaper Apple/macOS asli, wallpaper elementary asli (sebagai default akhir).

## 12. Sound

- **Default**: tidak ada suara startup (privasi).
- **System sounds**: opsional, sourced dari GNOME sounds (open-source) atau Sun sounds.
- **Volume**: default 70% saat first boot.

## 13. Accessibility

- **DPI scaling**: 100% default, tersedia 125%, 150%, 200%.
- **High contrast mode**: toggle.
- **Reduced motion**: respect GNOME setting `interface-enable-animations`.
- **Cursor size**: 24, 36, 48, 64.
- **Font scaling**: 0.875×, 1.0×, 1.125×, 1.25×, 1.5×.

## 14. Boot & Login

- **Plymouth**: logo mixos + spinner, warna tema gelap, durasi 5–10 detik.
- **GRUB**: tema mixos, font Inter, timeout 5 detik.
- **Login screen**: wallpaper mixos, form center, input compact.

## 15. Out of Style (Tidak Dilakukan)

- Glassmorphism (blurring) untuk window: **tidak** di Linux Wayland, berat.
- Sidebar transparan dengan blur window di belakangnya: **terbatas** di Mutter, tidak di gala.
- Floating dock dengan parallax: **tidak** realistis.
- Universal Control, Handoff, Continuity: **tidak mungkin** tanpa proprietary protocol.

## 16. Kriteria Sukses Tahap Awal

mixos dianggap "layak pakai internal" jika:

1. ISO bootable di QEMU dan VirtualBox.
2. Branding mixos muncul di About, login, Plymouth, GRUB.
3. Top panel, dock, titlebar, window control sesuai spec.
4. File manager terasa lebih "Finder-like" (sidebar rapi, view compact).
5. System Settings switchboard terasa lebih "System Settings-like" (sidebar kategori).
6. Global menu bekerja minimal untuk 1 app (mis. Files dan Terminal).
7. ISO build reproducible (checksum sama untuk input sama).

## 17. Penutup

mixos mengadaptasi **estetika** dan **prinsip** macOS, bukan **aset** macOS. Setiap elemen visual dirancang ulang atau di-sumber dari asset open-source. Dokumentasi ini akan diperbarui seiring implementasi.
