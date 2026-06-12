#!/usr/bin/env bash
# =============================================================================
# verify-iso.sh — Verifikasi ISO mixos setelah build
# =============================================================================
# Cek:
# - File ada dan tidak corrupt
# - Hybrid boot record valid
# - Ukuran masuk akal
# - ISO bisa di-mount (cek struktur casper/filesystem.squashfs)
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="verify-iso.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"

readonly C_RESET=$'\033[0m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_BLUE=$'\033[34m' C_BOLD=$'\033[1m'

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
ok()       { printf "  %b✓%b %s\n"            "${C_GREEN}" "${C_RESET}" "$*"; }
fail()     { printf "  %b✗%b %s\n"            "${C_RED}"   "${C_RESET}" "$*"; }
warn()     { printf "  %b!%b %s\n"            "${C_YELLOW}" "${C_RESET}" "$*"; }

ISO_FILE=""

print_help() {
  cat <<'EOF'
verify-iso.sh — Verifikasi ISO mixos

Usage:
  ./scripts/verify-iso.sh --iso=PATH

Options:
  --iso=PATH    Path ke ISO (wajib).
  -h, --help    Tampilkan bantuan.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iso=*)        ISO_FILE="${1#*=}" ;;
      -h|--help)      print_help; exit 0 ;;
      *)              log_error "Argumen tidak dikenal: $1"; print_help; exit 1 ;;
    esac
    shift
  done
}

check_file() {
  log_step "Cek file ISO"
  if [[ -z "${ISO_FILE}" ]]; then
    log_error "ISO_FILE kosong. Gunakan --iso=PATH"
    exit 1
  fi
  if [[ ! -f "${ISO_FILE}" ]]; then
    log_error "File tidak ada: ${ISO_FILE}"
    exit 1
  fi
  ok "File ada: ${ISO_FILE}"

  local size_bytes
  size_bytes=$(stat -c '%s' "${ISO_FILE}" 2>/dev/null || stat -f '%z' "${ISO_FILE}")
  local size_mb=$((size_bytes / 1024 / 1024))
  log_info "Ukuran: ${size_mb} MB"
  if [[ "${size_mb}" -lt 500 ]]; then
    warn "Ukuran terlalu kecil, kemungkinan ISO corrupt"
  elif [[ "${size_mb}" -gt 4000 ]]; then
    warn "Ukuran terlalu besar (>4GB), tidak bisa di-burn ke DVD"
  else
    ok "Ukuran OK"
  fi
}

check_magic() {
  log_step "Cek magic bytes"
  local magic
  magic=$(head -c 6 "${ISO_FILE}" | xxd -p 2>/dev/null || true)
  # ISO 9660: offset 0x8001-0x8005 berisi "CD001"
  local cd001
  cd001=$(dd if="${ISO_FILE}" bs=1 skip=32769 count=5 2>/dev/null | tr -d '\0' || true)
  if [[ "${cd001}" == "CD001" ]]; then
    ok "ISO 9660 magic OK (CD001)"
  else
    fail "ISO 9660 magic tidak ditemukan, bukan ISO yang valid"
    return 1
  fi
}

check_isohybrid() {
  log_step "Cek hybrid boot (BIOS + UEFI)"
  # isohybrid signature ada di akhir ISO
  if command -v isohybrid >/dev/null 2>&1; then
    if isohybrid --info "${ISO_FILE}" 2>/dev/null; then
      ok "isohybrid signature valid"
    else
      warn "isohybrid signature tidak terdeteksi (mungkin ISO bukan hybrid)"
    fi
  else
    warn "isohybrid command tidak ada, skip cek"
  fi
}

check_structure() {
  log_step "Cek struktur ISO (menggunakan isoinfo)"
  if ! command -v isoinfo >/dev/null 2>&1; then
    warn "isoinfo command tidak ada, skip cek struktur"
    return 0
  fi

  local files_to_check=(
    "casper/filesystem.squashfs"
    "casper/initrd"
    "casper/vmlinuz"
    ".disk/info"
  )

  for f in "${files_to_check[@]}"; do
    if isoinfo -i "${ISO_FILE}" -l 2>/dev/null | grep -q "$(basename "${f}")"; then
      ok "Ada: ${f}"
    else
      fail "Tidak ada: ${f}"
    fi
  done
}

main() {
  parse_args "$@"
  log_step "verify-iso.sh — mixos ISO verification"

  check_file
  check_magic
  check_isohybrid
  check_structure

  log_step "Verifikasi selesai"
  log_info "Lanjut: ./scripts/make-checksum.sh --iso=${ISO_FILE}"
}

main "$@"
