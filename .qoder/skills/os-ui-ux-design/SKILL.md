---
name: os-ui-ux-design
description: Merancang visual & interaksi Desktop Environment (DE) Linux yang terinspirasi elementary OS Pantheon dan/atau Lingmo OS, dengan fokus pada konsistensi desain, tipografi, color system, iconography, dan micro-interactions. Gunakan skill ini saat user ingin mendesain, mereview, atau membandingkan tampilan DE custom berbasis GTK/libadwaita, membuat design tokens, memilih typography pairing, atau membangun mockup sebelum implementasi.
---

# OS UI/UX Design — Pantheon-Inspired Desktop Environment

Skill ini untuk mendesain Desktop Environment (DE) Linux yang clean, modern, dan cohesive. Referensi utama: **elementary OS Pantheon** (clean, macOS-like, GTK/libadwaita native) dan **Lingmo OS** (colorful, Material-flavored, modern). Default: hybrid Pantheon untuk desktop shell + sedikit Material accent dari Lingmo di area yang playful (welcome, settings, file manager).

## Kapan Pakai Skill Ini

- Mendesain DE baru dari nol (mockup, design tokens, style guide)
- Review desain DE existing (kritik, audit konsistensi)
- Memilih typography, color palette, iconography
- Mendesain ulang komponen: panel, dock, app launcher, file manager, settings, notifications
- Menentukan spacing, radius, elevation convention
- Membuat wallpaper & theming guideline
- Mendesain onboarding/first-run experience
- Aksesibilitas (a11y): kontras, ukuran target, screen reader

**Jangan pakai skill ini** untuk: membangun DE (pakai `desktop-environment-engineering`), membuat installer/distro (pakai `linux-distro-customization`), security policy (pakai `os-security-hardening`).

## Filosofi Desain Default (Hybrid Pantheon + Lingmo)

1. **Calm, not flashy** — Pantheon DNA. Elemen UI secukupnya, whitespace banyak, satu fokus utama per layar.
2. **Consistency over creativity** — konsistensi spacing, radius, dan animation lebih penting daripada fitur unik per komponen.
3. **Native feel first** — pakai GTK4/libadwaita primitives dulu, custom widget hanya kalau primitive tidak cukup.
4. **Respect platform conventions** — desktop conventions (right-click, drag, keyboard nav) dihormati, jangan reinvent.
5. **Typography does the heavy lifting** — visual hierarchy lewat type scale, bukan warna atau ornament.
6. **Detail di micro-interactions** — easing, durasi, dan feedback yang konsisten bikin DE terasa "premium".

## Design Tokens

### Color System

Pakai **HSL-based** color tokens (bukan RGB hex random). Pantheon-style: satu accent color (default: indigo `#5860F8`-ish, bisa di-rebrand), netral, semantic states.

```
--accent-500        : primary accent (default brand)
--accent-100/300/700/900 : shade scale
--fg-default        : primary text
--fg-muted          : secondary text
--fg-disabled       : disabled state
--bg-base           : window background
--bg-surface        : cards, popovers
--bg-elevated       : modals, dialogs
--border-subtle     : hairlines
--border-strong     : focus rings
--success-500       : positive state
--warning-500       : warning
--danger-500        : destructive/error
--info-500          : informational
```

**Light + Dark mode**: WAJIB dual-mode. Pakai `@media (prefers-color-scheme: dark)` atau explicit toggle di settings. Semantic tokens hanya berubah value-nya, nama tetap.

**Kontras minimum**:
- Teks regular: WCAG AA 4.5:1
- Teks large (18pt+ atau 14pt bold): 3:1
- Non-text UI (border, icon): 3:1

Pakai tools: `contrast-checker`, `axe DevTools`, atau build script `color-contrast-check` di CI.

### Typography

