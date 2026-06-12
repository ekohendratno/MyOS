#!/usr/bin/env bash
# =============================================================================
# make-checksum.sh — Generate SHA256 checksum untuk ISO mixos
# =============================================================================
# Output: file .SHA256SUMS di folder yang sama dengan ISO.
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="make-checksum.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"

readonly C_RESET=$'\033[0m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_BLUE=$'\033[34m' C_BOLD=$'\033[1m'

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }

ALGO="sha256"
SIGN=false
GPG_KEY=""

print_help() {
  cat <<'EOF'
make-checksum.sh — Generate checksum ISO

Usage:
  ./scripts/make-checksum.sh --iso=PATH [options]

Options:
  --iso=PATH         Path ke ISO (wajib).
  --algo=ALGO        Algoritma: sha256 (default), sha512, blake2b.
  --sign             Tanda tangani SHA256SUMS dengan GPG.
  --gpg-key=KEYID    GPG key ID untuk signing.
  -h, --help         Tampilkan bantuan.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iso=*)         ISO_FILE="${1#*=}" ;;
      --algo=*)        ALGO="${1#*=}" ;;
      --sign)          SIGN=true ;;
      --gpg-key=*)     GPG_KEY="${1#*=}" ;;
      -h|--help)       print_help; exit 0 ;;
      *)               log_error "Argumen tidak dikenal: $1"; print_help; exit 1 ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"

  if [[ -z "${ISO_FILE:-}" ]]; then
    log_error "ISO_FILE kosong. Gunakan --iso=PATH"
    exit 1
  fi

  if [[ ! -f "${ISO_FILE}" ]]; then
    log_error "File tidak ada: ${ISO_FILE}"
    exit 1
  fi

  local iso_dir
  iso_dir="$(cd "$(dirname "${ISO_FILE}")" && pwd)"
  local iso_name
  iso_name="$(basename "${ISO_FILE}")"
  local sums_file="${iso_dir}/SHA256SUMS"

  log_step "Generate ${ALGO} checksum"
  log_info "ISO    : ${iso_name}"
  log_info "Folder: ${iso_dir}"

  case "${ALGO}" in
    sha256)  sha256sum "${ISO_FILE}" ;;
    sha512)  sha512sum "${ISO_FILE}" ;;
    blake2b) b2sum "${ISO_FILE}" ;;
    *)       log_error "Algo tidak dikenal: ${ALGO}"; exit 1 ;;
  esac > "${sums_file}"

  log_info "Checksum ditulis: ${sums_file}"
  cat "${sums_file}"

  if [[ "${SIGN}" == "true" ]]; then
    if ! command -v gpg >/dev/null 2>&1; then
      log_error "gpg tidak ditemukan"
      exit 1
    fi

    log_step "Sign SHA256SUMS"
    local gpg_args=(--armor --detach-sign)
    if [[ -n "${GPG_KEY}" ]]; then
      gpg_args+=(--local-user "${GPG_KEY}")
    fi

    cd "${iso_dir}"
    gpg "${gpg_args[@]}" --output "${sums_file}.asc" "${sums_file}"
    log_info "Signature ditulis: ${sums_file}.asc"
  fi

  log_info "Selesai"
}

main "$@"
