#!/usr/bin/env bash
# =============================================================================
# default-settings.sh — Default dconf/gsettings untuk mixos
# =============================================================================
# Script ini dijalankan di dalam chroot untuk set default preferences
# semua user. Output: file di /etc/dconf/db/mixos.d/ yang akan di-read
# oleh dconf saat user login.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="default-settings"
readonly DB_DIR="/etc/dconf/db/mixos.d"
readonly DB_FILE="01-mixos-defaults"

log_info()  { printf "[%s] [%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*"; }
log_warn()  { printf "[%s] [%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*" >&2; }
log_error() { printf "[%s] [%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*" >&2; }

log_info "Membuat direktori dconf db: ${DB_DIR}"
mkdir -p "${DB_DIR}"

# === 1. GNOME Desktop Interface (umum) ===
log_info "Menulis settings: org.gnome.desktop.interface"
cat > "${DB_DIR}/${DB_FILE}" <<'EOF'
# org.gnome.desktop.interface
[org/gnome/desktop/interface]
font-name='Inter 10.5'
document-font-name='Inter 10.5'
monospace-font-name='JetBrains Mono 10'
cursor-size=24
cursor-theme='mixos-cursors'
icon-theme='mixos-icons'
gtk-theme='mixos-gtk'
color-scheme='prefer-dark'
enable-animations=true
toolbar-style='both'
menubar-accel='F10'
toolkit-accessibility=false
text-scaling-factor=1.0
EOF

# === 2. GNOME Desktop Background ===
log_info "Menulis settings: org.gnome.desktop.background"
cat >> "${DB_DIR}/${DB_FILE}" <<'EOF'

# org.gnome.desktop.background
[org/gnome/desktop/background]
primary-color='#1e1e1e'
secondary-color='#0a0a0a'
color-shading-type='horizontal'
picture-uri='file:///usr/share/backgrounds/mixos/mixos-default.jpg'
picture-uri-dark='file:///usr/share/backgrounds/mixos/mixos-dark.jpg'
picture-options='zoom'
show-desktop-icons=true
EOF

# === 3. GNOME Desktop Lockdown ===
log_info "Menulis settings: org.gnome.desktop.lockdown"
cat >> "${DB_DIR}/${DB_FILE}" <<'EOF'

# org.gnome.desktop.lockdown
[org/gnome/desktop/lockdown]
disable-application-handler=false
disable-command-line=false
disable-lock-screen=false
disable-log-out=false
disable-mount=false
disable-print-setup=false
disable-remove-volume=false
disable-save-to-disk=false
disable-user-switching=false
EOF

# === 4. GNOME Desktop Media Handling ===
log_info "Menulis settings: org.gnome.desktop.media-handling"
cat >> "${DB_DIR}/${DB_FILE}" <<'EOF'

# org.gnome.desktop.media-handling
[org/gnome/desktop/media-handling]
autorun-x-content-ignore=['x-content/unknown', 'x-content/audio-cdda', 'x-content/audio-dvd', 'x-content/video-dvd', 'x-content/blank-cd', 'x-content/blank-dvd', 'x-content/image-dcf']
autorun-never=true
EOF

# === 5. GNOME Desktop Privacy ===
log_info "Menulis settings: org.gnome.desktop.privacy"
cat >> "${DB_DIR}/${DB_FILE}" <<'EOF'

# org.gnome.desktop.privacy
[org/gnome/desktop/privacy]
report-technical-problems=false
remember-app-usage=true
remember-recent-files=true
hide-identity=false
disable-camera=false
disable-microphone=false
old-files-age=30
recent-files-max-age=30
EOF

# === 6. GNOME Desktop Screenshot ===
log_info "Menulis settings: org.gnome.desktop.screenshot"
cat >> "${DB_DIR}/${DB_FILE}" <<'EOF'

# org.gnome.desktop.screenshot
[org/gnome/desktop/screenshot]
last-save-directory='file:///home/${PROJECT_DEFAULT_USERNAME}/Pictures/Screenshots'
include-pointer=true
delay=0
EOF

# === 7. GNOME Desktop Input Sources ===
log_info "Menulis settings: org.gnome.desktop.input-sources"
cat >> "${DB_DIR}/${DB_FILE}" <<'EOF'

# org.gnome.desktop.input-sources
[org/gnome/desktop/input-sources]
sources=[('xkb', 'us'), ('ibus', 'hangul')]
per-window=false
xkb-options=['compose:rwin', 'terminate:ctrl_alt_bksp']
EOF

# === 8. GTK4 Application Menu (penting untuk global menu) ===
log_info "Menulis settings: GTK4 app menu (untuk global menu)"
cat >> "${DB_DIR}/${DB_FILE}" <<'EOF'

# org.gnome.desktop.interface (GTK4 global menu)
[org/gnome/desktop/interface]
gtk-application-prefers-app-menu=true
EOF

# === 9. Per-session (override per-user) ===
log_info "Menulis settings: per-session override"
mkdir -p "${DB_DIR}/locks"
cat > "${DB_DIR}/locks/${DB_FILE}-locks" <<'EOF'
# Locks untuk default system (tidak bisa di-override user)
EOF

# === 10. Compile dconf database ===
log_info "Compile dconf database"
dconf update

log_info "Default settings selesai ditulis ke ${DB_DIR}/${DB_FILE}"
exit 0
