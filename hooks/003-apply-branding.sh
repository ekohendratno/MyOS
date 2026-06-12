#!/usr/bin/env bash
# =============================================================================
# 003-apply-branding.sh — Terapkan branding mixos
# =============================================================================
# - Generate /etc/os-release
# - Set hostname default
# - Siapkan folder logo, wallpaper, plymouth, grub
# - Hapus branding elementary dari About (best effort)
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="003-apply-branding"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"
readonly OS_RELEASE_CONF="${PROJECT_ROOT}/config/os-release.conf"

# shellcheck disable=SC1090
source "${CONFIG_FILE}" 2>/dev/null || {
  log_error "Config tidak ditemukan"
  exit 1
}
# shellcheck disable=SC1090
source "${OS_RELEASE_CONF}" 2>/dev/null || {
  log_error "os-release.conf tidak ditemukan"
  exit 1
}

log_info "=== ${HOOK_NAME} ==="
log_info "Menerapkan branding: ${OS_PRETTY_NAME}"

# === 1. Generate /etc/os-release ===
log_info "Menulis /etc/os-release"
cat > /etc/os-release <<EOF
NAME="${OS_NAME}"
PRETTY_NAME="${OS_PRETTY_NAME}"
ID="${OS_ID}"
ID_LIKE="${OS_ID_LIKE}"
VERSION="${OS_VERSION}"
VERSION_ID="${OS_VERSION_ID}"
VERSION_CODENAME="${OS_VERSION_CODENAME}"
HOME_URL="${OS_HOME_URL}"
SUPPORT_URL="${OS_SUPPORT_URL}"
BUG_REPORT_URL="${OS_BUG_REPORT_URL}"
PRIVACY_POLICY_URL="${OS_PRIVACY_POLICY_URL}"
EOF

# === 2. Symlink untuk lsb_release ===
if [[ -f /etc/lsb-release ]]; then
  log_info "Update /etc/lsb-release"
  cat > /etc/lsb-release <<EOF
DISTRIB_ID=${OS_ID}
DISTRIB_RELEASE=${OS_VERSION_ID}
DISTRIB_CODENAME=${OS_VERSION_CODENAME}
DISTRIB_DESCRIPTION="${OS_PRETTY_NAME}"
EOF
fi

# === 3. Hostname default ===
log_info "Set hostname default: ${PROJECT_DEFAULT_HOSTNAME}"
echo "${PROJECT_DEFAULT_HOSTNAME}" > /etc/hostname

# === 4. Copy branding asset ke /usr/share ===
readonly SHARE_BRANDING="/usr/share/mixos-branding"
log_info "Membuat direktori branding: ${SHARE_BRANDING}"
mkdir -p "${SHARE_BRANDING}/logo"
mkdir -p "${SHARE_BRANDING}/wallpaper"
mkdir -p "${SHARE_BRANDING}/icons"
mkdir -p "${SHARE_BRANDING}/about"

# Logo
if [[ -f "${PROJECT_ROOT}/${PROJECT_LOGO_PATH}" ]]; then
  cp "${PROJECT_ROOT}/${PROJECT_LOGO_PATH}" "${SHARE_BRANDING}/logo/"
  log_info "Logo di-copy: ${PROJECT_LOGO_PATH}"
else
  log_warn "Logo mixos belum ada: ${PROJECT_ROOT}/${PROJECT_LOGO_PATH}"
  log_warn "Lewati tahap ini, branding akan default"
fi

if [[ -f "${PROJECT_ROOT}/${PROJECT_LOGO_PNG_PATH}" ]]; then
  cp "${PROJECT_ROOT}/${PROJECT_LOGO_PNG_PATH}" "${SHARE_BRANDING}/logo/"
fi

# Wallpaper
if [[ -f "${PROJECT_ROOT}/${PROJECT_WALLPAPER_DEFAULT}" ]]; then
  cp "${PROJECT_ROOT}/${PROJECT_WALLPAPER_DEFAULT}" "${SHARE_BRANDING}/wallpaper/"
  log_info "Wallpaper di-copy: ${PROJECT_WALLPAPER_DEFAULT}"
else
  log_warn "Wallpaper mixos belum ada: ${PROJECT_ROOT}/${PROJECT_WALLPAPER_DEFAULT}"
fi

