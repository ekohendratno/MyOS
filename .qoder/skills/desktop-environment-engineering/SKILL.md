---
name: desktop-environment-engineering
description: Merancang, membangun, dan men-debug stack Desktop Environment (DE) Linux berbasis Wayland dengan filosofi elementary OS Pantheon. Mencakup compositor/window manager, panel/dock, app launcher, settings daemon, notification system, lock screen, session management, dan integrasi dengan GTK4/libadwaita. Gunakan skill ini saat user ingin memilih/membangun komponen DE, troubleshoot desktop Linux, atau mengintegrasikan komponen (panel, dock, dll) di atas compositor.
---

# Desktop Environment Engineering — Wayland + Pantheon-inspired

Skill ini fokus pada **engineer stack DE**: pilihan teknologi, integrasi komponen, dan troubleshooting. Asumsi: target akhir adalah desktop yang kohesi, **bukan** untuk build ISO (lihat `linux-distro-customization`) atau desain visual (lihat `os-ui-ux-design`).

## Kapan Pakai Skill Ini

- Memilih compositor: Mutter (GNOME) vs KWin (KDE) vs custom (Sway/wlroots) vs Pantheon (Gala)
- Mendesain/membangun panel (top bar), dock, app launcher
- Setup session manager, display manager (login screen)
- Integrasi notification daemon, settings daemon, screensaver/lock screen
- Troubleshooting Wayland session (input, scaling, fractional HiDPI)
- Membuat DE components dengan Vala/GTK4/libadwaita
- Setup Portal integration (file chooser, screen capture, notifications)
- Mendesain policy Power, NetworkManager dispatcher, dsb

**Jangan pakai skill ini** untuk: membuat ISO/branding (pakai `linux-distro-customization`), UX/visual design (pakai `os-ui-ux-design`), security (pakai `os-security-hardening`).

## Wayland First, X11 sebagai Fallback

Default: **Wayland-only** untuk versi modern. X11 hanya fallback untuk:
- App legacy yang belum support Wayland
- Hardware yang belum punya driver Wayland mature

```bash
# Check compositor
echo $XDG_SESSION_TYPE
# wayland (expected) atau x11 (fallback)

# Check protocol support
weston-info
# atau
wayland-info
```

### Kenapa Wayland

- **Security**: app terisolasi, tidak bisa keylog window lain
- **Multi-monitor**: lebih reliable, fractional scaling native
- **HiDPI**: per-output scale factor, bukan zoom hack
- **Modern**: protokol eksplisit, tidak ada extension chaos X11

### Kenapa masih perlu XWayland

```bash
# XWayland install
apt install xwayland

# Test X11 app di Wayland session
DISPLAY=:0 xterm  # akan jalan via XWayland
```

Majority app Linux modern sudah support Wayland native. XWayland adalah transisi, bukan tujuan akhir.

## Kompositor (Window Manager + Display Server)

### Pilihan utama

| Compositor | Bahasa | Style | Cocok untuk |
|------------|--------|-------|-------------|
| **Mutter** (GNOME) | C | Stacking WM + compositor | GNOME-based DE |
| **KWin** (KDE) | C++ | Stacking WM + compositor | KDE Plasma |
| **Gala** (elementary) | Vala | Minimal compositor, simple | Pantheon DE |
| **Sway** | C | i3-style tiling | Tiling workflow |
| **Hyprland** | C++ | Dynamic tiling, animations | Power user, eye candy |
| **Wayfire** | C | Stacking + plugins | Custom stack |
| **River** | C | Dynamic tiling | Minimal config |

### Default rekomendasi

**Gala (Pantheon)** kalau target = elementary-like, karena:
- Sudah integrate dengan seluruh stack Pantheon
- Simple API, ditulis Vala
- Built-in animations yang smooth
- Mature (dipakai elementary OS production)

**Mutter** sebagai fallback, karena:
- Standar GNOME, paling banyak resource
- Paling stabil, paling banyak user
- Extension ecosystem (walau Wayland extension terbatas)

**Hyprland** kalau user mau modern, beautiful animations + tiling. Bagus untuk "wow factor" distro.

**Hindari custom wlroots dari nol** kecuali untuk proyek riset/maintainer dedicated. Effort sangat tinggi.

## Pantheon Stack Deep Dive

Default untuk project ini. Stack component Pantheon:

### Core components

