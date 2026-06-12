#!/usr/bin/env bash
# =============================================================================
# apply-patches.sh — Apply patch mixos ke source upstream
# =============================================================================
# Menerapkan patch dari folder patches/ ke source upstream yang sudah di-clone.
# Mendukung format: unified diff (.patch), git diff, atau diff -ru.
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="apply-patches.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"
readonly PATCHES_DIR="${PROJECT_ROOT}/patches"
readonly UPSTREAM_DIR="${PROJECT_ROOT}/upstream"

readonly C_RESET=$'\033[0m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_BLUE=$'\033[34m'

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }

REVERSE=false
DRY_RUN=false
COMPONENT=""

print_help() {
  cat <<'EOF'
apply-patches.sh — Apply patch mixos

Usage:
  ./scripts/apply-patches.sh [options]

Options:
  --component=NAME   Patch untuk komponen tertentu (gala, wingpanel, files, dll).
                     Default: semua.
  --reverse          Apply reverse (un-apply).
  --dry-run          Tampilkan yang akan dilakukan, tidak apply.
  -h, --help         Tampilkan bantuan.

Contoh:
  ./scripts/apply-patches.sh --component=gala
  ./scripts/apply-patches.sh --reverse --component=gala
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --component=*)    COMPONENT="${1#*=}" ;;
      --reverse)        REVERSE=true ;;
      --dry-run)        DRY_RUN=true ;;
      -h|--help)        print_help; exit 0 ;;
      *)                log_error "Argumen tidak dikenal: $1"; print_help; exit 1 ;;
    esac
    shift
  done
}

# === Apply satu patch ===
apply_patch() {
  local patch_file="$1"
  local target_dir="$2"

  if [[ ! -f "${patch_file}" ]]; then
    log_warn "Patch tidak ada: ${patch_file}"
    return 0
  fi

  log_info "Patch: ${patch_file}"
  log_info "Target: ${target_dir}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Akan apply: ${patch_file}"
    return 0
  fi

  if [[ "${REVERSE}" == "true" ]]; then
    log_info "Applying reverse..."
    if ! patch -d "${target_dir}" -R -p1 < "${patch_file}"; then
      log_error "Reverse patch gagal: ${patch_file}"
      return 1
    fi
  else
    log_info "Applying forward..."
    if ! patch -d "${target_dir}" -p1 < "${patch_file}"; then
      log_error "Apply patch gagal: ${patch_file}"
      return 1
    fi
  fi

  log_info "OK"
}

# === Main ===
main() {
  parse_args "$@"

  log_info "Patch dir: ${PATCHES_DIR}"
  log_info "Upstream : ${UPSTREAM_DIR}"

  if [[ ! -d "${PATCHES_DIR}" ]]; then
    log_error "Folder patches tidak ada: ${PATCHES_DIR}"
    exit 1
  fi

  # Kumpulkan komponen yang akan di-patch
  local components=()
  if [[ -n "${COMPONENT}" ]]; then
    components=("${COMPONENT}")
  else
    while IFS= read -r d; do
      components+=("$(basename "${d}")")
    done < <(find "${PATCHES_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)
  fi

  if [[ ${#components[@]} -eq 0 ]]; then
    log_warn "Tidak ada patch ditemukan"
    exit 0
  fi

  for comp in "${components[@]}"; do
    log_step "Component: ${comp}"

    local patch_dir="${PATCHES_DIR}/${comp}"
    local target_dir="${UPSTREAM_DIR}/${comp}"

    if [[ ! -d "${patch_dir}" ]]; then
      log_warn "Skip: ${patch_dir} bukan folder"
      continue
    fi

    # Cari semua .patch
    local patches=()
    while IFS= read -r p; do
      patches+=("${p}")
    done < <(find "${patch_dir}" -type f \( -name '*.patch' -o -name '*.diff' \) | sort)

    if [[ ${#patches[@]} -eq 0 ]]; then
      log_info "Tidak ada patch di ${patch_dir}"
      continue
    fi

    for p in "${patches[@]}"; do
      apply_patch "${p}" "${target_dir}"
    done
  done

  log_info "Selesai"
}

main "$@"
