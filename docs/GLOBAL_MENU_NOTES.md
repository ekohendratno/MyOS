# GLOBAL_MENU_NOTES — Keterbatasan Global Menu di mixos

Dokumen ini menjelaskan **secara jujur** keterbatasan teknis implementasi global menu (menu bar global di top panel) di lingkungan GTK/Linux, dan apa yang bisa dicapai mixos.

## 1. Apa itu Global Menu?

Global menu adalah pola di mana **menu bar aplikasi** (File, Edit, View, Window, Help) tidak ditampilkan di titlebar window aplikasi, melainkan di **top panel desktop** (di samping indicator app aktif). Ini adalah ciri khas macOS.

Tujuan UX:
- Menghemat ruang vertikal.
- Konsistensi akses menu di semua app.
- Mengurangi clutter visual di titlebar.

## 2. Bagaimana Global Menu Bekerja di macOS?

Di macOS, NSMenu (AppKit) mengirim menu ke sistem operasi via protokol internal Apple. Sistem operasi menampilkan menu di menu bar atas. App mengirim sinyal `setMenuBar:` ke NSApp.

Di Linux/GTK, ada **standar DBus** dari Canonical (`com.canonical.AppMenu.Registrar`) yang dipakai Ubuntu Unity dulu, dan sekarang beberapa DE modern (KDE, GNOME dengan extension, elementary OS dengan patch).

## 3. Standar Teknis yang Tersedia

### 3.1 DBusMenu (Standar Canonical)
- Protocol: `com.canonical.dbusmenu`.
- App mendaftarkan menu di session bus dengan path `/com/canonical/menu/<id>`.
- Listener (Unity, kde-appmenu, appmenu-gtk-module) menerima sinyal dan render di top panel.
- Diperlukan: `appmenu-gtk-module` (untuk GTK2/GTK3), `dbusmenu-glib`, `indicator-application`.

### 3.2 GtkApplication DBus (Standar GTK4)
- GTK4 (>= 4.4) mengirim menu via `GApplication` DBus.
- Setting GSettings: `org.gnome.desktop.interface :: gtk-application-prefers-app-menu` (bool).
- Didukung penuh di GNOME 45+.

### 3.3 KDE AppMenu
- KDE Plasma mengirim menu via DBusMenu.
- kde-appmenu bisa di-load sebagai plugin.

## 4. Status Global Menu di Pantheon (elementary OS)

**Pantheon TIDAK memiliki global menu bawaan.**

wingpanel di Pantheon adalah panel indikator (ayatana-appindicator style), bukan panel menu aplikasi. Tidak ada bridge DBusMenu bawaan.

Implementasi di mixos harus menambahkan salah satu dari:

- `wingpanel-appmenu` sebagai indikator/loader plugin.
- `vala-panel-appmenu` (Xfce panel) di-embed ke wingpanel (sulit, tidak direkomendasikan).
- `kde-appmenu` dengan modifikasi.

## 5. Keterbatasan yang Tidak Bisa Diakali

### 5.1 Aplikasi GTK3 (LibreOffice 7.x, GIMP, Inkscape, dll.)
- Beberapa mengirim DBusMenu (LibreOffice, Inkscape, Evolution).
- Banyak yang **TIDAK** mengirim (Firefox, Chromium, beberapa app GTK3 sederhana).
- App GTK3 yang dikompilasi tanpa `appmenu-gtk-module` **tidak** akan bekerja.

### 5.2 Aplikasi GTK4 (Files, Terminal, Code, sebagian besar app elementary modern)
- GTK4 >= 4.4 mengirim `GtkApplication::menubar` ke desktop.
- GNOME, elementary OS 8.x: dukungan GSettings `gtk-application-prefers-app-menu`.
- **Jika diset true, GTK4 akan mengirim menu ke DBus.**
- mixos akan mengaktifkan setting ini, sehingga app GTK4 elementary (Files, Terminal, Calculator, dll.) seharusnya bekerja.

### 5.3 Aplikasi Flatpak
- Flatpak apps terisolasi dalam sandbox.
- App di Flatpak perlu portal Flatpak untuk komunikasi DBus.
- **Standar portal untuk DBusMenu belum stabil** di Flatpak.
- Banyak Flatpak app (mis. Firefox dari Flathub) tidak mengirim AppMenu ke host.
- mixos **tidak akan memaksa** integrasi Flatpak; fallback ke menu app-internal.

### 5.4 Aplikasi Electron
- Electron mengirim menu via `Menu.setApplicationMenu()` yang **tidak** diteruskan ke DBus.
- Workaround: ada `electron-appmenu` unofficial, tetapi tidak stabil, dan banyak app ignore.
- **Mayoritas Electron app (VS Code, Discord, Slack, Obsidian, Notion, Spotify) TIDAK akan menampilkan global menu.**

### 5.5 Aplikasi Qt (KDE apps, Krita, dll.)
- Qt >= 5.10 mendukung DBusMenu melalui `QMenuBar` dan `QDBusMenu`.
- App Qt yang dikompilasi dengan `dbusmenu-qt5` bisa bekerja.
- Banyak app Qt yang dikirim di Linux (Krita, qBittorrent) mendukung.

