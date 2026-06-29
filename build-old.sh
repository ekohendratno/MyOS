#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="build.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_PATH}"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

DRY_RUN=true
CLEAN=false
SKIP_UPSTREAM=false
SKIP_LINGMO_SOURCE=false

if [[ -t 1 ]]; then
  readonly C_RESET='\033[0m' C_BOLD='\033[1m' C_DIM='\033[2m'
  readonly C_RED='\033[31m' C_GREEN='\033[32m' C_YELLOW='\033[33m' C_BLUE='\033[34m'
else
  readonly C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_step()  { printf "%b==>%b %b%s%b\n"        "${C_GREEN}" "${C_RESET}" "${C_BOLD}" "$*" "${C_RESET}"; }

print_help() {
  cat <<'EOF'
build.sh — Build ISO mixos (LingmoOS base)

Usage:  ./build.sh [options]

Options:
  --dry-run            Validasi saja (default).
  --no-dry-run         Jalankan build.
  --clean              Hapus cache & build ulang dari awal (download ulang).
  --skip-upstream      Jangan clone ulang upstream.
  --skip-lingmo-source Pakai paket repo saja; hanya untuk debug/fallback.
  -h, --help           Tampilkan bantuan.

Cache: Secara default build menyimpan cache debootstrap & paket.
       Build ke-2 dan seterusnya jauh lebih cepat & hemat kuota.
       Gunakan --clean untuk build bersih (download ulang).
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)         DRY_RUN=true ;;
      --no-dry-run)      DRY_RUN=false ;;
      --clean)           CLEAN=true ;;
      --skip-upstream)   SKIP_UPSTREAM=true ;;
      --skip-lingmo-source) SKIP_LINGMO_SOURCE=true ;;
      -h|--help)         print_help; exit 0 ;;
      *)                 log_error "Argumen tidak dikenal: $1"; print_help; exit 1 ;;
    esac
    shift
  done
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log_error "Missing: $1"; exit 1; }
}

require_path() {
  [[ -e "$1" ]] || { log_error "Path tidak ada: $1"; exit 1; }
}

load_config() {
  log_step "Memuat konfigurasi"
  require_path "${CONFIG_FILE}"
  source "${CONFIG_FILE}"
  PROJECT_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  PROJECT_BUILD_BRANCH="$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  log_info "Project: ${PROJECT_NAME} ${PROJECT_VERSION} (${PROJECT_CODENAME})"
  log_info "Base:    ${BASE_DISTRO} ${BASE_DISTRO_VERSION} / Debian ${DEBIAN_CODENAME} / ${BASE_ARCH}"
}

