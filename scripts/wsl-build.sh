#!/usr/bin/env bash
# =============================================================================
# wsl-build.sh — Build ISO mixos dari dalam WSL2
# =============================================================================
# Script ini dijalankan DI DALAM WSL2 Debian/Ubuntu.
# Mengotomatiskan: clone upstream -> build ISO -> verify -> copy ke Windows.
#
# Usage:
#   chmod +x scripts/wsl-build.sh
#   ./scripts/wsl-build.sh
#
# Options:
#   --skip-upstream   Jangan clone ulang upstream
#   --skip-build      Jangan jalankan build (hanya prepare)
#   --skip-verify     Jangan verifikasi ISO
#   --output=PATH     Output ISO ke path Windows (contoh: /mnt/c/Users/ekohe/Desktop/)
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="wsl-build.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"

# === Colors ===
if [[ -t 1 ]]; then
  readonly C_RESET='\033[0m' C_BOLD='\033[1m' C_GREEN='\033[32m' C_YELLOW='\033[33m' C_RED='\033[31m' C_CYAN='\033[36m'
else
  readonly C_RESET='' C_BOLD='' C_GREEN='' C_YELLOW='' C_RED='' C_CYAN=''
fi

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_CYAN}"  "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_step()  { printf "\n%b=== %s ===%b\n"       "${C_GREEN}" "$*" "${C_RESET}"; }

# === Arg defaults ===
SKIP_UPSTREAM=false
SKIP_BUILD=false
SKIP_VERIFY=false
OUTPUT_PATH=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-upstream)  SKIP_UPSTREAM=true ;;
      --skip-build)     SKIP_BUILD=true ;;
      --skip-verify)    SKIP_VERIFY=true ;;
      --output=*)       OUTPUT_PATH="${1#*=}" ;;
      -h|--help)        print_help; exit 0 ;;
      *)                log_error "Argumen tidak dikenal: $1"; print_help; exit 1 ;;
    esac
    shift
  done
}

print_help() {
  cat <<'EOF'
wsl-build.sh — Build ISO mixos dari dalam WSL2

Usage:
  ./scripts/wsl-build.sh [options]

Options:
  --skip-upstream   Jangan clone ulang upstream
  --skip-build      Jangan jalankan build (hanya prepare)
  --skip-verify     Jangan verifikasi ISO setelah build
  --output=PATH     Copy ISO ke path Windows (contoh: /mnt/c/Users/ekohe/Desktop/)
  -h, --help        Tampilkan bantuan

Environment:
  WSL harus sudah terinstall dengan Debian distro.
  Pastikan sudah menjalankan:
    sudo apt install debootstrap live-build xorriso isolinux
EOF
}

# === Cek environment ===
check_env() {
  log_step "Cek Environment"

  # Deteksi WSL
  if ! grep -qi microsoft /proc/version 2>/dev/null; then
    log_warn "Sepertinya bukan WSL. Script ini untuk WSL2."
  fi

  # Cek tools
  local required=(bash debootstrap lb xorriso git)
  for cmd in "${required[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      log_error "Missing: ${cmd}. Jalankan: sudo apt install debootstrap live-build xorriso git"
      exit 1
    fi
  done

  log_info "Tools OK"

  # Cek disk
  local free_kb free_gb
  free_kb=$(df -k "${PROJECT_ROOT}" | tail -1 | awk '{print $4}')
  free_gb=$((free_kb / 1024 / 1024))
  log_info "Disk free: ${free_gb} GB"
  if [[ "${free_gb}" -lt 50 ]]; then
    log_warn "Disk hanya ${free_gb} GB. Build mungkin gagal."
    log_warn "Bersihkan dulu: docker system prune, apt clean, rm -rf builds/"
  fi
}

# === Clone upstream ===
clone_upstream() {
  if [[ "${SKIP_UPSTREAM}" == "true" ]]; then
    log_info "Skip clone upstream"
    return 0
  fi

  log_step "Clone upstream elementary/os"
  if [[ -d "${PROJECT_ROOT}/upstream/elementary-os/.git" ]]; then
    log_info "Upstream sudah ada, update..."
    git -C "${PROJECT_ROOT}/upstream/elementary-os" fetch origin
  else
    "${PROJECT_ROOT}/scripts/clone-upstream.sh"
  fi
}

# === Build ISO ===
run_build() {
  if [[ "${SKIP_BUILD}" == "true" ]]; then
    log_info "Skip build"
    return 0
  fi

  log_step "Build ISO mixos"
  log_warn "Build akan memakan waktu 2-6 jam. Pastikan laptop tercharger."
  log_warn "Tekan Ctrl+C untuk cancel kapan saja (build aman, bisa di-ulang)."
  echo ""

  cd "${PROJECT_ROOT}"
  ./build.sh --no-dry-run
}

# === Verify ISO ===
verify_iso() {
  if [[ "${SKIP_VERIFY}" == "true" ]]; then
    log_info "Skip verify"
    return 0
  fi

  log_step "Verify ISO"
  local iso
  iso=$(find "${PROJECT_ROOT}/builds" -name '*.iso' -type f | sort -r | head -1)

  if [[ -z "${iso}" ]]; then
    log_error "ISO tidak ditemukan di builds/"
    return 1
  fi

  log_info "Found: ${iso}"
  ls -lh "${iso}"

  if [[ -x "${PROJECT_ROOT}/scripts/verify-iso.sh" ]]; then
    "${PROJECT_ROOT}/scripts/verify-iso.sh" --iso="${iso}" || log_warn "Verify warnings"
  fi

  if [[ -x "${PROJECT_ROOT}/scripts/make-checksum.sh" ]]; then
    "${PROJECT_ROOT}/scripts/make-checksum.sh" --iso="${iso}"
  fi
}

# === Copy ISO ke Windows ===
copy_to_windows() {
  if [[ -z "${OUTPUT_PATH}" ]]; then
    log_info "No --output specified, skip copy to Windows"
    log_info "ISO ada di: ${PROJECT_ROOT}/builds/"
    return 0
  fi

  log_step "Copy ISO ke Windows"

  if [[ ! -d "${OUTPUT_PATH}" ]]; then
    log_error "Path tidak ada: ${OUTPUT_PATH}"
    return 1
  fi

  local iso
  iso=$(find "${PROJECT_ROOT}/builds" -name '*.iso' -type f | sort -r | head -1)

  if [[ -z "${iso}" ]]; then
    log_error "ISO tidak ditemukan"
    return 1
  fi

  local dest="${OUTPUT_PATH}/$(basename "${iso}")"
  log_info "Copy: ${iso} -> ${dest}"
  cp "${iso}" "${dest}"
  log_info "Done: ${dest}"

  # Juga copy checksum
  local sums
  sums=$(find "${PROJECT_ROOT}/builds" -name 'SHA256SUMS' -type f | head -1)
  if [[ -n "${sums}" ]]; then
    cp "${sums}" "${OUTPUT_PATH}/"
  fi
}

# === Main ===
main() {
  parse_args "$@"
  log_step "wsl-build.sh — mixos ISO Builder for WSL2"

  check_env
  clone_upstream
  run_build
  verify_iso
  copy_to_windows

  log_step "Selesai"
  log_info "ISO mixos siap di: ${PROJECT_ROOT}/builds/"
  log_info "Atau di: ${OUTPUT_PATH:-"belum di-copy ke Windows"}"
}

main "$@"