**Default pairing**:
- UI sans: `Inter` atau `IBM Plex Sans` (open source, multi-bahasa, hinting bagus)
- Display/sans heading: `Inter` weight 600/700 atau `Cantarell` (default GNOME)
- Mono: `JetBrains Mono` atau `IBM Plex Mono`

**Type scale (rem-based, 16px base)**:
```
caption    : 0.75rem  (12px)  - timestamps, badges
small      : 0.875rem (14px)  - secondary
body       : 1rem     (16px)  - default
h3         : 1.125rem (18px)  - section
h2         : 1.25rem  (20px)  - card title
h1         : 1.5rem   (24px)  - page title
display    : 2rem     (32px)  - hero/welcome
```

**Line height**: 1.4 untuk body, 1.2 untuk display.

**Letter spacing**: 0 untuk semua ukuran, **kecuali** `caption` (0.025em) untuk legibility di ukuran kecil.

**Locale**: pakai `system-ui` fallback chain dulu, baru font pilihan. Test dengan CJK (CJK harus tetap readable, fallback ke `Noto Sans CJK`).

### Spacing Scale

4px base unit, geometric:
```
--space-1  : 4px
--space-2  : 8px
--space-3  : 12px
--space-4  : 16px  (default padding)
--space-5  : 20px
--space-6  : 24px  (section gap)
--space-8  : 32px  (page-level)
--space-12 : 48px
--space-16 : 64px
```

Jangan pakai nilai di antara scale. Kalau perlu "tambah sedikit", naikkan ke step berikutnya.

### Radius

```
--radius-sm : 4px   (small chips, tags)
--radius-md : 8px   (buttons, inputs, default)
--radius-lg : 12px  (cards)
--radius-xl : 16px  (modals)
--radius-pill: 9999px (avatar, pill button)
```

Konsistensi radius = salah satu signature "premium feel". Pilih satu skala, jangan campur ad hoc.

### Elevation

Pakai **subtle shadow + slight border**, bukan shadow dramatis (overdone macOS-ripoff vibes):
```
elevation-0 : none
elevation-1 : shadow subtle + 1px border-subtle (cards, popovers)
elevation-2 : shadow medium + 1px border-subtle (modals, menus)
elevation-3 : shadow large (drag preview, notifications)
```

Dark mode: kurangi shadow, naikkan border opacity (karena shadow di dark bg kurang kelihatan).

### Animation & Motion

```
duration-instant : 0ms
duration-fast    : 120ms  (hover, focus)
duration-base    : 200ms  (default state change)
duration-slow    : 320ms  (page/modal transition)
duration-slowest : 480ms  (welcome/onboarding)

easing-standard  : cubic-bezier(0.2, 0.0, 0.0, 1.0)
easing-decel     : cubic-bezier(0.0, 0.0, 0.2, 1)   (entering)
easing-accel     : cubic-bezier(0.4, 0.0, 1, 1)     (exiting)
```

**Aturan motion**:
- Jangan animate tanpa tujuan (no decorative motion).
- Entering elements pakai `easing-decel`, exiting pakai `easing-accel`.
- Respect `prefers-reduced-motion: reduce` → matikan semua non-essential motion.

## Komponen Inti DE

### 1. Top Bar / Panel
- Tinggi 28-32px, single row, semi-translucent (blur 12px di belakang).
- Left: Activities/Menu, app name (hanya jika app dalam mode chrome-custom).
- Center: clock + tanggal.
- Right: system tray (network, battery, volume, notifications).
- Style: Pantheon-style "wingpanel" slim. **Jangan** dual-panel ala KDE.

### 2. Dock
- Bottom-center, auto-hide optional, height 56-64px.
- Icon size: 48px (running & pinned).
- Behavior: click to launch/minimize, right-click context menu (Quit, New Window).
- Indicator dot di bawah icon untuk running apps.
- Drag-and-drop reorder (dengan animasi 200ms ease-standard).

