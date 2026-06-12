# DESKTOP_ROADMAP — Peta Jalan Desktop mixos

Dokumen ini menjelaskan peta jalan teknis transformasi Pantheon (elementary OS) menjadi desktop mixos yang macOS-inspired. Disusun berdasarkan tingkat kesulitan dan dependensi.

## 1. Prinsip Umum

- **Bertahap**: setiap milestone harus stabil sebelum lanjut.
- **Non-destruktif**: patch mixos harus bisa di-undo dengan `git apply -R`.
- **Bersifat jujur**: keterbatasan teknologi (GTK3, Flatpak, Wayland) harus didokumentasikan.
- **Open-source only**: tidak ada binary proprietary, tidak ada serial偷, tidak ada crack.

## 2. Komponen Pantheon: Status dan Target

| Komponen | Status Upstream | Target mixos | Tingkat Kesulitan | Strategi |
|----------|-----------------|--------------|-------------------|----------|
| gala (WM) | Window control kanan, titlebar besar | Window control kiri, titlebar compact, layout tweaks | Sedang–Tinggi | Patch `WindowControls`, `WindowFrame`, layout constants |
| wingpanel (panel atas) | Indicator list standar | Menu bar style, padding kecil, font lebih kecil, area indicator ditata ulang | Sedang | Patch wingpanel + GSettings schema override |
| plank (dock) | Bottom dock, default config | Bottom center, autohide, icon size lebih kecil, tema custom | Rendah–Sedang | File config plank + tema plank custom |
| pantheon-files | Files (Nautilus fork) | Finder-like: sidebar, toolbar, icon view, column view opsional | Sedang–Tinggi | Patch pantheon-files (jangka panjang) |
| switchboard | Settings app | Sidebar kategori kiri, detail kanan, grouping System Settings-like | Sedang | Patch switchboard plugins + layout |
| pantheon-greeter | Login screen | Branding mixos, wallpaper mixos, layout | Rendah | Override asset + GSettings |
| io.elementary.installer | Installer | Branding, hostname default "mixos", disk label | Rendah | Patch installer + asset |
| granite (stylesheet) | Style Pantheon | Style mixos (warna, padding, radius) | Rendah | Override CSS Granite + `gtk.css` |
| AppMenu / DBusMenu | Tidak ada di Pantheon | Global menu untuk app GTK4 + LibreOffice | Tinggi, parsial | Plugin wingpanel + GSettings |

## 3. Roadmap per Tahap

### Tahap 3 — Branding (Rendah)
- `/etc/os-release` mixos.
- Default hostname `mixos`.
- ISO label "MIXOS".
- Logo, wallpaper, Plymouth, GRUB placeholder.
- About OS placeholder.

**Deliverable:** ISO yang di-remaster menampilkan identitas mixos saat boot dan About.

### Tahap 4 — Desktop Layout (Rendah–Sedang)
- Top panel (wingpanel) ditata ulang: padding kecil, font kecil.
- Plank dock: bottom-center, icon size 32–40 px, autohide, zoom 120%.
- Titlebar: padding kecil, font lebih kecil, tombol window di kiri.
- Default font: Inter / Cantarell 9–10pt.
- Default cursor: Bibata atau Capitaine.
- Default icon theme: Papirus atau Numix.
- Wallpaper default mixos.

**Deliverable:** desktop terasa lebih compact dan rapi.

### Tahap 5 — Global Menu (Eksperimen)
- Implementasi: `wingpanel-appmenu` sebagai plugin.
- Integrasi GTK4: GSettings `gtk-application-prefers-app-menu = true`.
- Limitasi eksplisit untuk GTK3, Flatpak, Electron, Chromium, Firefox.
- Fallback: jika app tidak support, tampilkan menu di titlebar seperti biasa.

**Deliverable:** global menu bekerja untuk beberapa app, dokumentasi keterbatasan jelas.

### Tahap 6 — Finder-like Files (Sedang)
- Sidebar kiri: Favorites, Locations, Tags.
- Toolbar compact: Back/Forward, path bar, search, view toggle.
- Icon view default, list view sebagai alternatif.
- Column view: implementasi terbatas via `pantheon-files-column-extension` atau patch internal.
- Preview panel: opsional, toggle via menu.
- Shortcut Space: preview, Enter: rename (default Files).

**Deliverable:** pantheon-files terasa lebih mirip Finder, bukan Nautilus default.

