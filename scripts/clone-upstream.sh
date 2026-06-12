#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="clone-upstream.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

source "${CONFIG_FILE}" 2>/dev/null || { printf "[ERROR] Config tidak ditemukan\n" >&2; exit 1; }

if [[ -t 1 ]]; then
  readonly C_RESET='\033[0m' C_BOLD='\033[1m' C_RED='\033[31m' C_GREEN='\033[32m' C_YELLOW='\033[33m' C_BLUE='\033[34m'
else
  readonly C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_step()  { printf "%b==>%b %s\n"            "${C_GREEN}" "${C_RESET}" "$*"; }

require_git() {
  command -v git >/dev/null 2>&1 || { log_error "git tidak ditemukan"; exit 1; }
}

main() {
  log_step "clone-upstream.sh — Clone LingmoOS live-build-config"
  require_git

  local target="${PROJECT_ROOT}/${UPSTREAM_DIR}/live-build-config"
  if [[ -d "${target}/.git" ]]; then
    log_info "Upstream sudah ada: ${target}"; return 0
  fi

  local url="https://github.com/LingmoOS/live-build-config"
  log_info "Cloning ${url} (tag 2.1-debian12-final) -> ${target}"
  git clone --depth 1 --branch "2.1-debian12-final" "${url}" "${target}"
  log_info "Selesai. HEAD: $(git -C "${target}" log -1 --oneline)"
}

main "$@"