# === 5. Install wallpaper ke /usr/share/backgrounds ===
readonly BACKGROUNDS_DIR="/usr/share/backgrounds/mixos"
log_info "Membuat direktori: ${BACKGROUNDS_DIR}"
mkdir -p "${BACKGROUNDS_DIR}"

if [[ -f "${PROJECT_ROOT}/${PROJECT_WALLPAPER_DEFAULT}" ]]; then
  cp "${PROJECT_ROOT}/${PROJECT_WALLPAPER_DEFAULT}" "${BACKGROUNDS_DIR}/mixos-default.jpg"
fi
if [[ -f "${PROJECT_ROOT}/${PROJECT_WALLPAPER_DARK}" ]]; then
  cp "${PROJECT_ROOT}/${PROJECT_WALLPAPER_DARK}" "${BACKGROUNDS_DIR}/mixos-dark.jpg"
fi

# === 6. Install Plymouth theme ===
log_info "Install Plymouth theme mixos"
readonly PLYMOUTH_DIR="/usr/share/plymouth/themes/mixos"
if [[ -d "${PROJECT_ROOT}/branding/plymouth/mixos" ]]; then
  mkdir -p "${PLYMOUTH_DIR}"
  cp "${PROJECT_ROOT}/branding/plymouth/mixos/"* "${PLYMOUTH_DIR}/" 2>/dev/null || true
  # Aktivasi
  if command -v update-alternatives >/dev/null 2>&1 && [[ -f "${PLYMOUTH_DIR}/mixos.plymouth" ]]; then
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "${PLYMOUTH_DIR}/mixos.plymouth" 100 2>/dev/null || true
    log_info "Plymouth theme mixos di-install"
  fi
else
  log_warn "Plymouth theme dir belum ada: branding/plymouth/mixos/"
fi

# === 7. Install GRUB theme ===
log_info "Install GRUB theme mixos"
readonly GRUB_DIR="/boot/grub/themes/mixos"
if [[ -d "${PROJECT_ROOT}/branding/grub" ]]; then
  mkdir -p "${GRUB_DIR}"
  cp "${PROJECT_ROOT}/branding/grub/"* "${GRUB_DIR}/" 2>/dev/null || true
  # Set GRUB_THEME di /etc/default/grub jika belum ada
  if [[ -f /etc/default/grub ]] && command -v update-grub >/dev/null 2>&1; then
    if ! grep -q "GRUB_THEME=" /etc/default/grub; then
      echo "GRUB_THEME=${GRUB_DIR}/theme.txt" >> /etc/default/grub
    fi
    log_info "GRUB theme mixos di-install"
  fi
else
  log_warn "GRUB theme dir belum ada: branding/grub/"
fi

# === 8. Install About dialog ===
log_info "Install About dialog content"
readonly ABOUT_DIR="/usr/share/mixos-branding/about"
mkdir -p "${ABOUT_DIR}"
if [[ -f "${PROJECT_ROOT}/branding/about/mixos-about.json" ]]; then
  cp "${PROJECT_ROOT}/branding/about/mixos-about.json" "${ABOUT_DIR}/"
fi
if [[ -f "${PROJECT_ROOT}/branding/about/README.md" ]]; then
  cp "${PROJECT_ROOT}/branding/about/README.md" "${ABOUT_DIR}/"
fi

# === 9. Update issue dan motd ===
log_info "Update /etc/issue dan /etc/issue.net"
cat > /etc/issue <<EOF
${OS_PRETTY_NAME} \n \l

EOF

cat > /etc/issue.net <<EOF
${OS_PRETTY_NAME}

EOF

# === 7. Hapus branding elementary dari identifier (best effort) ===
# HATI-HATI: ini TIDAK menghapus paket, hanya modify file yang
# mengidentifikasi elementary. upstream distro ID di /etc/os-release
# sudah di-override, tetapi beberapa tempat masih menyebut "elementary".

# Replace di /etc/update-motd.d
if [[ -d /etc/update-motd.d ]]; then
  for f in /etc/update-motd.d/*; do
    if [[ -f "${f}" ]] && grep -lq "elementary" "${f}" 2>/dev/null; then
      log_warn "Ditemukan referensi elementary di: ${f}"
      log_warn "Pertimbangkan untuk replace manual (best effort, skip untuk safety)"
    fi
  done
fi

log_info "${HOOK_NAME} selesai"
exit 0
