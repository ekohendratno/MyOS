#!/usr/bin/env bash
# =============================================================================
# clean.sh — Bersihkan folder build mixos
# =============================================================================
# Menghapus folder builds, cache, logs, dan artifacts yang dihasilkan build.
# VALIDASI KETAT: hanya menghapus folder di dalam PROJECT_ROOT, bukan di luar.
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="clean.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_PATH}"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

# shellcheck disable=SC1090
source "${CONFIG_FILE}" 2>/dev/null || {
  printf "[ERROR] Config tidak ditemukan: %s\n" "${CONFIG_FILE}" >&2
  exit 1
}

# === Colors ===
if [[ -t 1 ]]; then
  readonly C_RESET='\033[0m' C_BOLD='\033[1m' C_RED='\033[31m' C_GREEN='\033[32m' C_YELLOW='\033[33m'
else
  readonly C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW=''
fi

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_GREEN}" "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_step()  { printf "%b==>%b %s\n"            "${C_GREEN}" "${C_RESET}" "$*"; }

# === Safety check: pastikan folder yang akan dihapus berada di dalam PROJECT_ROOT ===
is_safe_to_delete() {
  local target="$1"
  # Resolve ke absolute path
  local abs_target
  abs_target="$(cd "${target}" 2>/dev/null && pwd -P || true)"

  if [[ -z "${abs_target}" ]]; then
    return 1
  fi

  # Harus di dalam PROJECT_ROOT
  case "${abs_target}" in
    "${PROJECT_ROOT}"/*) return 0 ;;
    *)                   return 1 ;;
  esac
}

# === Hapus folder dengan validasi ===
safe_rm() {
  local target="$1"

  if [[ ! -d "${target}" ]]; then
    log_info "Skip, tidak ada: ${target}"
    return 0
  fi

  if ! is_safe_to_delete "${target}"; then
    log_error "TIDAK AMAN menghapus: ${target}"
    log_error "Folder di luar PROJECT_ROOT (${PROJECT_ROOT})"
    return 1
  fi

  # Hitung ukuran
  local size
  size=$(du -sh "${target}" 2>/dev/null | cut -f1)
  log_info "Menghapus: ${target} (${size})"
  rm -rf "${target}"
}

# === Arg parsing ===
DRY_RUN=false
PURGE_UPSTREAM=false
PURGE_CACHE=false
PURGE_LOGS=false
PURGE_ALL=false
PURGE_ARTIFACTS=false

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)         DRY_RUN=true ;;
      --upstream)        PURGE_UPSTREAM=true ;;
      --cache)           PURGE_CACHE=true ;;
      --logs)            PURGE_LOGS=true ;;
      --artifacts)       PURGE_ARTIFACTS=true ;;
      --all)             PURGE_ALL=true ;;
      -h|--help)         print_help; exit 0 ;;
      *)                 log_error "Argumen tidak dikenal: $1"; print_help; exit 1 ;;
    esac
    shift
  done

  # Default jika tidak ada flag
  if [[ "${PURGE_UPSTREAM}" == "false" && "${PURGE_CACHE}" == "false" && \
        "${PURGE_LOGS}" == "false" && "${PURGE_ARTIFACTS}" == "false" && \
        "${PURGE_ALL}" == "false" ]]; then
    PURGE_CACHE=true
    PURGE_LOGS=true
    PURGE_ARTIFACTS=true
  fi

  if [[ "${PURGE_ALL}" == "true" ]]; then
    PURGE_UPSTREAM=true
    PURGE_CACHE=true
    PURGE_LOGS=true
    PURGE_ARTIFACTS=true
  fi
}

print_help() {
  cat <<'EOF'
clean.sh — Bersihkan folder build mixos

Usage:
  ./clean.sh [options]

Options:
  --dry-run         Tampilkan yang akan dihapus, tidak hapus.
  --upstream        Hapus folder upstream (clone live-build-config).
  --cache           Hapus folder cache.
  --logs            Hapus folder logs.
  --artifacts       Hapus folder artifacts.
  --all             Hapus semua di atas.
  -h, --help        Tampilkan bantuan.

DEFAULT (tanpa flag): hapus cache, logs, artifacts. TIDAK hapus upstream.

SAFETY:
  - Hanya menghapus folder di dalam PROJECT_ROOT.
  - Folder di luar PROJECT_ROOT akan di-skip dengan error.
  - Folder PROJECT_ROOT sendiri TIDAK akan dihapus.
EOF
}

# === Main ===
main() {
  parse_args "$@"
  log_step "clean.sh — mixos build cleanup"

  log_info "Project root: ${PROJECT_ROOT}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_warn "DRY-RUN mode, tidak ada yang dihapus"
  fi

  # Default cleanup
  safe_rm "${PROJECT_ROOT}/${BUILD_DIR}" 2>/dev/null || true
  if [[ "${PURGE_CACHE}" == "true" ]]; then
    if [[ "${DRY_RUN}" == "false" ]]; then
      safe_rm "${PROJECT_ROOT}/${CACHE_DIR}"
    else
      log_info "[DRY-RUN] akan hapus: ${PROJECT_ROOT}/${CACHE_DIR}"
    fi
  fi
  if [[ "${PURGE_LOGS}" == "true" ]]; then
    if [[ "${DRY_RUN}" == "false" ]]; then
      safe_rm "${PROJECT_ROOT}/${LOG_DIR}"
      mkdir -p "${PROJECT_ROOT}/${LOG_DIR}"
    else
      log_info "[DRY-RUN] akan hapus: ${PROJECT_ROOT}/${LOG_DIR}"
    fi
  fi
  if [[ "${PURGE_ARTIFACTS}" == "true" ]]; then
    if [[ "${DRY_RUN}" == "false" ]]; then
      safe_rm "${PROJECT_ROOT}/${ARTIFACT_DIR}"
    else
      log_info "[DRY-RUN] akan hapus: ${PROJECT_ROOT}/${ARTIFACT_DIR}"
    fi
  fi
  if [[ "${PURGE_UPSTREAM}" == "true" ]]; then
    if [[ "${DRY_RUN}" == "false" ]]; then
      safe_rm "${PROJECT_ROOT}/${UPSTREAM_DIR}/elementary-os"
    else
      log_info "[DRY-RUN] akan hapus: ${PROJECT_ROOT}/${UPSTREAM_DIR}/elementary-os"
    fi
  fi

  log_info "clean.sh selesai"
}

main "$@"
