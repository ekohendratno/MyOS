#!/usr/bin/env bash
# =============================================================================
# 004-apply-theme.sh — Terapkan theme mixos
# =============================================================================
# - Install theme GTK, icon, cursor ke /usr/share/themes atau /usr/share/icons
# - Set default theme via dconf
# - Aktifkan override settings.ini GTK3
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="004-apply-theme"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

# shellcheck disable=SC1090
source "${CONFIG_FILE}" 2>/dev/null || {
  log_error "Config tidak ditemukan"
  exit 1
}

log_info "=== ${HOOK_NAME} ==="
log_info "GTK theme  : ${PROJECT_GTK_THEME}"
log_info "Icon theme : ${PROJECT_ICON_THEME}"
log_info "Cursor     : ${PROJECT_CURSOR_THEME}"

# === 1. Copy theme GTK ===
readonly THEMES_SHARE="/usr/share/themes"
if [[ -d "${PROJECT_ROOT}/${PATH_THEMES}/mixos-gtk" ]]; then
  log_info "Copy GTK theme: ${PROJECT_GTK_THEME}"
  mkdir -p "${THEMES_SHARE}"
  cp -r "${PROJECT_ROOT}/${PATH_THEMES}/mixos-gtk" "${THEMES_SHARE}/" 2>/dev/null || \
    log_warn "Gagal copy GTK theme (asset mungkin belum dibuat)"
else
  log_warn "Folder theme belum ada: ${PROJECT_ROOT}/${PATH_THEMES}/mixos-gtk"
fi

# === 2. Copy icon theme ===
readonly ICONS_SHARE="/usr/share/icons"
if [[ -d "${PROJECT_ROOT}/${PATH_THEMES}/mixos-icons" ]]; then
  log_info "Copy icon theme: ${PROJECT_ICON_THEME}"
  mkdir -p "${ICONS_SHARE}"
  cp -r "${PROJECT_ROOT}/${PATH_THEMES}/mixos-icons" "${ICONS_SHARE}/" 2>/dev/null || \
    log_warn "Gagal copy icon theme"
else
  log_warn "Folder icon theme belum ada: ${PROJECT_ROOT}/${PATH_THEMES}/mixos-icons"
fi

# === 3. Copy cursor theme ===
if [[ -d "${PROJECT_ROOT}/${PATH_THEMES}/mixos-cursors" ]]; then
  log_info "Copy cursor theme: ${PROJECT_CURSOR_THEME}"
  cp -r "${PROJECT_ROOT}/${PATH_THEMES}/mixos-cursors" "${ICONS_SHARE}/" 2>/dev/null || \
    log_warn "Gagal copy cursor theme"
fi

# === 4. Copy shell theme (Plymouth) ===
if [[ -d "${PROJECT_ROOT}/${PATH_THEMES}/mixos-shell" ]]; then
  log_info "Copy shell theme: ${PROJECT_SHELL_THEME}"
  cp -r "${PROJECT_ROOT}/${PATH_THEMES}/mixos-shell" "${THEMES_SHARE}/" 2>/dev/null || \
    log_warn "Gagal copy shell theme"
fi

# === 5. Update icon cache untuk setiap icon theme ===
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  for d in "${ICONS_SHARE}"/*/; do
    if [[ -f "${d}/index.theme" ]]; then
      log_info "Update icon cache: $(basename "${d}")"
      gtk-update-icon-cache -f -t "${d}" 2>/dev/null || true
    fi
  done
fi

# === 6. Update GTK cache ===
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  for d in "${THEMES_SHARE}"/*/; do
    if [[ -f "${d}/index.theme" ]]; then
      log_info "Update GTK cache: $(basename "${d}")"
    fi
  done
fi

# === 7. Tulis settings.ini GTK3 ===
readonly GTK3_SETTINGS="/etc/gtk-3.0/settings.ini"
log_info "Menulis ${GTK3_SETTINGS}"
mkdir -p "$(dirname "${GTK3_SETTINGS}")"
if [[ -f "${PROJECT_ROOT}/config/gtk-settings.ini" ]]; then
  cp "${PROJECT_ROOT}/config/gtk-settings.ini" "${GTK3_SETTINGS}"
else
  log_warn "gtk-settings.ini tidak ada, skip"
fi

# === 8. Tulis settings.ini GTK4 ===
readonly GTK4_SETTINGS="/etc/gtk-4.0/settings.ini"
log_info "Menulis ${GTK4_SETTINGS}"
mkdir -p "$(dirname "${GTK4_SETTINGS}")"
# GTK4 tidak pakai settings.ini penuh, hanya beberapa key
cat > "${GTK4_SETTINGS}" <<'EOF'
[Settings]
gtk-theme-name=mixos-gtk
gtk-icon-theme-name=mixos-icons
gtk-cursor-theme-name=mixos-cursors
gtk-cursor-theme-size=24
gtk-font-name=Inter 10.5
gtk-application-prefer-dark-theme=1
EOF

# === 9. Set default theme via dconf ===
log_info "Menulis dconf default theme"
mkdir -p /etc/dconf/db/mixos.d
cat > /etc/dconf/db/mixos.d/06-mixos-theme <<EOF
# mixos theme defaults
[org/gnome/desktop/interface]
gtk-theme='${PROJECT_GTK_THEME}'
icon-theme='${PROJECT_ICON_THEME}'
cursor-theme='${PROJECT_CURSOR_THEME}'
font-name='Inter 10.5'
EOF

log_info "Compile dconf database"
dconf update

log_info "${HOOK_NAME} selesai"
exit 0
