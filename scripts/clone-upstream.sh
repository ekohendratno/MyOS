#!/usr/bin/env bash
# =============================================================================
# clone-upstream.sh — Clone elementary/os ke folder upstream
# =============================================================================
# Default: clone branch main.
# Jika BASE_DISTRO_VERSION adalah tag (mis. 8.1.1), checkout tag itu.
# Jika tag tidak ada, fallback ke branch main dengan peringatan.
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="clone-upstream.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

# shellcheck disable=SC1090
source "${CONFIG_FILE}" 2>/dev/null || {
  printf "[ERROR] Config tidak ditemukan: %s\n" "${CONFIG_FILE}" >&2
  exit 1
}

# === Colors ===
if [[ -t 1 ]]; then
  readonly C_RESET='\033[0m' C_BOLD='\033[1m' C_RED='\033[31m' C_GREEN='\033[32m' C_YELLOW='\033[33m' C_BLUE='\033[34m'
else
  readonly C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_step()  { printf "%b==>%b %s\n"            "${C_GREEN}" "${C_RESET}" "$*"; }

# === Validasi git ===
require_git() {
  if ! command -v git >/dev/null 2>&1; then
    log_error "git tidak ditemukan. Install: sudo apt install git"
    exit 1
  fi
}

# === Cek apakah remote & tag ada ===
check_remote_and_tags() {
  log_info "Mengecek remote dan tag di ${BASE_DISTRO_URL}"
  if ! git ls-remote --heads --tags "${BASE_DISTRO_URL}" >/dev/null 2>&1; then
    log_error "Tidak bisa menghubungi ${BASE_DISTRO_URL}"
    log_error "Periksa koneksi internet dan URL repository"
    exit 1
  fi
  log_info "Remote OK"
}

# === Pilih ref untuk di-checkout ===
# Logika:
# 1. Jika BASE_DISTRO_VERSION cocok dengan tag (mis. 8.1.1), pakai tag.
# 2. Jika tidak, coba branch dengan nama yang mengandung BASE_DISTRO_VERSION
#    (mis. branch "stable-8.1" atau "release-8.1").
# 3. Fallback ke branch main.
pick_ref() {
  local version="${BASE_DISTRO_VERSION}"
  log_info "Mencari tag yang cocok dengan versi: ${version}"

  # Ambil daftar tag
  local tags
  tags=$(git ls-remote --tags --refs "${BASE_DISTRO_URL}" \
         | awk '{print $2}' \
         | sed 's|refs/tags/||' \
         | sort -Vr)

  if [[ -z "${tags}" ]]; then
    log_warn "Repository tidak punya tag publik"
  else
    log_info "Tag tersedia:"
    while IFS= read -r tag; do
      log_info "  - ${tag}"
    done <<< "${tags}"
  fi

  # Cek exact match
  if printf '%s\n' "${tags}" | grep -qx "${version}"; then
    log_info "Tag cocok ditemukan: ${version}"
    PICKED_REF="refs/tags/${version}"
    PICKED_TYPE="tag"
    return 0
  fi

  # Cek prefix match (mis. 8.1 -> 8.1.0, 8.1.1, ...)
  local prefix_match
  prefix_match=$(printf '%s\n' "${tags}" | grep -E "^${version//./\\.}\." | head -1 || true)
  if [[ -n "${prefix_match}" ]]; then
    log_warn "Versi ${version} bukan tag, pakai tag tertinggi yang prefix-nya cocok: ${prefix_match}"
    PICKED_REF="refs/tags/${prefix_match}"
    PICKED_TYPE="tag"
    return 0
  fi

  # Cek branch
  log_warn "Tag ${version} tidak ada, cari branch..."
  local branches
  branches=$(git ls-remote --heads "${BASE_DISTRO_URL}" | awk '{print $2}' | sed 's|refs/heads/||')
  local branch_match
  branch_match=$(printf '%s\n' "${branches}" | grep -E "(${version}|stable|release)" | head -1 || true)

  if [[ -n "${branch_match}" ]]; then
    log_info "Branch cocok: ${branch_match}"
    PICKED_REF="refs/heads/${branch_match}"
    PICKED_TYPE="branch"
    return 0
  fi

  # Fallback ke main
  log_warn "Tidak ada tag/branch yang cocok, fallback ke branch main"
  PICKED_REF="refs/heads/main"
  PICKED_TYPE="branch"
}

# === Clone ===
do_clone() {
  local target="${PROJECT_ROOT}/${UPSTREAM_DIR}/elementary-os"
  if [[ -d "${target}/.git" ]]; then
    log_warn "Upstream sudah ada: ${target}"
    log_info "Untuk re-clone, hapus dulu dengan: rm -rf ${target}"
    return 0
  fi

  log_step "Cloning ${BASE_DISTRO_URL} -> ${target}"
  if ! git clone "${BASE_DISTRO_URL}" "${target}"; then
    log_error "Clone gagal"
    exit 1
  fi

  log_step "Checkout ke ${PICKED_REF}"
  git -C "${target}" checkout "${PICKED_REF}"

  log_info "Clone selesai. HEAD: $(git -C "${target}" log -1 --oneline)"
}

# === Main ===
main() {
  log_step "clone-upstream.sh — Clone elementary/os"
  require_git
  check_remote_and_tags
  pick_ref
  do_clone

  log_info "Picked ref : ${PICKED_REF} (${PICKED_TYPE})"
  log_info "Selesai"
}

main "$@"