| Component | Fungsi | Bahasa | Repositori |
|-----------|--------|--------|------------|
| **Gala** | Window manager & compositor | Vala | github.com/elementary/gala |
| **Pantheon Shell** | Session & shell glue | Vala | github.com/elementary/pantheon-shell |
| **Wingpanel** | Top bar | Vala | github.com/elementary/wingpanel |
| **Plank** | Dock (juga standalone) | Vala | github.com/elementary/plank |
| **Slingshot** | App launcher | Vala | github.com/elementary/slingshot |
| **Switchboard** | Settings hub | Vala | github.com/elementary/switchboard |
| **Pantheon Files** | File manager | Vala | github.com/elementary/files |
| **Pantheon Terminal** | Terminal | Vala | github.com/elementary/terminal |

### Build dari source (kalau tidak ada PPA untuk Ubuntu 24.04)

```bash
# Deps
sudo apt install -y \
  build-essential cmake meson ninja-build \
  libgtk-4-dev libadwaita-1-dev \
  libgranite-dev libwingpanel-3.0-dev \
  libplank-dev libswitchboard-3-dev \
  libsoup-3.0-dev json-glib-dev \
  libgee-0.8-dev libxml2-dev \
  gobject-introspection \
  valac

# Clone & build salah satu component
git clone https://github.com/elementary/gala.git
cd gala
meson setup build
meson compile -C build
sudo meson install -C build
```

**Caveat**: Pantheon 8 mungkin masih ada incompatibility dengan GTK4/libadwaita 1.x yang dipakai Ubuntu 24.04. Be prepared untuk patch. Atau pakai elementary OS 8 (basis Ubuntu 24.04) langsung, fork itu.

## GTK4 / libadwaita — Native Toolkit

Semua UI components DE harus ditulis pakai **GTK4 + libadwaita** untuk native feel & a11y.

```python
# Contoh minimal GTK4 + libadwaita app (Python)
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw

class MydistroApp(Adw.Application):
    def do_activate(self):
        win = Adw.ApplicationWindow(application=self)
        win.set_default_size(400, 300)
        win.set_content(Gtk.Label(label="Hello, Mydistro!"))
        win.present()

app = MydistroApp()
app.run(None)
```

```vala
// Atau Vala (idiomatic untuk Pantheon)
public class Mydistro.App : Adw.Application {
    public override void activate () {
        var win = new Adw.ApplicationWindow (this);
        win.set_default_size (400, 300);
        win.set_content (new Gtk.Label ("Hello, Mydistro!"));
        win.present ();
    }
}
```

**Kenapa libadwaita, bukan raw GTK**:
- Adaptive widgets (otomatis scale di mobile/tablet/desktop)
- Built-in style untuk libadwaita-aware themes
- Style classes resmi: `.card`, `.toolbar`, `.sidebar`, dll
- A11y built-in (focus, AT-SPI, dll)
- Header bar & adaptive layout primitives

## Session & Display Manager

### Display Manager (Login Screen)

Pilihan:

| DM | Style | Cocok untuk |
|----|-------|-------------|
| **GDM** (GNOME) | GNOME-style, mature | GNOME-based |
| **LightDM + slick-greeter** | Simple, themeable | Custom DE |
| **SDDM** (KDE) | Modern, themeable | KDE |
| **Greetd** | Minimal, daemon | Wayland-first minimal |
| **Ly** | TUI minimal | Niche / power user |

**Default rekomendasi**: **GDM** karena maturity + integration dengan Gala/Pantheon session.

```bash
# Install GDM
sudo apt install gdm3

# Set default
sudo systemctl set-default graphical.target
sudo systemctl enable gdm3
```

### Session File

Session di-define via `.desktop` file di `/usr/share/xsessions/` (X11) atau `/usr/share/wayland-sessions/` (Wayland).

```ini
# /usr/share/wayland-sessions/pantheon.desktop
[Desktop Entry]
Name=Pantheon
Comment=Elementary OS desktop environment
Exec=/usr/libexec/pantheon-session
Type=Application
DesktopNames=Pantheon
```

`/usr/libexec/pantheon-session` adalah script launcher:

```bash
#!/bin/sh
exec /usr/bin/gnome-session --session=pantheon
# atau
exec gala --wayland & wingpanel & plank & slingshot &
```

## Power Management

### upower + power-profiles-daemon

```bash
# Install
sudo apt install upower power-profiles-daemon

# Profile aktif
powerprofilesctl list
powerprofilesctl set balanced
powerprofilesctl set power-saver
powerprofilesctl set performance
```

### Lid switch, suspend, hibernate

