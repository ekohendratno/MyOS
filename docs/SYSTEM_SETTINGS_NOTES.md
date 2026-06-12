# SYSTEM_SETTINGS_NOTES — Keterbatasan Switchboard Layout di mixos

Dokumen ini menjelaskan target dan keterbatasan membuat switchboard (System Settings bawaan elementary) terasa lebih mirip System Settings dari macOS.

## 1. Apa itu System Settings macOS?

System Settings (sebelumnya System Preferences) di macOS Ventura+ menggunakan layout:

```
+-----------------------------------------------------------+
|  System Settings                              [search]    |
+----+------------------------------------------------------+
|    |                                                      |
| APP|   Appearance                                        |
| DES|   Make the controls easier to see and use           |
| NET|                                                      |
| BLU|   [Light] [Dark] [Auto]                              |
| SND|                                                      |
| KBD|   Accent color: [Blue] [Purple] [Pink] [Red] ...     |
| MOU|                                                      |
| USR|                                                      |
| PRV|                                                      |
| UPD|                                                      |
+----+------------------------------------------------------+
```

Ciri khas:
- **Sidebar kategori** dengan icon + label.
- **Detail panel** kanan dengan judul besar, deskripsi kecil, kontrol besar.
- **Search bar** di atas sidebar.
- **Single-page** per kategori (bukan modal/wizard).
- **Visual language** yang konsisten: large icons, large text, big controls.

## 2. Status Switchboard (elementary OS)

Switchboard adalah System Settings elementary OS yang:

- Berbasis GTK4 + Granite 7.
- **Plugin-based** architecture: setiap kategori adalah plugin.
- Layout **Grid** (bukan sidebar). Tile-widget yang disusun grid.
- Tidak ada sidebar.
- Tidak ada search bar bawaan (meskipun `switchboard-plug-security` punya search internal).
- Plugin-plugin:
  - `switchboard-plug-about`
  - `switchboard-plug-applications`
  - `switchboard-plug-bluetooth`
  - `switchboard-plug-datetime`
  - `switchboard-plug-display`
  - `switchboard-plug-keyboard`
  - `switchboard-plug-mouse`
  - `switchboard-plug-network`
  - `switchboard-plug-notifications`
  - `switchboard-plug-onlineaccounts`
  - `switchboard-plug-pantheon-shell`
  - `switchboard-plug-power`
  - `switchboard-plug-printers`
  - `switchboard-plug-security-privacy`
  - `switchboard-plug-sound`
  - `switchboard-plug-useraccounts`
  - `switchboard-plug-wacom`

## 3. Target mixos: System Settings-like, Bukan Clone

mixos bertujuan membuat switchboard terasa lebih **mirip System Settings** dalam hal:

1. Sidebar kategori di kiri.
2. Detail panel kanan dengan layout konsisten.
3. Search bar atas.
4. Plugin grouping yang masuk akal.
5. Visual style konsisten (padding, typography).

mixos **TIDAK** bertujuan:

- Mengkloning System Settings 100%.
- Mengganti backend (GNOME Settings masih dipakai sebagai fallback untuk beberapa hal).
- Meniru wallpaper animasi proprietary.

## 4. Apa yang Bisa Diubah dengan Patch

### 4.1 Layout Sidebar
- **Status**: switchboard pakai grid, bukan sidebar.
- **Patch**: tambahkan sidebar widget, sembunyikan grid, route klik sidebar ke plug yang sama.
- **Target**:
  ```
  Sidebar (kiri)
  ├── Appearance
  ├── Desktop & Dock
  ├── Display
  ├── Network
  ├── Bluetooth
  ├── Sound
  ├── Keyboard
  ├── Mouse & Trackpad
  ├── Users & Groups
  ├── Privacy & Security
  ├── Updates
  ├── Power
  ├── Notifications
  └── About
  ```

### 4.2 Detail Panel
- **Status**: setiap plug render sendiri.
- **Patch**: tidak bisa uniform 100%, karena setiap plug adalah app terpisah.
- **Target**: standardisasi typography (title 14pt, body 10pt, secondary 9pt).

