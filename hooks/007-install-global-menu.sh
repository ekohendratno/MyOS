#!/usr/bin/env bash
# =============================================================================
# 007-install-global-menu.sh — Eksperimen global menu
# =============================================================================
# Hanya dijalankan jika ENABLE_GLOBAL_MENU_EXPERIMENT=true.
# Install appmenu-gtk-module dan paket pendukung.
# CATATAN: keterbatasan global menu sangat banyak, lihat docs/GLOBAL_MENU_NOTES.md.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="007-install-global-menu"

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

# === Cek flag ===
ENABLE_GLOBAL_MENU_EXPERIMENT="${ENABLE_GLOBAL_MENU_EXPERIMENT:-false}"

if [[ "${ENABLE_GLOBAL_MENU_EXPERIMENT}" != "true" ]]; then
  log_info "ENABLE_GLOBAL_MENU_EXPERIMENT=false, skip"
  exit 0
fi

log_warn "EKSPERIMEN: Global menu memiliki keterbatasan besar"
log_warn "Lihat docs/GLOBAL_MENU_NOTES.md sebelum mengaktifkan"

# === Install paket pendukung ===
export DEBIAN_FRONTEND=noninteractive
PACKAGES=(
  "appmenu-gtk2-module"
  "appmenu-gtk3-module"
  "appmenu-gtk-module-common"
  "dbusmenu-glib"
  "dbusmenu-gtk3"
  "libdbusmenu-glib-dev"
  "libdbusmenu-gtk3-dev"
  "indicator-application"
  "libindicator3-7"
  "libindicator3-dev"
  "wingpanel-indicator-appmenu"
)

log_info "Install paket global menu: ${PACKAGES[*]}"
apt-get install -y "${PACKAGES[@]}" || {
  log_warn "Beberapa paket global menu gagal di-install"
  log_warn "Ini bukan error fatal, mixos akan jalan tanpa global menu"
}

# === Aktifkan GTK modules ===
log_info "Set GTK_MODULES di /etc/environment"
if ! grep -q "GTK_MODULES" /etc/environment 2>/dev/null; then
  cat >> /etc/environment <<EOF
GTK_MODULES=appmenu-gtk-module:globalmenu
EOF
else
  log_info "GTK_MODULES sudah di-set, skip append"
fi

# === Aktifkan prefer app menu di dconf ===
log_info "Set gtk-application-prefers-app-menu=true"
cat > /etc/dconf/db/mixos.d/07-global-menu <<'EOF'
# mixos global menu preference
[org/gnome/desktop/interface]
gtk-application-prefers-app-menu=true
EOF

dconf update

log_info "${HOOK_NAME} selesai (eksperimen, lihat keterbatasan)"
exit 0
