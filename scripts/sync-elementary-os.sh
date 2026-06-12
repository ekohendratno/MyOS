#!/usr/bin/env bash
# =============================================================================
# sync-elementary-os.sh — Sync upstream elementary/os ke local
# =============================================================================
# Pull perubahan terbaru dari upstream. Default: git fetch + git pull
# di folder upstream/elementary-os.
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="sync-elementary-os.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"

readonly C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_BLUE=$'\033[34m'

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_step()  { printf "%b==>%b %s\n"            "${C_GREEN}" "${C_RESET}" "$*"; }

REPO="${PROJECT_ROOT}/upstream/elementary-os"
REMOTE="origin"
BRANCH=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --remote=*)       REMOTE="${1#*=}" ;;
      --branch=*)       BRANCH="${1#*=}" ;;
      -h|--help)        print_help; exit 0 ;;
      *)                log_error "Argumen tidak dikenal: $1"; exit 1 ;;
    esac
    shift
  done
}

print_help() {
  cat <<'EOF'
sync-elementary-os.sh — Sync upstream elementary/os

Usage:
  ./scripts/sync-elementary-os.sh [options]

Options:
  --remote=NAME   Nama remote (default: origin).
  --branch=NAME   Branch spesifik (default: current).
  -h, --help      Tampilkan bantuan.
EOF
}

main() {
  parse_args "$@"
  log_step "sync-elementary-os.sh"

  if [[ ! -d "${REPO}/.git" ]]; then
    log_error "Upstream belum di-clone. Jalankan: ./scripts/clone-upstream.sh"
    exit 1
  fi

  log_info "Repo    : ${REPO}"
  log_info "Remote  : ${REMOTE}"

  if [[ -n "${BRANCH}" ]]; then
    log_info "Branch  : ${BRANCH}"
    git -C "${REPO}" checkout "${BRANCH}"
  else
    local current
    current=$(git -C "${REPO}" rev-parse --abbrev-ref HEAD)
    log_info "Current branch: ${current}"
  fi

  log_info "Fetching ${REMOTE}..."
  git -C "${REPO}" fetch "${REMOTE}"

  log_info "Status saat ini:"
  git -C "${REPO}" status --short

  log_info "Pulling..."
  git -C "${REPO}" pull --ff-only "${REMOTE}" HEAD || {
    log_warn "Pull gagal, mungkin ada local changes. Cek dengan: cd ${REPO} && git status"
  }

  log_info "Sync selesai"
  log_info "HEAD: $(git -C "${REPO}" log -1 --oneline)"
}

main "$@"