```ini
# /etc/UPower/UPower.conf
IgnoreLid=false
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

```bash
# /etc/systemd/logind.conf
HandleSuspendKey=suspend
HandleHibernateKey=hibernate
HandleLidSwitch=suspend
```

## Network Management

### NetworkManager

```bash
sudo apt install network-manager network-manager-gnome
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
```

### nm-applet vs custom tray

Pakai `nm-applet` (GNOME) atau custom tray indicator. Pantheon biasanya pakai wingpanel-indicator-network.

## Notification System

### Notification daemon

Pilihan:
- **Mako** (Wayland-native, minimal)
- **Dunst** (lightweight, classic)
- **Phosh Notifications** (mobile-style)
- **Pantheon Notifications** (kalau pakai full Pantheon stack)

**Default**: Mako untuk Wayland-only, konfig via `~/.config/mako/config`.

```ini
# mako config
default-timeout=5000
border-size=2
border-color=#5860F8
background-color=#1e1e1e
text-color=#ffffff
width=300
height=80
anchor=top-right
```

### Notification spec

Pakai **org.freedesktop.Notifications** D-Bus spec (semua app Linux pakai ini).

```python
# Kirim notifikasi via D-Bus
import subprocess
subprocess.run([
    "gdbus", "call", "--session",
    "--dest", "org.freedesktop.Notifications",
    "--object-path", "/org/freedesktop/Notifications",
    "--method", "org.freedesktop.Notifications.Notify",
    "my-app", "0", "dialog-information",
    "Title", "Body", "[]", "{}", "5000"
])
```

## Settings Daemon

### GNOME Settings Daemon (bukan GNOME-only)

GNOME Settings Daemon (`gnome-settings-daemon`) bisa dipakai tanpa GNOME Shell. Sangat berguna untuk:
- Theme management (light/dark)
- Font rendering
- Mouse/touchpad
- Keyboard shortcuts
- XSettings (untuk GTK theme)

```bash
sudo apt install gnome-settings-daemon gnome-control-center
```

Atau untuk Pantheon, pakai **Switchboard** (settings daemon + UI).

## Power User Features

### Keyboard shortcuts

```ini
# /usr/share/glib-2.0/schemas/mydistro-custom.gschema.xml
<schema id="org.pantheon.desktop.keybindings">
  <key name="screenshot" type="s">
    <default><![CDATA['<Primary>Print']]></default>
    <summary>Screenshot</summary>
  </key>
  <key name="terminal" type="s">
    <default><![CDATA['<Primary><Alt>t']]></default>
    <summary>Open Terminal</summary>
  </key>
</schema>
```

Compile: `glib-compile-schemas /usr/share/glib-2.0/schemas/`

### Custom keybinding handler (D-Bus)

Bind `PrintScreen` ke script `pantheon-screenshot`:

```bash
# /usr/bin/mydistro-keybind-screenshot
#!/bin/sh
# Capture screen & save
grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%s).png
```

Pair dengan `sxhkd` atau custom handler daemon.

## Portals (XDG Desktop Portals)

Portals adalah D-Bus API yang mediates app-to-DE communication (file chooser, screen capture, notification). Penting untuk Flatpak & Snap.

```bash
sudo apt install xdg-desktop-portal xdg-desktop-portal-gtk
# atau untuk Pantheon:
sudo apt install xdg-desktop-portal-pantheon
```

Konfig:
```ini
# /usr/share/xdg-desktop-portal/portals.conf
[preferred]
default=gtk;pantheon
org.freedesktop.impl.portal.Screenshot=gnome
org.freedesktop.impl.portal.Notification=gnome
org.freedesktop.impl.portal.FileChooser=gtk
```

## XSettings & Theming Integration

DE perlu broadcast GTK theme, icon theme, cursor, font ke semua app. XSettings daemon handles ini.

```bash
# gnome-settings-daemon handles this via org.gnome.desktop.interface
gsettings set org.gnome.desktop.interface gtk-theme 'elementary'
gsettings set org.gnome.desktop.interface icon-theme 'elementary'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
gsettings set org.gnome.desktop.interface font-name 'Inter 11'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'  # atau 'default'
```

`color-scheme` (libadwaita 1.x) bikin semua libadwaita apps respect light/dark automatically. **Pakai ini**, jangan custom toggle.

## Troubleshooting Umum

### Layar hitam setelah boot

```bash
# Boot ke TTY
Ctrl+Alt+F2

