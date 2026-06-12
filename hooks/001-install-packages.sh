#!/usr/bin/env bash
# =============================================================================
# 001-install-packages.sh — Install paket tambahan mixos
# =============================================================================
# Hook ini dijalankan live-build di dalam chroot SETELAH debootstrap dan
# SETELAH paket elementary terinstall. Membaca config/packages.list dan
# install paket tambahan.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="001-install-packages"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"
readonly PACKAGES_LIST="${PROJECT_ROOT}/config/packages.list"

# shellcheck disable=SC1090
source "${CONFIG_FILE}" 2>/dev/null || {
  log_error "Config tidak ditemukan: ${CONFIG_FILE}"
  exit 1
}

log_info "=== ${HOOK_NAME} ==="
log_info "Project: ${PROJECT_NAME} ${PROJECT_VERSION}"

# === Validasi ===
if [[ ! -f "${PACKAGES_LIST}" ]]; then
  log_error "Packages list tidak ada: ${PACKAGES_LIST}"
  exit 1
fi

# === Baca dan filter paket (skip komentar dan baris kosong) ===
log_info "Membaca ${PACKAGES_LIST}"
mapfile -t packages < <(grep -vE '^\s*(#|$)' "${PACKAGES_LIST}" || true)

if [[ ${#packages[@]} -eq 0 ]]; then
  log_warn "Tidak ada paket untuk di-install"
  exit 0
fi

log_info "Akan install ${#packages[@]} paket"

# === Update repo dulu ===
log_info "apt-get update"
apt-get update

# === Install paket ===
# Gunakan DEBIAN_FRONTEND=noninteractive agar tidak ada prompt
export DEBIAN_FRONTEND=noninteractive
log_info "apt-get install -y ${packages[*]}"
if ! apt-get install -y --no-install-recommends "${packages[@]}"; then
  log_error "Beberapa paket gagal di-install, cek log di atas"
  # Tidak exit 1: lanjut agar build bisa selesai, paket yang gagal di-skip
fi

# === Cleanup ===
log_info "apt-get clean"
apt-get clean

log_info "${HOOK_NAME} selesai"
exit 0