### 5.6 Aplikasi Proprietary non-Linux-native
- Zoom, Skype, Teams (Electron-based) **TIDAK** mengirim AppMenu.
- App Android (Anbox/Waydroid) **TIDAK** relevan.

### 5.7 Browser (WebKit/Chromium-based)
- **TIDAK** mengirim DBusMenu.
- **TIDAK** mengirim GtkApplication menu.
- GNOME Web (Epiphany) mengirim GtkApplication menu (karena GTK4 native).
- Firefox: **TIDAK** mengirim apa pun untuk menu.
- Chromium: **TIDAK** mengirim apa pun.

## 6. Strategi mixos untuk Global Menu

### 6.1 Layer Implementasi

```
+-------------------------------------------------+
|                wingpanel (top panel)             |
|                                                 |
|  [app icon + name]  [File Edit View ... Help]   |
|       (1)              (2)                       |
+-------------------------------------------------+
                  ^
                  | DBusMenu + GtkApplication
                  |
+-------------------------------------------------+
|                Application                       |
|   - GTK4 native (sebagian besar)                |
|   - LibreOffice (DBusMenu)                      |
|   - Inkscape (DBusMenu)                         |
|   - Firefox/Chromium/Electron (TIDAK terhubung) |
+-------------------------------------------------+
```

(1) Indikator app: indikator kustom yang membaca app aktif via `org.gnome.Shell` atau `_NET_ACTIVE_WINDOW` dan ganti icon di panel.

(2) Menu global: panel kedua yang di-render oleh plugin `wingpanel-appmenu`, mendengarkan sinyal DBusMenu dan GtkApplication.

### 6.2 Rencana Implementasi

1. **Aktifkan GSettings GTK4**:
   ```
   gsettings set org.gnome.desktop.interface gtk-application-prefers-app-menu true
   ```

2. **Install dependencies**:
   - `appmenu-gtk-module` (untuk fallback GTK3)
   - `dbusmenu-glib`
   - `indicator-application`
   - `libdbusmenu-gtk3` (untuk app yang compile-time support)

3. **Patch wingpanel**:
   - Tambahkan indikator `appmenu`.
   - Indikator membaca window aktif, request menu via DBus, render di panel.

4. **Patch gala** (opsional):
   - Saat window focus berubah, kirim sinyal ke indikator appmenu.
   - Set window property `_GTK_APP_MENU` jika memungkinkan.

5. **Fallback untuk app yang tidak support**:
   - Menu tetap ditampilkan di titlebar window (default behavior).
   - Indikator app di panel hanya update icon + nama app.

### 6.3 Target App yang Bekerja

| App | Global Menu? | Catatan |
|-----|--------------|---------|
| pantheon-files | Ya | GTK4 native |
| pantheon-terminal | Ya | GTK4 native |
| io.elementary.code | Ya | GTK4 native |
| io.elementary.calculator | Ya | GTK4 native |
| LibreOffice Writer/Calc | Ya | DBusMenu built-in |
| Inkscape | Ya (1.x), Tidak (2.x) | Tergantung build |
| Firefox | Tidak | Tidak ada support |
| Chromium | Tidak | Tidak ada support |
| VS Code (Electron) | Tidak | Tidak ada support |
| Discord (Electron) | Tidak | Tidak ada support |
| GIMP | Tidak (3.x) | Menu internal |
| Zoom | Tidak | Electron |

## 7. Risiko dan Mitigasi

### 7.1 Stabilitas
- DBusMenu crash bisa menutup app atau panel.
- **Mitigasi**: monitor `gala` dan `wingpanel` dengan restart on-crash, log error ke journald.

### 7.2 Wayland Compatibility
- X11 menyediaka `_NET_ACTIVE_WINDOW` yang sederhana.
- Wayland memerlukan protokol `wlr-foreign-toplevel-management` atau implementasi Gala Wayland.
- Pantheon masih default ke X11 di 8.x; Wayland eksperimental.
- **mixos tahap awal target X11 dulu**, Wayland sebagai backlog.

### 7.3 Konflik dengan Titlebar
- Beberapa app (terutama GTK3) crash jika titlebar dihilangkan.
- mixos TIDAK menghilangkan titlebar; titlebar tetap ada, global menu adalah **additive**.
- Override via Gala: maximize dan hide-titlebar setting tidak diaktifkan global.

## 8. Out of Scope (Tidak Dilakukan)

- **Global menu untuk webapp** (Progressive Web App, Fluid App-style) — tidak mungkin tanpa wrapper.
- **Search dalam menu** (sub-menu filter) — tidak standar di Linux.
- **Custom keyboard shortcut per-menu** — tidak standar, sulit di-implement.

## 9. Penutup

Global menu di mixos adalah **eksperimen teknis**, bukan fitur wajib. Sebagian besar app akan tetap menggunakan menu di titlebar. mixos hanya menjamin global menu bekerja untuk app GTK4 elementary dan LibreOffice. Untuk app lain, fallback ke behavior standar. Hal ini harus dikomunikasikan dengan jelas kepada pengguna mixos agar tidak ada ekspektasi yang tidak realistis.