### Tahap 7 — System Settings (Sedang)
- Sidebar kategori kiri (mirip System Settings).
- Detail kanan.
- Kategori: Appearance, Desktop & Dock, Display, Network, Bluetooth, Sound, Keyboard, Mouse & Trackpad, Users, Privacy & Security, Updates.
- Beberapa plugin bawaan perlu di-rearrange atau di-rename.

**Deliverable:** switchboard terlihat lebih konsisten dengan referensi System Settings.

### Tahap 8 — Build System (Sedang–Tinggi)
- `scripts/clone-upstream.sh`: clone `elementary/os`, pin ke tag `8.1.x`.
- `scripts/prepare-build-env.sh`: cek dependency (debootstrap, live-build, xorriso).
- `build.sh`: orchestrasi build di container.
- `clean.sh`: hapus folder build (dengan validasi).
- `test-vm.sh`: uji ISO via QEMU.
- `scripts/verify-iso.sh`: cek isi ISO, signature, checksum.

**Deliverable:** build script bisa menghasilkan ISO mixos secara reproducible (waktu build 2–6 jam).

### Tahap 9 — Packages (Rendah)
- `config/packages.list`: paket tambahan.
- `config/remove-packages.list`: paket yang dihapus (mis. branding elementary proprietary).
- `config/repositories.list`: repo tambahan (jika ada).

**Deliverable:** paket mixos terkonfigurasi.

### Tahap 10 — Legal & Finalisasi (Rendah)
- `docs/LEGAL_NOTES.md` final.
- `branding/ATTRIBUTION.md` final.
- `licenses/THIRD_PARTY_LICENSES.txt` final.
- Rilis ISO internal untuk uji coba.

**Deliverable:** ISO mixos siap uji coba internal.

## 4. Keterbatasan yang Harus Diterima

- **Window control posisi (kiri)**: butuh patch gala. Upstream tidak support config.
- **Titlebar sangat kecil**: butuh patch gala. Compiz-style resizing mungkin terbatas.
- **Global menu**: hanya bekerja untuk app yang mengirim DBus AppMenu. Banyak app GTK3, Flatpak sandbox, dan Electron **TIDAK** akan comply.
- **Finder-like file manager**: pantheon-files adalah fork Nautilus GTK4, banyak fitur Finder (column view penuh, Quick Look dengan preview universal) sulit atau tidak mungkin ditiru 100%.
- **System Settings**: switchboard adalah GTK4 app, layout bisa didekati tetapi tidak akan identik dengan System Settings.
- **Wallpaper dinamis (mirip macOS Sonoma)**: tidak mungkin tanpa komponen tambahan (hack seperti `variety` atau script custom), tidak masuk scope tahap awal.
- **Spotlight/Universal Search**: Pantheon punya `appcenter` search terbatas. `slingshot-launcher` adalah launcher sederhana. Implementasi Spotlight-like butuh effort besar.
- **Mission Control / Exposé**: gala punya workspace overview, tetapi tidak bisa di-clone 100% fitur Exposé.
- **Hot corners**: bisa didekati dengan `hotcorners` daemon atau script custom.

## 5. Prioritas Implementasi

1. **Mudah & dampak besar**: branding, wallpaper, default settings, dock config, icon theme, cursor.
2. **Sedang & dampak besar**: titlebar size, panel padding, fonts, Plymouth, GRUB.
3. **Sulit & dampak besar**: global menu (parsial), Finder-like, System Settings layout.
4. **Sangat sulit & dampak kecil/niche**: Mission Control clone, Spotlight clone, wallpaper dinamis.

## 6. Out of Scope (untuk Tahap 1–10)

- Dukungan macOS-style trackpad gestures penuh (beberapa sudah ada di libinput-gestures, tetapi clone 100% tidak realistis).
- iCloud, Apple ID, integrasi proprietary Apple apa pun.
- Boot animation proprietary.
- iOS-style lock screen.
- Universal Control (sync clipboard/keyboard antar device).

## 7. Penutup

mixos adalah **eksplorasi UX desktop Linux**, bukan klaim menjadi macOS. Setiap komponen yang ditambahkan harus melalui proses:

1. Apakah bisa dicapai dengan config/theme saja? (lebih dulu)
2. Apakah bisa dicapai dengan patch ringan? (kedua)
3. Apakah perlu fork komponen? (terakhir)

Urutan ini meminimalkan biaya pemeliharaan dan memudahkan upstream sync.
