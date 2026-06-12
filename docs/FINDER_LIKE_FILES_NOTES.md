# FINDER_LIKE_FILES_NOTES — Keterbatasan File Manager Finder-like di mixos

Dokumen ini menjelaskan target dan keterbatasan membuat pantheon-files (file manager bawaan elementary) terasa lebih mirip Finder dari macOS.

## 1. Apa itu Finder?

Finder adalah file manager default macOS dengan ciri:

- **Sidebar kiri** dengan section: Favorites, Locations, Tags, Network.
- **Path bar** di atas konten.
- **Status bar** di bawah.
- **Multi-view**: Icon, List, Column, Gallery.
- **Quick Look** dengan `Space` untuk preview.
- **Get Info** inspector.
- **Tags** (label warna).
- **Search bar** dengan filter.
- **Drag & drop** ke app dock atau desktop.
- **Tab** (multiple tab di satu window).
- **Breadcrumb path** yang bisa diklik.
- **Spring-loaded folders** (drag ke folder auto-open).

## 2. Status pantheon-files (Files)

pantheon-files adalah fork dari `nautilus` (GNOME Files) yang ditulis ulang sebagian dalam GTK4 dengan Granite. Versi di elementary OS 8.x adalah **generasi baru** (julukan "Files 7" atau "elementary Files") yang:

- Berbasis GTK4 + libadwaita + Granite 7.
- Single document interface (SDI), bukan Multiple document interface (MDI) lagi.
- Sidebar sudah ada (mirip Nautilus).
- Icon view, list view sudah ada.
- **TIDAK** punya column view.
- **TIDAK** punya Quick Look built-in.
- **TIDAK** punya Gallery view.
- **TIDAK** punya Tab (SDI).
- **TIDAK** punya breadcrumb path bar yang bisa diklik (path bar editable, tapi tidak seperti Finder breadcrumb).

## 3. Target mixos: Finder-like, Bukan Finder Clone

mixos bertujuan membuat pantheon-files terasa lebih **mirip Finder** dalam hal:

1. Sidebar rapi dengan kategori jelas.
2. Toolbar compact dengan kontrol yang mudah ditemukan.
3. Icon view default, dengan grid yang konsisten.
4. Status bar informatif.
5. Shortcut intuitif.
6. Tampilan bersih tanpa clutter.

mixos **TIDAK** bertujuan:

- Mengkloning Finder 100%.
- Mengimplementasikan semua fitur proprietary Finder.
- Membajak aset visual Finder (icon, icon set, layout proprietary).

## 4. Apa yang Bisa Diubah dengan Patch

### 4.1 Sidebar Layout
- **Status**: sudah ada di pantheon-files.
- **Patch**: restrukturisasi section, urutan item, ikonografi.
- **Target**:
  ```
  Sidebar
  ├── Favorites
  │   ├── Home
  │   ├── Documents
  │   ├── Downloads
  │   ├── Pictures
  │   ├── Music
  │   └── Videos
  ├── Locations
  │   ├── Root (/)
  │   ├── Boot (jika ada)
  │   └── Drive lain
  ├── Tags (jika ada)
  └── Network
      └── Network (SMB, SFTP)
  ```

### 4.2 Toolbar
- **Status**: sudah ada (back, forward, view toggle, search).
- **Patch**: kompakkan, tambahkan breadcrumb-style path editor.
- **Target**:
  ```
  [back] [forward]  [path editor]  [search]  [view:icon|list]  [menu]
  ```

### 4.3 Icon View
- **Status**: sudah ada, dengan zoom.
- **Patch**: konsistensi grid spacing, label truncation policy, default zoom level.

### 4.4 List View
- **Status**: sudah ada.
- **Patch**: kolom default (Name, Size, Type, Modified), bisa di-sort, ukuran kolom proporsional.

### 4.5 Status Bar
- **Status**: sudah ada di Nautilus, mungkin tidak di pantheon-files baru.
- **Patch**: tambahkan kembali status bar dengan info jumlah item, free space.

### 4.6 Shortcut
- `Cmd+L`: focus ke path bar.
- `Cmd+1/2`: icon/list view.
- `Cmd+Shift+.`: show hidden files (toggle).
- `Cmd+,`: preferences.
- `Space`: preview (lihat §5).
- `Enter`: rename (sudah standar).
- `Cmd+Backspace`: move to trash.
- `Cmd+Shift+N`: new folder.
- `Cmd+T`: new tab (lihat §5.7).

## 5. Apa yang TIDAK Bisa / Sangat Sulit

### 5.1 Column View
- **Status**: TIDAK ADA di pantheon-files.
- **Tantangan**:
  - Column view di Nautilus dihapus sejak 3.x.
  - Implementasi ulang di GTK4 + Granite 7 butuh effort besar.
  - Resizable column, recursive browsing, dan breadcrumb otomatis.