is_enabled() {
  case "${1:-false}" in
    true|TRUE|yes|YES|1|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

lingmo_source_enabled() {
  [[ "${SKIP_LINGMO_SOURCE}" == "true" ]] && return 1
  is_enabled "${ENABLE_LINGMO_SOURCE_BUILD:-false}"
}

lingmo_source_required() {
  is_enabled "${LINGMO_SOURCE_REQUIRED:-false}"
}

validate_environment() {
  log_step "Validasi environment"
  local req=(bash git find sed)
  for cmd in "${req[@]}"; do require_cmd "${cmd}"; done
  require_path "${PROJECT_ROOT}/config"
  if [[ "${DRY_RUN}" == "false" ]]; then
    local build_tools=(debootstrap lb xorriso)
    for cmd in "${build_tools[@]}"; do require_cmd "${cmd}"; done
    if [[ "$(id -u)" != "0" ]]; then
      log_warn "Build butuh root. Jalankan: sudo ./build.sh --no-dry-run"; exit 1
    fi
    # Cek live-build version
    local ver
    ver=$(dpkg-query -f '${Version}' -W live-build 2>/dev/null || echo "0")
    if dpkg --compare-versions "$ver" lt "1:20230502"; then
      log_error "Need live-build >= 1:20230502, have $ver"; exit 1
    fi
  fi
  log_info "Environment OK"
}

prepare_dirs() {
  mkdir -p "${PROJECT_ROOT}/${BUILD_DIR}"
  mkdir -p "${PROJECT_ROOT}/${UPSTREAM_DIR}"
  mkdir -p "${PROJECT_ROOT}/${LOG_DIR}"
}

clone_upstream() {
  local target="${PROJECT_ROOT}/${UPSTREAM_DIR}/live-build-config"
  if [[ -d "${target}/.git" ]]; then
    log_info "Upstream sudah ada di ${target}"
    return 0
  fi
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Akan clone: ${BASE_DISTRO_URL} -> ${target}"; return 0
  fi
  log_info "Cloning ${BASE_DISTRO_URL}..."
  git clone --depth 1 --branch "2.1-debian12-final" "${BASE_DISTRO_URL}" "${target}"
  log_info "Clone selesai"
}

setup_config() {
  local work_dir="$1"
  local upstream="${PROJECT_ROOT}/${UPSTREAM_DIR}/live-build-config"

  # Hapus config lama, biarkan cache/ utuh
  rm -rf "${work_dir}/config" "${work_dir}/lingmo-config" "${work_dir}/auto" 2>/dev/null || true

  # Copy upstream config
  cp -r "${upstream}/auto" "${work_dir}/"
  cp -r "${upstream}/lingmo-config" "${work_dir}/"
  cp "${upstream}/.getopt.sh" "${work_dir}/" 2>/dev/null || true

  # Bootloader branding
  sed -i 's/Lingmo Linux/mixos/g; s/Lingmo/mixos/g' \
    "${work_dir}/lingmo-config/common/bootloaders/grub-pc/grub.cfg" 2>/dev/null || true

  # Fix archive files in lingmo-config (source config, not just config/)
  # The auto/config script recopies from lingmo-config/common during lb build
  local src_archives_dir="${work_dir}/lingmo-config/common/archives"
  mkdir -p "${src_archives_dir}"
  cat > "${src_archives_dir}/lingmo_pkg.list.chroot" <<ARCHIVE
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
  cat > "${src_archives_dir}/lingmo_pkg.list.binary" <<ARCHIVE
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
  log_info "Fixed archive files in lingmo-config/common/archives"

  # Create debian-cd symlink when live-build lacks data for the selected codename.
  local live_build_data="/usr/share/live/build/data/debian-cd"
  if [[ ! -e "${live_build_data}/${DEBIAN_CODENAME}" ]]; then
    ln -sf sid "${live_build_data}/${DEBIAN_CODENAME}" 2>/dev/null || \
      log_warn "Cannot create debian-cd symlink for ${DEBIAN_CODENAME} (try: sudo ln -sf sid ${live_build_data}/${DEBIAN_CODENAME})"
  fi

  # Replace auto/config with a clean wrapper — bypass upstream complexity
  # (jq dependency, IP-country detection, debian-cd symlink, archive overwrite)
  cat > "${work_dir}/auto/config" << AUTOCFG
#!/bin/bash
set -e

# Create debian-cd symlink if needed
dist="\${LB_DISTRIBUTION:-${DEBIAN_CODENAME}}"
if [ ! -e /usr/share/live/build/data/debian-cd/"\$dist" ]; then
  if [ -w /usr/share/live/build/data/debian-cd ]; then
    ln -sf sid /usr/share/live/build/data/debian-cd/"\$dist"
  fi
fi

# Re-apply our custom archive files (they may get overwritten)
mkdir -p config/archives
cat > config/archives/lingmo_pkg.list.chroot << 'ARCHIVE'
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
cat > config/archives/lingmo_pkg.list.binary << 'ARCHIVE'
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE

# Always use the configured base distribution
exec lb config noauto --distribution "${DEBIAN_CODENAME}" "\$@"
AUTOCFG
  chmod +x "${work_dir}/auto/config"
  log_info "Replaced auto/config with clean wrapper"

  # Hooks — write directly to config/hooks/normal/ with .hook.chroot extension
  # (live-build only executes files matching *.hook.chroot in config/hooks/normal/)
  local hooks_normal_dir="${work_dir}/config/hooks/normal"
  local hooks_live_dir="${work_dir}/lingmo-config/common/hooks/live"
  mkdir -p "${hooks_normal_dir}" "${hooks_live_dir}"

  cat > "${hooks_normal_dir}/7000-mixos-setup.hook.chroot" <<HOOK
#!/usr/bin/env bash
set -euo pipefail
HOOK_NAME="mixos-setup"
log_info()  { printf "[%s] [INFO]  %s\n"  "\$(date +%H:%M:%S)" "\$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "\$(date +%H:%M:%S)" "\$*" >&2; }
log_info "=== \${HOOK_NAME} ==="

# === 1. OS Identity ===
log_info "Writing /etc/os-release"
cat > /etc/os-release <<OSEOF
NAME="${PROJECT_NAME}"
PRETTY_NAME="${PROJECT_DISPLAY_NAME} ${PROJECT_PRETTY_VERSION}"
ID="${PROJECT_NAME}"
ID_LIKE="lingmo debian"
VERSION="${PROJECT_PRETTY_VERSION}"
VERSION_ID="${PROJECT_VERSION_ID}"
VERSION_CODENAME="${PROJECT_CODENAME}"
HOME_URL="https://github.com/ekohe/mixos"
SUPPORT_URL="https://github.com/ekohe/mixos/issues"
BUG_REPORT_URL="https://github.com/ekohe/mixos/issues/new"
OSEOF

echo "${PROJECT_DEFAULT_HOSTNAME}" > /etc/hostname

# === 2. GTK Settings ===
mkdir -p /etc/gtk-3.0 /etc/gtk-4.0
cat > /etc/gtk-3.0/settings.ini <<GTK
[Settings]
gtk-theme-name=mixos-gtk
gtk-icon-theme-name=mixos-icons
gtk-cursor-theme-name=mixos-cursors
gtk-font-name=Inter 10.5
gtk-application-prefer-dark-theme=true
gtk-decoration-layout=close,minimize,maximize:menu
gtk-overlay-scrolling=true
GTK

cat > /etc/gtk-4.0/settings.ini <<GTK4
[Settings]
gtk-theme-name=mixos-gtk
gtk-icon-theme-name=mixos-icons
gtk-cursor-theme-name=mixos-cursors
gtk-font-name=Inter 10.5
gtk-application-prefer-dark-theme=1
GTK4

# === 3. dconf profile ===
mkdir -p /etc/dconf/profile
cat > /etc/dconf/profile/user <<PROF
user-db:user
system-db:mixos
PROF

mkdir -p /etc/dconf/db/mixos.d

# === 4. Desktop interface defaults ===
log_info "Writing dconf: interface defaults"
cat > /etc/dconf/db/mixos.d/01-mixos-defaults <<'DBLOCK'
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
toolkit-accessibility=false
text-scaling-factor=1.0
gtk-application-prefer-app-menu=true

[org/gnome/desktop/background]
primary-color='#1e1e1e'
secondary-color='#0a0a0a'
color-shading-type='horizontal'
picture-uri='file:///usr/share/backgrounds/mixos/mixos-default.jpg'
picture-uri-dark='file:///usr/share/backgrounds/mixos/mixos-dark.jpg'
picture-options='zoom'
show-desktop-icons=true

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

[org/gnome/desktop/media-handling]
autorun-never=true

[org/gnome/desktop/privacy]
report-technical-problems=false
remember-recent-files=true
old-files-age=30
recent-files-max-age=30
DBLOCK

# === 5. Pantheon / LingmoOS shell settings ===
log_info "Writing dconf: gala + statusbar"
cat > /etc/dconf/db/mixos.d/02-pantheon-gala <<'DBLOCK'
[org/pantheon/desktop/gala]
animations=1
button-layout='close,minimize,maximize:menu'
workspace-count=4
enable-workspaces=true
hotcorner-topleft=''
hotcorner-topright=''
hotcorner-bottomleft=''
hotcorner-bottomright=''
attach-modal-dialogs=true
DBLOCK

cat > /etc/dconf/db/mixos.d/03-statusbar <<'DBLOCK'
[org/pantheon/desktop/wingpanel]
background-color='#1e1e1e'
opacity=255
transparency-type='solid'
DBLOCK

# === 6. Keyboard shortcuts (macOS-inspired) ===
log_info "Writing dconf: keyboard shortcuts"
cat > /etc/dconf/db/mixos.d/05-keyboard-shortcuts <<'DBLOCK'
[org/gnome/desktop/wm/keybindings]
close=['<Super>w']
maximize=['<Super>Up']
unmaximize=['<Super>Down']
minimize=['<Super>h']
toggle-maximized=['<Super>m']
switch-applications=['<Super>Tab']
switch-applications-backward=['<Super><Shift>Tab']
switch-group=['<Super>grave', '<Super>asciitilde']
show-desktop=['<Super>d']
panel-run-dialog=['<Super>r']
move-to-workspace-left=['<Super><Shift>Left']
move-to-workspace-right=['<Super><Shift>Right']
switch-to-workspace-left=['<Super>Left']
switch-to-workspace-right=['<Super>Right']

[org/gnome/mutter/keybindings]
toggle-tiled-left=['<Super>bracketleft']
toggle-tiled-right=['<Super>bracketright']

[org/gnome/settings-daemon/plugins/media-keys]
calculator=['<Super>equal']
home=['<Super>e']
screensaver=['<Super>l']
mute=['<XF86AudioMute']
volume-down=['<XF86AudioLowerVolume']
volume-up=['<XF86AudioRaiseVolume']

[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
two-finger-scrolling=true
natural-scroll=true
disable-while-typing=true
click-method='fingers'
DBLOCK

# === 7. Display & typography ===
log_info "Writing dconf: display settings"
cat > /etc/dconf/db/mixos.d/04-display <<'DBLOCK'
[org/gnome/desktop/wm/preferences]
titlebar-font='Inter Semibold 10'
button-layout='close,minimize,maximize:menu'
focus-mode='sloppy'
raise-on-click=true
double-click-titlebar='toggle-maximize'
num-workspaces=4

[org/gnome/settings-daemon/peripherals/mouse]
double-click=400
drag-threshold=8

[org/gnome/settings-daemon/peripherals/touchpad]
tap-to-click=true
natural-scroll=true
two-finger-scrolling=true
edge-scrolling=false
disable-while-typing=true

[org/gnome/settings-daemon/peripherals/keyboard]
repeat=true
delay=250
repeat-interval=33
DBLOCK

# === 8. Theme defaults (dconf) ===
log_info "Writing dconf: theme"
cat > /etc/dconf/db/mixos.d/06-mixos-theme <<DBLOCK
[org/gnome/desktop/interface]
gtk-theme='${PROJECT_GTK_THEME}'
icon-theme='${PROJECT_ICON_THEME}'
cursor-theme='${PROJECT_CURSOR_THEME}'
font-name='Inter 10.5'
DBLOCK

# === 9. Titlebar ===
log_info "Writing dconf: titlebar"
cat > /etc/dconf/db/mixos.d/08-titlebar <<'DBLOCK'
[org/gnome/desktop/wm/preferences]
titlebar-font='Inter Semibold 10'
button-layout='close,minimize,maximize:menu'
DBLOCK

# === 10. File manager defaults ===
log_info "Writing dconf: file manager"
cat > /etc/dconf/db/mixos.d/09-files <<'DBLOCK'
[org/pantheon/files/preferences]
default-folder-view='icon-view'
show-hidden-files=false
sort-directories-first=true
thumbnail-size=128
DBLOCK

# === 11. LingmoOS Settings (fix navigation) ===
log_info "Writing dconf: lingmo-settings"
cat > /etc/dconf/db/mixos.d/10-lingmo-settings <<'DBLOCK'
[com/lingmo/settings]
default-page='appearance'
sidebar-width=200
window-width=900
window-height=600
DBLOCK

# === 12. Environment variables (global menu + misc) ===
log_info "Setting environment variables"
mkdir -p /etc/environment.d
cat > /etc/environment.d/90-mixos.conf <<ENVEOF
GTK_OVERLAY_SCROLLING=1
GTK_MODULES=gail:atk-bridge
UBUNTU_MENUPROXY=1
ENVEOF

# Fallback: also write to /etc/environment
if ! grep -q 'GTK_OVERLAY_SCROLLING' /etc/environment 2>/dev/null; then
  cat >> /etc/environment <<ENVEOF2
GTK_OVERLAY_SCROLLING=1
UBUNTU_MENUPROXY=1
ENVEOF2
fi

# === 13. Dock: default pinned launchers ===
log_info "Configuring dock default launchers"
mkdir -p /etc/skel/.config/lingmo-dock /etc/skel/.config/lingmoos

# Lingmo components use QSettings("lingmoos", "..."). Seed those settings
# before the live user is created so the theme daemon, desktop, and dock agree
# on wallpaper + dock geometry at first login.
cat > /etc/skel/.config/lingmoos/theme.conf <<'THEMECONF'
[General]
Wallpaper=/usr/share/backgrounds/lingmoos/default.jpg
BackgroundType=0
BackgroundColor=#2B8ADA
AccentColor=0
DarkMode=false
DarkModeDimsWallpaer=false
CursorTheme=default
CursorSize=24
IconTheme=Crule
DarkIconTheme=Crule-dark
THEMECONF

cat > /etc/skel/.config/lingmoos/dock.conf <<'DOCKQCONF'
[General]
IconSize=53
Direction=1
Visibility=0
RoundedWindow=true
Style=0
EdgeMargins=10
DOCKQCONF

# lingmo-dock reads /etc/lingmo-dock-list.conf. Keep this list limited to
# desktop files that are actually installed in this ISO.
cat > /etc/lingmo-dock-list.conf <<'DOCKLIST'
[lingmo-filemanager]
DesktopPath=/usr/share/applications/lingmo-filemanager.desktop
Index=0

[chromium]
DesktopPath=/usr/share/applications/chromium.desktop
Index=1

[gnome-console]
DesktopPath=/usr/share/applications/org.gnome.Console.desktop
Index=2

[lingmo-settings]
DesktopPath=/usr/share/applications/lingmo-settings.desktop
Index=3

[lingmo-calculator]
DesktopPath=/usr/share/applications/lingmo-calculator.desktop
Index=4

[gnome-text-editor]
DesktopPath=/usr/share/applications/org.gnome.TextEditor.desktop
Index=5

[gnome-system-monitor]
DesktopPath=/usr/share/applications/org.gnome.SystemMonitor.desktop
Index=6
DOCKLIST

# Skel fallback for old/user-local dock configs.
cat > /etc/skel/.config/lingmo-dock/dock.conf <<'DOCKCONF'
[General]
PinnedLaunchers=lingmo-filemanager.desktop,chromium.desktop,org.gnome.Console.desktop,lingmo-settings.desktop,lingmo-calculator.desktop,org.gnome.TextEditor.desktop,org.gnome.SystemMonitor.desktop
ShowRecentApps=true
IconSize=40
Position=0
AutoHide=true
HideMode=1
DOCKCONF

# Also setup Plank config as fallback
mkdir -p /etc/skel/.config/plank/dock1
cat > /etc/skel/.config/plank/dock1/settings <<'PLANKCONF'
[PlankDock]
Alignment=2
AutoHide=true
HideMode=1
IconSize=40
Position=3
Theme=mixos-plank
ZoomEnabled=true
ZoomFactor=1.2
ShowDockItem=false
ShowDockItem=true
ItemPinnedGS='[]'
PLANKCONF

# Create dock launchers directory with .desktop links
mkdir -p /etc/skel/.config/plank/dock1/launchers
create_launcher() {
  local target="\$1"
  local name="\$2"
  local icon="\$3"
  local exec="\$4"
  if [[ -f "\${target}" ]]; then
    return 0
  fi
  cat > "\${target}" <<LAUNCHER
[Desktop Entry]
Type=Application
Name=\${name}
Exec=\${exec}
Icon=\${icon}
NoDisplay=true
Terminal=false
StartupNotify=true
Categories=Utility;
LAUNCHER
}
create_launcher "/etc/skel/.config/plank/dock1/launchers/files.desktop" "Files" "system-file-manager" "lingmo-filemanager"
create_launcher "/etc/skel/.config/plank/dock1/launchers/terminal.desktop" "Terminal" "utilities-terminal" "kgx"
create_launcher "/etc/skel/.config/plank/dock1/launchers/settings.desktop" "Settings" "settings-config" "lingmo-settings"
create_launcher "/etc/skel/.config/plank/dock1/launchers/browser.desktop" "Browser" "web-browser" "chromium"
create_launcher "/etc/skel/.config/plank/dock1/launchers/calculator.desktop" "Calculator" "accessories-calculator" "gnome-calculator"
for app in lingmo-filemanager.desktop chromium.desktop org.gnome.Console.desktop lingmo-settings.desktop lingmo-calculator.desktop org.gnome.TextEditor.desktop org.gnome.SystemMonitor.desktop; do
  for searchdir in /usr/share/applications /usr/local/share/applications; do
    if [ -f "\${searchdir}/\${app}" ]; then
      cp "\${searchdir}/\${app}" "/etc/skel/.config/plank/dock1/launchers/"
      break
    fi
  done
done
log_info "Dock launchers configured"

# === 14. Skel directories ===
mkdir -p /etc/skel/.config/dconf
mkdir -p /etc/skel/.local/share/applications
mkdir -p /etc/skel/Desktop

# === 15. Compile dconf database ===
log_info "Compiling dconf database"
if command -v dconf >/dev/null 2>&1; then
  dconf update
  log_info "dconf compiled successfully"
else
  log_warn "dconf command not found, database will be compiled on first boot"
fi

log_info "\${HOOK_NAME} selesai"
HOOK
  chmod +x "${hooks_normal_dir}/7000-mixos-setup.hook.chroot"

  cat > "${hooks_normal_dir}/9500-mixos-cleanup.hook.chroot" <<CLN
#!/usr/bin/env bash
set -euo pipefail
HOOK_NAME="mixos-cleanup"
log_info()  { printf "[%s] [INFO]  %s\n"  "\$(date +%H:%M:%S)" "\$*"; }
log_info "=== \${HOOK_NAME} ==="
apt-get clean
rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*
rm -f /root/.bash_history /home/*/.bash_history
find /var/log -type f -name '*.log' -delete 2>/dev/null || true
truncate -s 0 /etc/machine-id 2>/dev/null || true
rm -f /var/lib/dbus/machine-id /etc/ssh/ssh_host_*
log_info "Cleanup selesai"
CLN
  chmod +x "${hooks_normal_dir}/9500-mixos-cleanup.hook.chroot"

  # Package list
  local pkgs_dir="${work_dir}/lingmo-config/common/package-lists"
  mkdir -p "${pkgs_dir}"
  if [[ -f "${PROJECT_ROOT}/config/packages.list" ]]; then
    grep -vE '^\s*(#|$)' "${PROJECT_ROOT}/config/packages.list" \
      | grep -vE 'mixos-' \
      | awk '{print $1}' \
      > "${pkgs_dir}/mixos-packages.list.chroot" || true
    log_info "Packages: $(wc -l < "${pkgs_dir}/mixos-packages.list.chroot") extra"
  fi

  # Branding includes
  local inc="${work_dir}/lingmo-config/common/includes.chroot_after_packages"
  mkdir -p "${inc}/usr/share/mixos-branding/logo" "${inc}/usr/share/backgrounds/mixos" "${inc}/etc"
  [[ -f "${PROJECT_ROOT}/branding/logo/mixos-logo.svg" ]] && \
    cp "${PROJECT_ROOT}/branding/logo/mixos-logo.svg" "${inc}/usr/share/mixos-branding/logo/"
  [[ -f "${PROJECT_ROOT}/branding/wallpaper/mixos-default.svg" ]] && \
    cp "${PROJECT_ROOT}/branding/wallpaper/mixos-default.svg" "${inc}/usr/share/backgrounds/mixos/"
  [[ -f "${PROJECT_ROOT}/branding/wallpaper/mixos-dark.svg" ]] && \
    cp "${PROJECT_ROOT}/branding/wallpaper/mixos-dark.svg" "${inc}/usr/share/backgrounds/mixos/"
  echo "${PROJECT_DEFAULT_HOSTNAME}" > "${inc}/etc/hostname"

  # Live session identity and SDDM autologin.
  # Upstream Lingmo uses lingmo/live; our image uses mixos/live.
  mkdir -p "${inc}/etc/live/config.conf.d" "${inc}/usr/lib/live/config" "${inc}/etc"
  cat > "${inc}/etc/live/config.conf.d/user-setup.conf" <<EOF
LIVE_HOSTNAME="${PROJECT_DEFAULT_HOSTNAME}"
LIVE_USERNAME="${PROJECT_DEFAULT_USERNAME}"
LIVE_USER_FULLNAME="mixos Live User"
LIVE_USER_DEFAULT_GROUPS="audio cdrom dip floppy video plugdev netdev sudo"
EOF
  cat > "${inc}/usr/lib/live/config/1166-fix-sddm-auto-login" <<EOF
#!/bin/sh

rm -f /etc/sddm.conf
mkdir -p /usr/share/xsessions /usr/local/bin

cat << 'SESSIONSD' > /usr/share/xsessions/mixos.desktop
[Desktop Entry]
Name=MixOS
Comment=MixOS Desktop Session
Exec=/usr/local/bin/mixos-session
TryExec=/usr/local/bin/mixos-session
Type=Application
DesktopNames=Lingmo
SESSIONSD

cat << 'SESSIONEOF' > /usr/local/bin/mixos-session
#!/bin/sh
set -u

export XDG_CURRENT_DESKTOP=Lingmo
export XDG_SESSION_DESKTOP=Lingmo
export DESKTOP_SESSION=mixos
export QT_QPA_PLATFORM=xcb
export QT_QPA_PLATFORMTHEME=lingmo
export QT_PLATFORM_PLUGIN=lingmo
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_LOGGING_RULES="\${QT_LOGGING_RULES:-qt.qpa.xcb=false}"

LOG="\${HOME:-/tmp}/.mixos-session.log"
echo "mixos-session started at \$(date)" > "\$LOG"

mkdir -p "\${HOME}/Desktop" "\${HOME}/.config/lingmo-dock" "\${HOME}/.config/lingmoos" "\${HOME}/.config/plank/dock1"

copy_if_missing() {
  src="\$1"
  dst="\$2"
  if [ -f "\$src" ] && [ ! -f "\$dst" ]; then
    mkdir -p "\$(dirname "\$dst")"
    cp "\$src" "\$dst" 2>/dev/null || true
  fi
}

copy_if_missing /etc/skel/.config/lingmoos/theme.conf "\${HOME}/.config/lingmoos/theme.conf"
copy_if_missing /etc/skel/.config/lingmoos/dock.conf "\${HOME}/.config/lingmoos/dock.conf"
copy_if_missing /etc/skel/.config/lingmo-dock/dock.conf "\${HOME}/.config/lingmo-dock/dock.conf"
if [ -d /etc/skel/.config/plank/dock1 ]; then
  cp -an /etc/skel/.config/plank/dock1/. "\${HOME}/.config/plank/dock1/" 2>/dev/null || true
fi

start_if_exists() {
  cmd="\$1"
  shift
  if command -v "\$cmd" >/dev/null 2>&1; then
    echo "starting \$cmd \$*" >> "\$LOG"
    "\$cmd" "\$@" >> "\$LOG" 2>&1 &
    return 0
  fi
  echo "missing \$cmd" >> "\$LOG"
  return 1
}

keepalive_if_exists() {
  cmd="\$1"
  shift
  if command -v "\$cmd" >/dev/null 2>&1; then
    (
      while :; do
        echo "starting \$cmd \$*" >> "\$LOG"
        "\$cmd" "\$@" >> "\$LOG" 2>&1
        code="\$?"
        echo "\$cmd exited with \$code" >> "\$LOG"
        sleep 2
      done
    ) &
    return 0
  fi
  echo "missing \$cmd" >> "\$LOG"
  return 1
}

set_wallpaper() {
  wallpaper="/usr/share/backgrounds/lingmoos/default.jpg"
  [ -f "\$wallpaper" ] || wallpaper="/usr/share/backgrounds/lingmoos/wallpaper-0.jpg"
  [ -f "\$wallpaper" ] || wallpaper="/usr/share/backgrounds/mixos-default.jpg"

  if [ -f "\$wallpaper" ]; then
    if command -v xwallpaper >/dev/null 2>&1; then
      xwallpaper --zoom "\$wallpaper" >> "\$LOG" 2>&1 || true
    elif command -v feh >/dev/null 2>&1; then
      feh --bg-fill "\$wallpaper" >> "\$LOG" 2>&1 || true
    fi
  else
    xsetroot -solid '#9bc9ff' >/dev/null 2>&1 || true
  fi
}

fallback_desktop() {
  echo "starting fallback desktop stack" >> "\$LOG"
  start_if_exists kwin_x11 --replace
  sleep 1
  set_wallpaper
  start_if_exists lingmo-settings-daemon
  start_if_exists lingmo-appmotor
  start_if_exists lingmo-desktop
  start_if_exists lingmo-dock
  start_if_exists lingmo-launcher
  start_if_exists lingmo-statusbar
  start_if_exists nm-applet
  if command -v plank >/dev/null 2>&1 && ! pgrep -u "\$(id -u)" -x lingmo-dock >/dev/null 2>&1; then
    start_if_exists plank
  fi
}

if command -v dbus-run-session >/dev/null 2>&1 && [ -z "\${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  exec dbus-run-session -- /usr/local/bin/mixos-session
fi

if command -v lingmo-session >/dev/null 2>&1; then
  echo "starting upstream lingmo-session" >> "\$LOG"
  exec lingmo-session >> "\$LOG" 2>&1
else
  echo "missing lingmo-session; falling back" >> "\$LOG"
fi

fallback_desktop
sleep 4
if pgrep -u "\$(id -u)" -x lingmo-desktop >/dev/null 2>&1 || pgrep -u "\$(id -u)" -x lingmo-dock >/dev/null 2>&1; then
  echo "desktop components running; skipping fallback terminal" >> "\$LOG"
elif command -v xterm >/dev/null 2>&1; then
  xterm -title "MixOS fallback terminal" -geometry 100x28+80+80 >> "\$LOG" 2>&1 &
elif command -v lingmo-terminal >/dev/null 2>&1; then
  lingmo-terminal >> "\$LOG" 2>&1 &
elif command -v kgx >/dev/null 2>&1; then
  kgx >> "\$LOG" 2>&1 &
fi

wait
SESSIONEOF
chmod +x /usr/local/bin/mixos-session

cat << 'SDDMEOF' > /etc/sddm.conf
[Theme]
Current=lingmo

[Users]
# Default \$PATH for logged in users
# Don't change this, See issue in
# https://github.com/orgs/LingmoOS/discussions/25#discussioncomment-11029445
DefaultPath=/usr/bin:/bin

[Autologin]
User=${PROJECT_DEFAULT_USERNAME}
Session=mixos.desktop
Relogin=false
HiddenUsers=

SDDMEOF
EOF
  chmod +x "${inc}/usr/lib/live/config/1166-fix-sddm-auto-login"

  # Copy ke config/ (LingmoOS pattern)
  cp -rT "${work_dir}/lingmo-config/common" "${work_dir}/config"
  local variant_src="${work_dir}/lingmo-config/variant-default"
  if [[ -L "${variant_src}" ]]; then
    variant_src="$(readlink -f "${variant_src}")"
    log_info "Variant symlink resolved: variant-default -> ${variant_src}"
  fi
  cp -rT "${variant_src}" "${work_dir}/config" 2>/dev/null || true

  # Fix OBS repo URL & bypass GPG v3 rejection
  local archives_dir="${work_dir}/config/archives"
  mkdir -p "${archives_dir}"
  cat > "${archives_dir}/lingmo_pkg.list.chroot" <<ARCHIVE
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
  cat > "${archives_dir}/lingmo_pkg.list.binary" <<ARCHIVE
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
  log_info "Created archive files with correct OBS repo URL"

  # Fix package lists — remove packages not available in OBS repo or Debian base
  for list_file in "${work_dir}"/config/package-lists/*.list.chroot; do
    [[ -f "${list_file}" ]] || continue
    sed -i \
      -e '/^lingmo-base-files/d' \
      -e '/^lingmo-workspace-base/d' \
      -e '/^lingmo-plymouth/d' \
      -e '/^lingmo-grub-config/d' \
      -e '/^lingmo-live/d' \
      -e '/^lingmo-screenshot/d' \
      -e '/^neofetch/d' \
      -e '/^firmware-/d' \
      -e '/^bluez-firmware/d' \
      -e '/^broadcom-/d' \
      -e '/^reiserfsprogs/d' \
      -e '/^packagekit-tools/d' \
      -e '/^qml-module-org/d' \
      "${list_file}"
  done

  # Rewrite variant package list with verified available packages
  local variant_pkgs="${work_dir}/config/package-lists/lingmo.list.chroot"
  if [[ -f "${variant_pkgs}" ]]; then
    if lingmo_source_enabled; then
      cat > "${variant_pkgs}" <<LINGMO_SOURCE_LIST
# LingmoOS desktop packages are installed from local source-built .deb files
# in config/packages.chroot. Keep this apt list limited to base/session tools
# and non-Lingmo dependencies to avoid mixing OBS CI desktop components.

# Display & window manager
sddm
xorg
kwin-x11
konsole
plymouth

# Live & utils
live-boot
gparted
dirmngr
kscreen
sound-theme-freedesktop
sudo
parted
xwallpaper
plank

# Apps
chromium
chromium-l10n
LINGMO_SOURCE_LIST
      log_info "Rewrote variant package list for source-built LingmoOS packages"
    else
    cat > "${variant_pkgs}" <<LINGMO_LIST
# LingmoOS packages (available in OBS CI repo)
libicu76
liblingmo
lingmoui3
lingmo-core
lingmo-dock
lingmo-filemanager
lingmo-kwin-plugins
lingmo-kwin-plugins-roundedwindow
lingmo-launcher
lingmo-sddm-theme
lingmo-settings
lingmo-statusbar
lingmo-systemicons
lingmo-wallpapers
lingmo-calculator

# Display & window manager
sddm
xorg
kwin-x11
konsole
plymouth

# Live & utils
live-boot
gparted
dirmngr
kscreen
sound-theme-freedesktop
sudo
parted
xwallpaper
plank

# Apps
chromium
chromium-l10n
LINGMO_LIST
    log_info "Rewrote variant package list: lingmo.list.chroot"
    fi
  fi

  # Binary-only package list cleanup
  for list_file in "${work_dir}"/config/package-lists/*.list.binary; do
    [[ -f "${list_file}" ]] || continue
    sed -i \
      -e '/^neofetch/d' \
      "${list_file}"
  done
}

build_stub_pkgs() {
  local work_dir="$1"
  local pkgs_dir="${work_dir}/config/packages.chroot"
  local stub_base="qt6-base-private-abi-stub"
  local stub_decl="qt6-declarative-private-abi-stub"

  mkdir -p "${pkgs_dir}"

  # Build qt6-base-private-abi stub
  if ! ls "${pkgs_dir}/${stub_base}"*.deb >/dev/null 2>&1; then
    log_info "Building ${stub_base} (provides qt6-base-private-abi = 6.9.2)"
    local ctrl="/tmp/lingmo-stub-base.control"
    cat > "${ctrl}" << EOF
Section: misc
Priority: optional
Standards-Version: 4.6.0
Package: ${stub_base}
Version: 6.9.2
Provides: qt6-base-private-abi (= 6.9.2)
Architecture: all
Description: Stub for qt6-base-private-abi (= 6.9.2) Lingmo OBS compat
EOF
    pushd /tmp >/dev/null
    equivs-build "${ctrl}"
    popd >/dev/null
    cp /tmp/${stub_base}_*.deb "${pkgs_dir}/"
    rm -f "${ctrl}" /tmp/${stub_base}_*.deb
  fi

  # Build qt6-declarative-private-abi stub
  if ! ls "${pkgs_dir}/${stub_decl}"*.deb >/dev/null 2>&1; then
    log_info "Building ${stub_decl} (provides qt6-declarative-private-abi = 6.9.2)"
    local ctrl="/tmp/lingmo-stub-decl.control"
    cat > "${ctrl}" << EOF
Section: misc
Priority: optional
Standards-Version: 4.6.0
Package: ${stub_decl}
Version: 6.9.2
Provides: qt6-declarative-private-abi (= 6.9.2)
Architecture: all
Description: Stub for qt6-declarative-private-abi (= 6.9.2) Lingmo OBS compat
EOF
    pushd /tmp >/dev/null
    equivs-build "${ctrl}"
    popd >/dev/null
    cp /tmp/${stub_decl}_*.deb "${pkgs_dir}/"
    rm -f "${ctrl}" /tmp/${stub_decl}_*.deb
  fi

  log_info "Stub packages placed in config/packages.chroot/"
}

fetch_compat_pkgs() {
  local work_dir="$1"
  local pkgs_dir="${work_dir}/config/packages.chroot"
  local libicu_deb="${pkgs_dir}/libicu76_76.1-4_amd64.deb"
  local libicu_url="http://deb.debian.org/debian/pool/main/i/icu/libicu76_76.1-4_amd64.deb"

  mkdir -p "${pkgs_dir}"
  if [[ ! -f "${libicu_deb}" ]]; then
    log_info "Downloading libicu76 compatibility package from Debian trixie"
    wget -q -O "${libicu_deb}.tmp" "${libicu_url}"
    mv "${libicu_deb}.tmp" "${libicu_deb}"
  else
    log_info "libicu76 compatibility package already cached"
  fi
}

use_repo_lingmo_settings() {
  local work_dir="$1"
  local pkgs_dir="${work_dir}/config/packages.chroot"

  mkdir -p "${pkgs_dir}"
  if compgen -G "${pkgs_dir}/lingmo-settings*.deb" >/dev/null; then
    rm -f "${pkgs_dir}"/lingmo-settings*.deb
    log_info "Removed local lingmo-settings override; using repo package for version consistency"
  else
    log_info "Using repo-provided lingmo-settings"
  fi
}

build_lingmo_source_pkgs() {
  if ! lingmo_source_enabled; then
    log_info "LingmoOS source build disabled"
    return 0
  fi

  log_step "Build LingmoOS desktop packages from source"
  local source_builder="${PROJECT_ROOT}/scripts/build-lingmo-source.sh"
  if [[ ! -x "${source_builder}" ]]; then
    chmod +x "${source_builder}" 2>/dev/null || true
  fi

  if bash "${source_builder}"; then
    log_info "LingmoOS source packages are ready"
    return 0
  fi

  if lingmo_source_required; then
    log_error "LingmoOS source build failed; refusing to build another OBS-only ISO"
    log_error "Run this for details: sudo scripts/build-lingmo-source.sh --force"
    log_error "Or validate the source/cache only: sudo scripts/build-lingmo-source.sh --check-only"
    exit 1
  fi

  log_warn "LingmoOS source build failed; continuing because LINGMO_SOURCE_REQUIRED=false"
}

install_lingmo_source_pkgs() {
  local work_dir="$1"
  local source_out="${PROJECT_ROOT}/${LINGMO_SOURCE_OUT_DIR:-artifacts/lingmo-source-debs}"
  local pkgs_dir="${work_dir}/config/packages.chroot"
  local count=0
  local copied=0

  lingmo_source_enabled || return 0
  mkdir -p "${pkgs_dir}"

  if ! compgen -G "${source_out}/*.deb" >/dev/null; then
    if lingmo_source_required; then
      log_error "No LingmoOS source packages found in ${source_out}"
      exit 1
    fi
    log_warn "No LingmoOS source packages found in ${source_out}; using repo packages"
    return 0
  fi

  # Keep local Lingmo source packages as the authoritative desktop stack.
  rm -f "${pkgs_dir}"/lingmo-*.deb \
        "${pkgs_dir}"/liblingmo*.deb \
        "${pkgs_dir}"/lingmoui*.deb \
        2>/dev/null || true

  while IFS= read -r -d '' deb; do
    case "$(basename "${deb}")" in
      *-dev_*.deb|*-dbg_*.deb|*-dbgsym_*.deb|*-doc_*.deb)
        continue
        ;;
    esac
    cp "${deb}" "${pkgs_dir}/"
    copied=$((copied + 1))
  done < <(find "${source_out}" -maxdepth 1 -type f -name '*.deb' -print0)

  if [[ "${copied}" -eq 0 ]]; then
    log_error "LingmoOS source output contains no runtime .deb packages for the ISO"
    exit 1
  fi
  local required_pkg
  local missing_required=()
  for required_pkg in liblingmo lingmoui appmotor lingmo-desktop lingmo-dock lingmo-launcher lingmo-statusbar lingmo-settings; do
    if ! compgen -G "${pkgs_dir}/${required_pkg}_*.deb" >/dev/null; then
      missing_required+=("${required_pkg}")
    fi
  done
  if [[ "${#missing_required[@]}" -gt 0 ]]; then
    log_error "Missing required Lingmo desktop shell packages: ${missing_required[*]}"
    log_error "Run: sudo scripts/build-lingmo-source.sh --force"
    exit 1
  fi
  patch_local_lingmo_source_debs "${pkgs_dir}"
  count="$(find "${pkgs_dir}" -maxdepth 1 -type f -name '*.deb' | wc -l)"
  if [[ -f "${source_out}/.source-commit" ]]; then
    cp "${source_out}/.source-commit" "${work_dir}/.lingmo-source-commit"
  fi
  log_info "Installed LingmoOS source packages into live-build config (${count} local .deb files)"
}

repack_deb_without_dependency() {
  local deb="$1"
  local dep="$2"
  local tmp_dir
  local control_file
  local old_size
  local new_size

  [[ -f "${deb}" ]] || return 0
  tmp_dir="$(mktemp -d)"
  dpkg-deb -R "${deb}" "${tmp_dir}" >/dev/null
  control_file="${tmp_dir}/DEBIAN/control"

  if [[ -f "${control_file}" ]] && grep -q "${dep}" "${control_file}"; then
    log_warn "Removing unavailable dependency ${dep} from $(basename "${deb}")"
    sed -Ei \
      -e "s/,[[:space:]]*${dep}([[:space:]]*\\([^)]*\\))?//g" \
      -e "s/${dep}([[:space:]]*\\([^)]*\\))?,[[:space:]]*//g" \
      -e "/^[[:space:]]*${dep}([[:space:]]*\\([^)]*\\))?[[:space:]]*$/d" \
      "${control_file}"
    old_size="$(stat -c '%s' "${deb}")"
    dpkg-deb -b "${tmp_dir}" "${deb}" >/dev/null
    new_size="$(stat -c '%s' "${deb}")"
    log_info "Repacked $(basename "${deb}") (${old_size} -> ${new_size} bytes)"
  fi

  rm -rf "${tmp_dir}"
}

patch_local_lingmo_source_debs() {
  local pkgs_dir="$1"
  local deb

  while IFS= read -r -d '' deb; do
    repack_deb_without_dependency "${deb}" "appmenu-gtk2-module"
  done < <(find "${pkgs_dir}" -maxdepth 1 -type f -name 'lingmo-core_*.deb' -print0)

  while IFS= read -r -d '' deb; do
    repack_deb_without_dependency "${deb}" "lingmo-kwin-plugins-roundedwindow"
  done < <(find "${pkgs_dir}" -maxdepth 1 -type f -name 'lingmo-kwin-plugins_*.deb' -print0)

  # This OBS package targets newer Qt than Debian trixie currently installs.
  rm -f "${pkgs_dir}"/lingmo-kwin-plugins-roundedwindow_*.deb 2>/dev/null || true
}

unmount_chroot_mounts() {
  local chroot_dir="$1"
  local mount_point

  for mount_point in \
    "${chroot_dir}/run/lock" \
    "${chroot_dir}/run" \
    "${chroot_dir}/dev/pts" \
    "${chroot_dir}/dev" \
    "${chroot_dir}/proc" \
    "${chroot_dir}/sys"; do
    if mountpoint -q "${mount_point}" 2>/dev/null; then
      umount -l "${mount_point}" 2>/dev/null || true
    fi
  done
}

reset_chroot_if_local_settings_override() {
  local work_dir="$1"
  local chroot_dir="${work_dir}/chroot"
  local installed_version=""
  local has_local_package="false"
  local has_trixie_repo="false"
  local source_stamp="${work_dir}/.lingmo-source-commit"
  local old_source_stamp="${work_dir}/.lingmo-source-commit.applied"
  local source_state_changed="false"

  [[ -d "${chroot_dir}" ]] || return 0

  if compgen -G "${chroot_dir}/packages/lingmo-settings*.deb" >/dev/null; then
    has_local_package="true"
  fi
  if [[ -x "${chroot_dir}/usr/bin/dpkg-query" ]]; then
    installed_version="$(chroot "${chroot_dir}" dpkg-query -W -f='${Version}' lingmo-settings 2>/dev/null || true)"
  fi
  if [[ -e "${chroot_dir}/etc/apt/sources.list.d/trixie_compat.list" || \
        -e "${chroot_dir}/etc/apt/preferences.d/trixie_compat.pref" ]]; then
    has_trixie_repo="true"
  fi
  if lingmo_source_enabled; then
    if [[ ! -f "${old_source_stamp}" || ! -f "${source_stamp}" || \
          "$(cat "${old_source_stamp}" 2>/dev/null)" != "$(cat "${source_stamp}" 2>/dev/null)" || \
          "${installed_version}" == *"~2025"* || "${installed_version}" == *"~2024"* ]]; then
      source_state_changed="true"
    fi
  fi

  if [[ "${has_local_package}" == "true" || "${installed_version}" == "3.0.1~1" || \
        "${has_trixie_repo}" == "true" || "${source_state_changed}" == "true" ]]; then
    log_info "Existing chroot contains stale package state; rebuilding chroot with package cache preserved"
    unmount_chroot_mounts "${chroot_dir}"
    rm -rf "${chroot_dir}" \
           "${work_dir}/binary" \
           "${work_dir}/chroot.files" \
           "${work_dir}/binary.contents" \
           "${work_dir}/binary.packages" \
           2>/dev/null || true
    rm -f "${work_dir}"/.build/chroot_* \
          "${work_dir}"/.build/binary_* \
          2>/dev/null || true
  fi

  if [[ -f "${source_stamp}" ]]; then
    cp "${source_stamp}" "${old_source_stamp}" 2>/dev/null || true
  fi
}

build_lingmo_settings() {
  local work_dir="$1"
  local pkgs_dir="${work_dir}/config/packages.chroot"
  local build_chroot="/var/cache/mixos-build-chroot"

  cleanup_build_chroot() {
    if mountpoint -q "${build_chroot}/proc" 2>/dev/null; then
      umount -l "${build_chroot}/proc" 2>/dev/null || true
    fi
    if mountpoint -q "${build_chroot}/dev" 2>/dev/null; then
      umount -l "${build_chroot}/dev" 2>/dev/null || true
    fi
    if mountpoint -q "${build_chroot}/sys" 2>/dev/null; then
      umount -l "${build_chroot}/sys" 2>/dev/null || true
    fi
  }
  trap cleanup_build_chroot EXIT

  # Bersihkan mount lama kalau build sebelumnya sempat gagal.
  cleanup_build_chroot

  if ls "${pkgs_dir}"/lingmo-settings*.deb >/dev/null 2>&1; then
    log_info "lingmo-settings already built, skipping"
    trap - EXIT
    return 0
  fi

  if [ ! -d "${build_chroot}" ]; then
    log_info "Creating ${DEBIAN_CODENAME} build chroot..."
    if command -v mmdebstrap >/dev/null 2>&1; then
      if ! mmdebstrap --variant=buildd --format=directory \
        --include="build-essential,devscripts,cmake,extra-cmake-modules,git,ca-certificates,pkg-config" \
        "${DEBIAN_CODENAME}" "${build_chroot}" http://deb.debian.org/debian; then
        log_warn "mmdebstrap failed; retrying with debootstrap fallback"
        rm -rf "${build_chroot}"
      fi
    fi
    if [ ! -d "${build_chroot}" ]; then
      debootstrap --variant=minbase \
        --include=build-essential,devscripts,cmake,extra-cmake-modules,git,ca-certificates,pkg-config \
        "${DEBIAN_CODENAME}" "${build_chroot}" http://deb.debian.org/debian
    fi
    mount --bind /proc "${build_chroot}/proc"
    mount --bind /dev "${build_chroot}/dev"
    mount --bind /sys "${build_chroot}/sys"
    cp /etc/resolv.conf "${build_chroot}/etc/resolv.conf"
  fi

  # Add OBS repo and stub packages to build chroot
  mkdir -p "${build_chroot}/etc/apt/sources.list.d"
  echo "deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./" \
    > "${build_chroot}/etc/apt/sources.list.d/lingmo-obs.list"
  mkdir -p "${build_chroot}/tmp/pkgs"
  cp "${pkgs_dir}"/*.deb "${build_chroot}/tmp/pkgs/"

  chroot "${build_chroot}" bash -c "
    apt-get update -qq 2>&1 | tail -3 || true
    # Install stub packages FIRST to satisfy ABI deps
    dpkg -i /tmp/pkgs/*.deb 2>&1 | tail -3 || true
    apt-get install -f -y 2>&1 | tail -3 || true
    # Now install OBS packages and build deps
    apt-get install -y --no-install-recommends -o DPkg::Options::=--force-confnew \
      liblingmo lingmoui3 libkf6config-dev libkf6networkmanagerqt-dev \
      libkf6modemmanagerqt-dev libkf6bluezqt-dev libkf6kio-dev libkscreen-dev \
      qt6-base-dev qt6-declarative-dev qt6-tools-dev qt6-tools-dev-tools qt6-5compat-dev \
      debhelper-compat libicu-dev libcrypt-dev libxi-dev libxcursor-dev \
      libqt5concurrent5 qt6-declarative-private-dev libpackagekitqt6-dev network-manager \
      2>&1 | tail -10
  " 2>&1 | tail -5

  # Clone and build lingmo-settings
  if [ ! -d "${build_chroot}/src/lingmo-settings" ]; then
    chroot "${build_chroot}" git clone --depth 1 \
      https://github.com/LingmoOS/lingmo-settings.git /src/lingmo-settings
  fi

  # Install build deps from debian/control
  chroot "${build_chroot}" bash -c "cd /src/lingmo-settings && \
    mk-build-deps -i -t 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y' debian/control 2>&1 | tail -5" || true

  # Install extra private Qt deps not in debian/control
  chroot "${build_chroot}" apt-get install -y --no-install-recommends \
    qt6-base-private-dev libxcb-errors-dev 2>&1 | tail -3

  # Patch CMakeLists.txt: Qt6GuiPrivate not auto-loaded in Qt 6.10
  if ! grep -q 'find_package(Qt6GuiPrivate' "${build_chroot}/src/lingmo-settings/CMakeLists.txt" 2>/dev/null; then
    sed -i 's/find_package(LingmoLogger REQUIRED)/find_package(LingmoLogger REQUIRED)\nfind_package(Qt6GuiPrivate REQUIRED)/' \
      "${build_chroot}/src/lingmo-settings/CMakeLists.txt"
  fi
  # Skip a broken translation file that aborts the whole build.
  if ! grep -q 'eo_XX.ts' "${build_chroot}/src/lingmo-settings/CMakeLists.txt" 2>/dev/null; then
    perl -0pi -e 's|file\(GLOB TS_FILES translations/\*\.ts\)\n|file(GLOB TS_FILES translations/*.ts)\nlist(FILTER TS_FILES EXCLUDE REGEX "eo_XX\\.ts\$")\n|' \
      "${build_chroot}/src/lingmo-settings/CMakeLists.txt"
  fi

  # Fix invalid date in debian/changelog (Tue, 46 Jul 2024)
  sed -i 's/Tue, 46 Jul 2024/Tue, 30 Jul 2024/' \
    "${build_chroot}/src/lingmo-settings/debian/changelog"

  # Build
  chroot "${build_chroot}" bash -c "cd /src/lingmo-settings && export MAKEFLAGS='-j$(nproc)' DEB_BUILD_OPTIONS='parallel=$(nproc)' && dpkg-buildpackage -b -uc -us -j$(nproc)"

  # Copy result
  cp "${build_chroot}/src/"lingmo-settings*.deb "${pkgs_dir}/" 2>/dev/null || true
  log_info "lingmo-settings built and placed in config/packages.chroot/"

  trap - EXIT
  cleanup_build_chroot
}

run_build() {
  local upstream="${PROJECT_ROOT}/${UPSTREAM_DIR}/live-build-config"
  local work_dir="${PROJECT_ROOT}/${BUILD_DIR}/work-${BASE_ARCH}"

  log_step "Setup working directory"
  if [[ "${CLEAN}" == "true" || ! -d "${work_dir}/cache" ]]; then
    log_info "Clean build: hapus work dir"
    rm -rf "${work_dir}"
    mkdir -p "${work_dir}"
  else
    log_info "Cache ditemukan, pakai build incremental (--clean untuk bersih)"
  fi

  build_lingmo_source_pkgs
  setup_config "${work_dir}"
  cd "${work_dir}"

  log_step "lb config"
  DEBIAN_FRONTEND=noninteractive \
  lb config noauto \
    --distribution "${DEBIAN_CODENAME}" \
    --debian-installer-distribution "${DEBIAN_CODENAME}" \
    --archive-areas "main contrib non-free non-free-firmware" \
    --apt-recommends false \
    --apt-indices false \
    --apt-options "-o DPkg::Options::=\"--force-confnew\" -o Acquire::Check-Valid-Until=false -o Acquire::ForceIPv4=true -y" \
    --updates true \
    --backports true \
    --source false \
    --firmware-binary true \
    --firmware-chroot true \
    --uefi-secure-boot enable \
    --initramfs live-boot \
    --mirror-bootstrap "http://deb.debian.org/debian" \
    --mirror-binary "http://deb.debian.org/debian" \
    --mirror-debian-installer "http://deb.debian.org/debian" \
    --iso-application "mixos" \
    --iso-publisher "mixos" \
    --iso-volume "MIXOS" \
    --linux-packages "linux-image linux-headers" \
    --memtest none \
    --bootappend-live "boot=live components noeject" \
    --bootappend-live-failsafe "boot=live components noeject memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal" \
    --debootstrap-options "--include=apt-transport-https,ca-certificates,openssl" \
    --security false \
    --win32-loader false \
    --cache-packages true \
    --cache-stages bootstrap \
    -a "${BASE_ARCH}"

  # Remove ALL stale chroot stage stamps so all stages re-run
  # with correct repos (preserves bootstrap cache, avoids full redownload)
  rm -f "${work_dir}"/.build/chroot_* \
        "${work_dir}"/.build/bootstrap* \
        2>/dev/null || true
  log_info "Removed stale chroot stamps, bootstrap cache preserved"

  build_stub_pkgs "${work_dir}"
  fetch_compat_pkgs "${work_dir}"
  if lingmo_source_enabled; then
    install_lingmo_source_pkgs "${work_dir}"
  else
    use_repo_lingmo_settings "${work_dir}"
  fi
  reset_chroot_if_local_settings_override "${work_dir}"

  log_step "lb build"
  echo "---[ live-build output start ]---"
  lb build 2>&1
  echo "---[ live-build output end ]---"

  log_step "Move ISO output"
  local iso_file
  iso_file="$(find . -maxdepth 1 -name 'live-image-*.hybrid.iso' -type f | head -1)"
  if [[ -z "${iso_file}" ]]; then
    log_error "ISO tidak ditemukan!"; ls -la "${work_dir}"; exit 1
  fi
  local yyyymmdd
  yyyymmdd="$(date +%Y%m%d)"
  local output_name="${PROJECT_NAME}-${PROJECT_CODENAME}-${PROJECT_VERSION_ID}-${BASE_ARCH}.${yyyymmdd}.iso"
  local output_dir="${PROJECT_ROOT}/${BUILD_DIR}"
  mkdir -p "${output_dir}"
  mv "${iso_file}" "${output_dir}/${output_name}"
  cd "${output_dir}"
  sha256sum "${output_name}" > "${output_name}.sha256"
  md5sum "${output_name}" > "${output_name}.md5"
  if [[ -f "${work_dir}/.lingmo-source-commit" ]]; then
    cp "${work_dir}/.lingmo-source-commit" "${work_dir}/.lingmo-source-commit.applied" 2>/dev/null || true
  fi
  log_info "SHA256: $(cat "${output_name}.sha256")"

  if [[ -n "${WINDOWS_OUTPUT_DIR:-}" && -d "$(dirname "${WINDOWS_OUTPUT_DIR}")" ]]; then
    mkdir -p "${WINDOWS_OUTPUT_DIR}"
    mv -f "${output_name}" "${output_name}.sha256" "${output_name}.md5" "${WINDOWS_OUTPUT_DIR}/"
    log_info "Moved ISO and checksums to ${WINDOWS_OUTPUT_DIR}/"
  fi
}

install_deps() {
  log_step "Install build dependencies"
  local deps=(live-build debootstrap xorriso isolinux syslinux-common
    grub-pc-bin grub-efi-amd64-bin grub-efi-ia32-bin mtools squashfs-tools
    genisoimage curl wget rsync git equivs mmdebstrap build-essential g++
    cmake dpkg-dev gettext devscripts debhelper pkg-config extra-cmake-modules
    ninja-build reprepro python3)
  local missing=()
  for pkg in "${deps[@]}"; do
    if ! dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"; then
      missing+=("${pkg}")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_info "Install missing: ${missing[*]}"
    apt-get update -qq && apt-get install -y --no-install-recommends "${missing[@]}"
  else
    log_info "All deps already installed"
  fi
}

print_summary() {
  log_step "Ringkasan Build"
  echo "Project   : ${PROJECT_NAME} ${PROJECT_VERSION} (${PROJECT_CODENAME})"
  echo "Build     : ${PROJECT_BUILD_DATE}"
  echo "Output    : ${PROJECT_ROOT}/${BUILD_DIR}/"
  echo "Next step : Test ISO dengan test-vm.sh atau VirtualBox"
}

main() {
  parse_args "$@"
  log_step "build.sh — mixos ISO builder (LingmoOS base)"
  load_config
  validate_environment
  prepare_dirs
  clone_upstream
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Build tidak dijalankan. Jalankan: sudo ./build.sh --no-dry-run"
    print_summary
    return 0
  fi
  install_deps
  run_build
  print_summary
  log_info "build.sh selesai"
}

main "$@"