# Check log
journalctl -b -p err
# atau
cat /var/log/Xorg.0.log    # kalau masih X11
cat ~/.local/share/xorg/Xorg.0.log  # log X11 di user session
```

Common causes:
- GPU driver missing
- Wayland session crash → fallback ke X11 (`/etc/gdm3/custom.conf` → `WaylandEnable=false`)
- Compositor crash

### Scaling HiDPI pecah

```bash
# Set fractional scaling GDM
sudo nano /etc/gdm3/custom.conf
# Add: WaylandEnable=true (default)

# User-level: pakai GNOME control center / Pantheon settings
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

# atau langsung set scale
gsettings set org.gnome.desktop.interface scaling-factor 2
# atau 1.5 (fractional, butuh experimental feature)
```

### App legacy tidak bisa di-window

App yang expect X11 harus di-launch dengan `GDK_BACKEND=x11`:

```bash
GDK_BACKEND=x11 my-app
# atau di .desktop file
Exec=env GDK_BACKEND=x11 my-app
```

### Compositor crash loop

```bash
# Kill compositor, kill GDM
sudo systemctl restart gdm

# Atau switch ke TTY, kill user session
sudo pkill -9 -u $(whoami)
```

### Audio tidak ada suara

```bash
# Check PipeWire/PulseAudio
pactl info
wpctl status   # PipeWire

# Restart
systemctl --user restart pipewire pipewire-pulse wireplumber
```

## Performance Tuning

### Compositor

```ini
# Gala config (~/.config/io.elementary.gala.settings)
[animations]
enable-animations=true
duration=200

[workspaces]
dynamic-workspaces=true
```

### Startup services

```bash
# Lihat apa yang auto-start
systemd-analyze blame
# atau
ls /etc/xdg/autostart/ ~/.config/autostart/
```

Disable yang tidak perlu:
```bash
# /etc/xdg/autostart/remove-these.desktop → pindahkan
sudo mv /etc/xdg/autostart/update-notifier.desktop /tmp/
```

### Swappiness

```bash
# Check
cat /proc/sys/vm/swappiness  # default 60

# Untuk desktop dengan RAM cukup, turunkan
sudo sysctl vm.swappiness=10

# Persistent
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-mydistro.conf
```

## Anti-Pattern yang Harus Dihindari

- ❌ **Campur DE stacks** — pakai Mutter + Plank + KDE panel = FrankenDE. Pilih satu, commit.
- ❌ **Custom session script tanpa systemd** — pakai `gnome-session` atau custom D-Bus activated service, bukan `&` di `.xinitrc`.
- ❌ **Hardcode theme di semua component** — pakai dconf/GSettings, biar user bisa ganti.
- ❌ **Skip XDG compliance** — file konfigurasi di `~/.config/`, cache di `~/.cache/`, data di `~/.local/share/`. Jangan bikin folder sembarangan.
- ❌ **Compositor leak** — pastikan window manager, panel, dock di-track sama session manager, kalau crash auto-restart.
- ❌ **Notifikasi spam** — batasi app yang boleh pakai notification. Beri user control.
- ❌ **Disable a11y "biar bersih"** — keep focus ring, keep screen reader, keep keyboard nav. Always.

## Output Skill Ini

Saat user minta:
- **"Pilih DE apa untuk distro gw?"** → kasih: comparison per aspek (resource, customization, maintenance, looks), rekomendasi untuk use case mereka.
- **"Setup Pantheon di Ubuntu 24.04"** → kasih: step-by-step install + patch notes, common issues, fallback plan.
- **"Buat custom panel"** → kasih: tech stack (Wingpanel plug-in), contoh code, integration steps.
- **"Troubleshoot Wayland issue"** → kasih: cara baca log, common causes, fix step-by-step.
- **"Build DE component"** → kasih: arsitektur, API yang dipakai, build instructions, testing.

## Referensi Belajar

- elementary OS GitHub: https://github.com/elementary
- Pantheon HIG: https://docs.elementary.io/develop/
- Wayland Book: https://wayland-book.com/
- GTK4 docs: https://docs.gtk.org/gtk4/
- libadwaita docs: https://gnome.pages.gitlab.gnome.org/libadwaita/
- Portal spec: https://flatpak.github.io/xdg-desktop-portal/
- Freedesktop specs: https://specifications.freedesktop.org/
- Hyprland wiki (untuk inspiration animation): https://wiki.hyprland.org/
- Arch Wiki DE Comparison: https://wiki.archlinux.org/title/Desktop_environment