- **Alternatif**:
  - Pakai plugin pihak ketiga (mis. `nautilus-columns` tua, tidak kompatibel GTK4).
  - Tulis ulang column view dari awal (effort 3–6 bulan).
- **mixos keputusan**: TIDAK di tahap awal. Tandai sebagai **backlog**.

### 5.2 Quick Look dengan `Space`
- **Status**: TIDAK ADA built-in.
- **Tantangan**:
  - Quick Look macOS render preview multi-format (PDF, video, gambar, text) di window overlay.
  - Implementasi Linux: `sushi` (GNOME) adalah pendekatan, tetapi `sushi` sudah deprecated di GNOME 45.
  - File manager GTK4 elementary tidak ada Quick Look.
- **Alternatif**:
  - Pakai `sushi` jika masih berfungsi.
  - Pakai `tumbler` (D-Bus thumnailer) untuk preview di file manager.
  - Tulis plugin custom yang load file di overlay (effort besar).
- **mixos keputusan**: TIDAK di tahap awal. Tandai sebagai **nice-to-have**.

### 5.3 Gallery View
- **Status**: TIDAK ADA.
- **Tantangan**: Gallery view di Finder menampilkan foto dengan cover flow horizontal. Butuh custom widget GTK4 atau gunakan `libclutter` (deprecated) atau `gst-play` (GStreamer).
- **mixos keputusan**: TIDAK di tahap awal.

### 5.4 Get Info Inspector
- **Status**: partial di pantheon-files (properties dialog).
- **Patch**: tambahkan side-panel inspector yang persistent (mirip Finder "Get Info").
- **mixos keputusan**: BACKLOG. Bisa diiterasi kemudian.

### 5.5 Spring-loaded Folders
- **Status**: TIDAK ADA.
- **Tantangan**: Deteksi drag hover dengan timer, auto-open folder. Standar di macOS, sulit di Linux.
- **mixos keputusan**: TIDAK di tahap awal.

### 5.6 Tags
- **Status**: sudah ada di pantheon-files (Granite mendukung).
- **Patch**: TIDAK banyak dibutuhkan, default upstream sudah OK.

### 5.7 Tab
- **Status**: pantheon-files **SDI**, tidak ada tab.
- **Tantangan**: SDI adalah keputusan desain elementary. Tab adalah fitur Nautilus MDI yang dihapus.
- **mixos keputusan**: TIDAK di tahap awal (mengubah paradigma SDI butuh fork besar).

### 5.8 Breadcrumb Path Bar
- **Status**: path bar editable, bukan breadcrumb.
- **Patch**: tambahkan breadcrumb widget di toolbar (mirip Finder, klik folder di path).
- **mixos keputusan**: COBA di tahap awal sebagai patch ringan.

### 5.9 Search dengan Filter
- **Status**: search sudah ada.
- **Patch**: tambahkan dropdown filter (by type, by date, by size). Bisa pakai Granite widget atau custom.
- **mixos keputusan**: BACKLOG.

## 6. Strategi Patch Pantheon-Files

### 6.1 Patch Ringan (Tahap Awal)
- Sidebar: reorder dan grouping.
- Toolbar: kompakkan layout.
- Default view: icon view, zoom 100%.
- Default sort: by name ascending.
- Status bar: tambahkan.
- Shortcut: `Cmd+L`, `Cmd+1/2`, `Cmd+Shift+.`, `Cmd+,`.
- Breadcrumb path (opsional, coba).

### 6.2 Patch Sedang (Tahap Lanjutan)
- Filter dropdown di search.
- Iconography sidebar disesuaikan dengan mixos.
- Hidden file default OFF (privacy).

### 6.3 Fork Komponen (Jangka Panjang)
- Column view: fork atau tulis ulang.
- Quick Look: plugin atau daemon terpisah.
- Gallery view: opsional.

## 7. Aset yang Dilarang dalam Patch

- Icon Finder asli.
- String UI Finder ("Finder", "Get Info", "Quick Look" — boleh pakai "Quick Look" karena generik, TIDAK boleh "Get Info" karena Apple trademark, ganti "Properties").
- Wallpaper Finder (tidak relevan).
- Animation Finder proprietary.

## 8. Out of Scope

- iCloud integration.
- Tag sync ke Apple Notes/Reminders.
- Universal file picker yang iOS-style.
- Server-side index (Spotlight untuk file).
- Content-based file search.

## 9. Penutup

mixos tidak akan pernah menjadi Finder. mixos akan mendekati Finder dalam hal **kebersihan visual** dan **konsistensi UX**, sambil tetap menggunakan komponen open-source. Ekspektasi harus realistis: file manager mixos adalah **file manager GTK4 yang bagus**, bukan tiruan Finder.

Dokumen ini akan diperbarui seiring perkembangan patch.
