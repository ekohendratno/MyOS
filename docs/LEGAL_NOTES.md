# LEGAL_NOTES — Catatan Hukum & Lisensi mixos

Dokumen ini menjelaskan batasan hukum dan lisensi yang harus dipatuhi selama pengembangan dan distribusi mixos.

## 1. Pernyataan Posisi mixos

mixos **BUKAN**:

- macOS, OS X, atau produk Apple apa pun.
- elementary OS resmi, distribusi resmi elementary, Inc., atau produk elementary.
- Distro Linux yang didukung, di-endorse, atau di-afiliasi dengan elementary, Inc.
- Distribusi komersial.

mixos adalah project open-source eksperimental/pribadi yang dibangun di atas komponen open-source elementary OS, Pantheon, dan Debian.

## 2. Aset yang DILARANG

Anda **TIDAK BOLEH** memasukkan ke dalam mixos (atau turunannya) aset berikut:

### 2.1 Aset Apple
- Logo Apple (ikon Apple, " bitten apple", silhouette Apple).
- Nama "Apple", "macOS", "OS X", "Mac", "Macintosh".
- Wallpaper resmi macOS / OS X dalam bentuk apa pun.
- Icon aplikasi proprietary Apple (Finder, Safari, Mail, Messages, dll.).
- Cursor proprietary Apple.
- Font proprietary Apple (San Francisco, SF Pro, SF Mono, New York, Helvetica Neue kecuali versi open-source berlisensi).
- Soundscape macOS (suara startup, suara alert, dsb.).
- Screenshot macOS sebagai referensi visual yang diklaim sebagai "persis sama".
- Boot loader, login screen, atau animasi proprietary Apple.
- Dokumentasi, string UI, atau terjemahan dari macOS.

### 2.2 Aset elementary OS
- Logo elementary (ikon "e" di dalam lingkaran) sebagai branding akhir mixos.
- Wallpaper resmi elementary OS.
- Tema "elementary" bawaan yang diklaim sebagai branding mixos.
- Nama "elementary OS" di splash, About, atau halaman web resmi mixos.
- String "powered by elementary" atau frasa serupa yang menyesatkan.

### 2.3 Aset Pihak Ketiga Lainnya
- Aset yang tidak jelas lisensinya (no license / proprietary).
- Aset berlisensi "personal use only" atau "non-commercial".
- Font Microsoft (Arial, Calibri, Segoe UI) kecuali via package Microsoft yang tersedia resmi.
- Font proprietary lain (Helvetica kecuali Linotype LTSF, Roboto dari Android kecuali Apache, dsb.).

## 3. Yang BOLEH Digunakan

Anda boleh menggunakan:

- Aset buatan sendiri (logo mixos, wallpaper mixos, icon mixos).
- Aset open-source dengan lisensi permissive (MIT, BSD, Apache 2.0, CC0, CC-BY 4.0, CC-BY-SA 4.0, OFL 1.1, GPL, LGPL).
- Icon theme open-source: **Papirus**, **Adwaita**, **Numix Circle**, **Tela**, **La Capitaine** (cek lisensi masing-masing).
- Cursor theme open-source: **Bibata**, **Capitaine**, **DMZ**, **Adwaita**.
- Font open-source: **Inter**, **Cantarell**, **DejaVu Sans**, **Liberation Sans**, **Noto Sans**, **Hack**, **JetBrains Mono**, **Fira Sans/Code**, **Roboto** (via package Debian).
- Wallpaper dari situs berlisensi CC0/CC-BY (Unsplash dengan cek lisensi, Pexels, Wikimedia Commons dengan filter lisensi).
- Plymouth theme open-source.
- GRUB theme open-source.

## 4. Atribusi Wajib

Setiap aset open-source pihak ketiga yang digunakan **WAJIB** menyertakan:

- Nama aset dan creator/asal.
- Lisensi asli.
- Tautan ke sumber asli.
- Pernyataan modifikasi (jika dimodifikasi).

Disimpan dalam `branding/ATTRIBUTION.md` dan/atau `licenses/THIRD_PARTY_LICENSES.txt`.

## 5. Branding mixos

mixos harus menampilkan:

- Nama "mixos" dengan penulisan konsisten (lowercase, tanpa capslock bombastis).
- Logo mixos buatan sendiri.
- Tahun rilis, versi, dan kode nama yang jelas.
- Link ke repository sumber (jika dipublikasikan).
- Pernyataan: "mixos is a custom build based on elementary OS and the Pantheon desktop. It is not affiliated with elementary, Inc."

## 6. Distribusi

Jika Anda mendistribusikan ulang mixos (ISO, VM image, container image):

- Wajib menyertakan `docs/LEGAL_NOTES.md` ini.
- Wajib menyertakan `branding/ATTRIBUTION.md`.
- Wajib menyertakan changelog.
- Wajib menyertakan `licenses/THIRD_PARTY_LICENSES.txt`.
- **Dilarang** menggunakan nama "elementary" dalam nama rilis (mis. "mixos elementary edition", "elementary mixos") tanpa izin.
- **Dilarang** menggunakan domain `elementary.io` atau subdomain di dalamnya.
- **Dilarang** menggunakan trademark "elementary" di header HTTP, signature email, atau media sosial untuk menyesatkan.

## 7. Komponen yang Dilisensikan GPL

Berikut komponen utama yang dipakai mixos dan lisensinya:

| Komponen | Lisensi | Keterangan |
|----------|---------|------------|
| elementary OS build system | MIT | `github.com/elementary/os` |
| gala (window manager) | GPL-3.0 | Pantheon upstream |
| wingpanel (top panel) | GPL-3.0 | Pantheon upstream |
| plank (dock) | GPL-3.0 | fork dari docky |
| pantheon-files | GPL-3.0 | Pantheon upstream |
| switchboard | GPL-3.0 | Pantheon upstream |
| granite (stylesheet) | LGPL-3.0 | Pantheon upstream |
| pantheon-greeter | GPL-3.0 | Pantheon upstream |
| io.elementary.installer | GPL-3.0 | Pantheon upstream |
| Debian base | beragam (banyak GPL) | `debian.org` |
| live-build | GPL-3.0 | Debian |

Setiap patch mixos yang dimodifikasi dari komponen di atas **harus** tetap di bawah lisensi yang sama (copyleft).

## 8. Ringkasan Aman

Gunakan selalu istilah **"macOS-inspired"**, **"macOS-like"**, atau **"bernuansa macOS"**, **BUKAN** "macOS clone", "macOS remake", atau "macOS replacement".

mixos **TIDAK** kompatibel dengan macOS, **TIDAK** menjalankan aplikasi macOS, dan **TIDAK** mengklaim sebagai produk Apple.

---

Disusun sebagai bagian dari dokumentasi wajib mixos project.
