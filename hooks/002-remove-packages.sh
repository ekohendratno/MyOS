#!/usr/bin/env bash
# =============================================================================
# 002-remove-packages.sh — Hapus paket yang tidak diinginkan
# =============================================================================
# Membaca config/remove-packages.list dan remove paket.
# HATI-HATI: paket elementary adalah dependency sistem, jangan remove sembarangan.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="002-remove-packages"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"
readonly REMOVE_LIST="${PROJECT_ROOT}/config/remove-packages.list"

# shellcheck disable=SC1090
source "${CONFIG_FILE}" 2>/dev/null || {
  log_error "Config tidak ditemukan: ${CONFIG_FILE}"
  exit 1
}

log_info "=== ${HOOK_NAME} ==="
log_warn "PERHATIAN: Hapus paket bisa break sistem. Default: skip."

# === Default behavior: JANGAN remove paket (lihat config/remove-packages.list) ===
# Override dengan set ENABLE_PURGE_UPSTREAM="true" di mixos.conf
ENABLE_PURGE_UPSTREAM="${ENABLE_PURGE_UPSTREAM:-false}"

if [[ "${ENABLE_PURGE_UPSTREAM}" != "true" ]]; then
  log_info "ENABLE_PURGE_UPSTREAM=false, skip remove paket"
  log_info "Untuk enable, set ENABLE_PURGE_UPSTREAM=true di config/mixos.conf"
  exit 0
fi

if [[ ! -f "${REMOVE_LIST}" ]]; then
  log_error "Remove list tidak ada: ${REMOVE_LIST}"
  exit 1
fi

# === Filter paket (skip komentar) ===
mapfile -t packages < <(grep -vE '^\s*(#|$)' "${REMOVE_LIST}" || true)

if [[ ${#packages[@]} -eq 0 ]]; then
  log_warn "Tidak ada paket untuk di-remove"
  exit 0
fi

log_info "Akan remove ${#packages[@]} paket"

export DEBIAN_FRONTEND=noninteractive

# === Cek paket yang benar-benar terinstall ===
to_remove=()
for pkg in "${packages[@]}"; do
  if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"; then
    to_remove+=("${pkg}")
  else
    log_warn "Skip, tidak terinstall: ${pkg}"
  fi
done

if [[ ${#to_remove[@]} -eq 0 ]]; then
  log_info "Tidak ada paket yang perlu di-remove"
  exit 0
fi

log_info "Removing: ${to_remove[*]}"
apt-get remove -y --purge "${to_remove[@]}" || {
  log_error "apt-get remove gagal"
  exit 1
}

apt-get autoremove -y
apt-get clean

log_info "${HOOK_NAME} selesai"
exit 0