### 3. App Launcher / Applications Menu
- **Dua opsi** (pilih satu, jangan hybrid):
  - **Option A (Pantheon-like)**: Full-screen grid, kategori di sidebar kiri, search di atas.
  - **Option B (Lingmo-like)**: Centered rounded window, kategori sebagai tab/filter.
- Search: fuzzy match, recent apps di atas, kategori filter instant.
- Keyboard: `/` atau `Super` fokus ke search.

### 4. File Manager
- 3-pane: sidebar | list | preview (preview hidden by default, slide in on select).
- Path bar: klik-able breadcrumb, **bukan** location text field (cleaner).
- View modes: list (default), grid (toggle).
- Selection: single-click select, double-click open.
- Drag-and-drop: in-window dan out-window (ke desktop/dock).

### 5. Settings
- Sidebar kiri: kategori (Appearance, Network, Displays, Power, Users, etc.).
- Right pane: form-based content.
- Search di atas (filter kategori + jump to setting).
- Live preview untuk theme/accent picker (lihat perubahan real-time).
- Bahasa: Indonesia + English minimal, arsitektur i18n-ready (`gettext`).

### 6. Notifications
- Top-right stack, slide in 320ms easing-decel.
- Auto-dismiss: 5s default, 0 (sticky) untuk important.
- Action buttons inline (max 2: primary + dismiss).
- Grouped by app, expand untuk history.

### 7. Lock Screen & Login
- Full-bleed wallpaper, jam + tanggal center-bottom.
- User picker di bawah (jika multi-user) atau single user fade in.
- PAM integration: fingerprint (jika ada), password, smartcard.

## Iconography

- Style: **outline + filled** dual-mode (filled untuk active, outline untuk inactive) ala elementary.
- Grid: 16/24/32/48/64/128/256 px, dengan 1-2px stroke konsisten di semua ukuran.
- Source: desain original atau kontribusi ke project ikon open (Elementary icon theme, Papirus, Adwaita).
- Avoid: stock icons dari tema random, ikon glossy/3D, drop shadow berlebihan.

## Sound Design

- Pakai **Freedesktop Sound Theme Specification** (libcanberra).
- Default theme: `elementary` (CC-BY-SA) atau custom.
- Events: `message-new-instant`, `bell-window-system`, `power-plug`, `power-unplug`, `screen-capture`, `volume-change`, `device-removed-media`, `device-added`.
- Jangan terlalu banyak event — pilih 5-8 most useful, sisanya silent.

## Accessibility (a11y)

- **Keyboard**: semua aksi reachable tanpa mouse. `Tab` order logis, `Esc` close modal, `Enter` activate.
- **Screen reader**: pakai AT-SPI (Linux accessibility bus). Test dengan `orca`. Label semua icon-only button.
- **Focus ring**: WAJIB visible, 2px outline `--border-strong`, offset 2px.
- **Target size**: minimal 32x32px untuk clickable, 44x44px recommended untuk touch.
- **Reduced motion**: respect `prefers-reduced-motion`.
- **Color independence**: jangan pakai warna sebagai satu-satunya penanda status (tambah icon + text).

## Internationalization

- Pakai `gettext` / `.po` files.
- Test layout dengan bahasa yang lebih panjang (Deutsch, Français) — pastikan tidak overflow.
- RTL support: pakai `logical` CSS properties (`margin-inline-start`, bukan `margin-left`).
- Locale-aware: tanggal (`%x`), angka (`%d`), mata uang (jangan hardcode `Rp`/`$`).

## Onboarding / First-Run

- Tampil **pertama kali** setelah install. Skipable.
- Steps: Welcome → Language → Keyboard → Network (Wi-Fi) → Account (jika user-create) → Theme picker (light/dark + accent) → Done.
- Total steps max 5-6, masing-masing satu fokus.
- "Skip to desktop" option di setiap step.
- Store preference di `~/.config/<distro>/first-run-done` (tidak pernah muncul lagi).

## Theming & Branding