### 4.3 Search Bar
- **Status**: tidak ada global search.
- **Patch**: tambahkan search entry di header sidebar, implement filtering (cocokkan dengan nama plug).
- **Limitasi**: tidak search di dalam plug content, hanya filter plug visible.

### 4.4 Grouping Kategori
- **Status**: flat grid.
- **Patch**: tambahkan section header (System, Personal, Hardware) di sidebar.

### 4.5 Branding
- **Status**: branding elementary.
- **Patch**: ganti icon, ganti About content, ganti window title.

### 4.6 Default Plug
- **Status**: tidak ada default landing.
- **Patch**: pilih plug "Appearance" sebagai landing.

## 5. Apa yang TIDAK Bisa / Sangat Sulit

### 5.1 Layout Sidebar Native
- **Tantangan**: switchboard arsitektur tidak mendukung sidebar secara native.
- **Workaround**: fork switchboard dan rewrite `SwitchboardWindow` untuk pakai `Hdy.NavigationView` atau `Gtk.ListBox` di sidebar.
- **Effort**: sedang (1–2 bulan untuk developer yang paham GTK4).

### 5.2 Detail Panel Konsisten
- **Tantangan**: setiap plug adalah app terpisah dengan UI sendiri.
- **Workaround**: terbitkan design system (CSS class) dan minta upstream plug遵守. mixos hanya styling override, tidak enforce.

### 5.3 Search Dalam Plug
- **Tantangan**: plug content tidak terindeks sentral.
- **Workaround**: fokus ke search nama plug dulu. Konten search adalah backlog.

### 5.4 Live Preview
- **Tantangan**: macOS System Settings ada live preview (mis. dark mode toggle langsung terlihat).
- **Status**: beberapa plug sudah punya (Display, Appearance), tetapi tidak semua.
- **mixos**: TIDAK di tahap awal.

### 5.5 Account Integration (Apple ID style)
- **Tantangan**: GNOME Online Accounts sudah ada, tetapi integrasi OneDrive/Google/iCloud proprietary.
- **mixos**: out of scope (lisensi).

## 6. Strategi Patch Switchboard

### 6.1 Patch Ringan (Tahap Awal)
- Branding mixos di About plug.
- Title bar window mixos.
- Default landing: Appearance.
- Icon set mixos untuk plug.

### 6.2 Patch Sedang (Tahap Lanjutan)
- Tulis ulang layout switchboard pakai NavigationView.
- Tambah search bar.
- Grouping kategori.
- Typography standar.

### 6.3 Fork (Jangka Panjang)
- Sidebar navigation full.
- Custom plug untuk mixos-specific (Desktop & Dock, mixos Update Channel).
- Plug "About mixos" yang menampilkan logo, versi, contributor, lisensi.

## 7. Plug Baru yang Mungkin Diperlukan

| Plug Baru | Tujuan |
|-----------|--------|
| `mixos-plug-desktop` | Setting dock, panel, icon, font, theme mixos |
| `mixos-plug-branding` | Wallpaper, accent color, light/dark mode |
| `mixos-plug-update` | mixos update channel, schedule, delta updates |
| `mixos-plug-feedback` | Kirim feedback ke repo (opsional) |
| `mixos-plug-touchpad` | Gesture customization mixos |

Plug-plugin ini adalah **ekstensi** dari plug yang sudah ada, bukan penggantian.

## 8. Aset yang Dilarang dalam Patch

- Icon System Settings/System Preferences Apple asli.
- String "System Preferences" / "System Settings" (boleh pakai karena generik, tetapi mixos pakai "mixos Settings" atau "Pengaturan mixos" untuk identitas).
- Wallpaper Apple.
- Animation proprietary.

## 9. Out of Scope

- Time Machine-like backup GUI (Déjà Dup cukup, integrasi OK).
- Migration Assistant (impossible tanpa proprietary).
- iCloud sync.
- Touch ID/Face ID.
- Universal Control.
- AirDrop.
- Apple Pay.

## 10. Penutup

Switchboard mixos akan terasa lebih **terstruktur dan terorganisir** dari versi upstream, tetapi TIDAK akan identik dengan System Settings. Trade-off antara konsistensi total dan kompleksitas patch akan menjadi keputusan engineering mixos di kemudian hari. Untuk tahap awal, branding dan sidebar layout adalah target realistis.