- Default: light theme + indigo accent.
- Pre-built variants: 3-4 accent (blue, green, purple, graphite) shipped as default options.
- Custom accent: user bisa pilih dari color picker di Settings → Appearance.
- Wallpaper: 6-8 default wallpapers (gradient + minimal, hindari busy photo).
- Cursor: Bibata atau McMojave (open source). Test di light + dark bg.
- Font rendering: `fontconfig` tuned, antialiasing RGB LCD, hinting slight.

## Validation Checklist (sebelum "done")

- [ ] Light + dark mode tested, semua komponen visible
- [ ] Kontras WCAG AA lulus (otomatis via CI script)
- [ ] Keyboard nav 100% reachable (manual test semua screen)
- [ ] `prefers-reduced-motion` respected
- [ ] Screen reader (orca) test passed
- [ ] i18n: minimal 2 bahasa tested, no overflow
- [ ] RTL spot-check (Arabic/Hebrew sample text)
- [ ] Animation duration konsisten (no random values)
- [ ] Radius/spacing pakai token, no hardcoded magic numbers
- [ ] Icon set lengkap untuk semua kategori di file manager & settings
- [ ] Onboarding tested end-to-end
- [ ] Wallpaper, cursor, font konsisten dengan brand

## Tools Rekomendasi

- **Design**: Figma (free tier cukup), atau Penpot (FOSS).
- **Color**: HSL Color Picker, Coolors, ColorHub.
- **Contrast**: WebAIM Contrast Checker, `color-contrast-check` npm.
- **Icon**: Inkscape + custom, atau Elementary icon guidelines.
- **Prototype**: Figma prototype, atau langsung implement di GTK4/libadwaita.

## Anti-Pattern yang Harus Dihindari

- ❌ **Shadow abuse** — depth bukan dari shadow dramatis.
- ❌ **Color overload** — accent color max 1 aktif per screen, sisanya netral.
- ❌ **Magic numbers** — hardcoded 17px padding di satu tempat, 18px di tempat lain. Selalu token.
- ❌ **Inconsistent radius** — tombol radius 6, card radius 8, modal radius 10. Pilih satu skala.
- ❌ **Animation bouncy** — `cubic-bezier` untuk elastic spring effect bikin terasa "cheap". Decel/accel cukup.
- ❌ **Stock icons campur** — setengah Elementary, setengah Papirus. Pilih satu keluarga.
- ❌ **Custom scrollbar** — jangan bikin scrollbar 4px super thin yang susah di-grab.
- ❌ **Double UI patterns** — misalnya, dua cara buka app launcher (klik icon + gesture). Pilih satu primary.
- ❌ **Skipping a11y** — fokus ring dimatikan "biar lebih clean". Tidak. Selalu ada.

## Output Skill Ini

Saat user minta:
- **Mockup/design proposal** → kasih: design tokens, komponen breakdown, ASCII wireframe atau list komponen + behavior, referensi visual.
- **Review desain existing** → kasih: daftar issue per kategori (consistency, a11y, motion, type), saran fix konkret.
- **Color/typography/spacing decision** → kasih: opsi, trade-off, rekomendasi dengan justifikasi.
- **Comparison** (misal "Pantheon vs KDE Plasma") → kasih: side-by-side per aspek filosofi, kelebihan, kapan pilih yang mana.

## Referensi Belajar

- elementary OS Human Interface Guidelines: https://elementaryos.org/docs/hig
- GNOME Human Interface Guidelines: https://developer.gnome.org/hig/
- Material Design 3 (untuk inspo warna & motion): https://m3.material.io/
- Apple Human Interface Guidelines (untuk desktop conventions): https://developer.apple.com/design/human-interface-guidelines/
- GTK4/libadwaita docs: https://gnome.pages.gitlab.gnome.org/libadwaita/
- WCAG 2.2: https://www.w3.org/TR/WCAG22/
