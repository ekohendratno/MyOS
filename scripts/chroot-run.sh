#!/usr/bin/env bash
# =============================================================================
# chroot-run.sh — Wrapper untuk chroot ke filesystem mixos
# =============================================================================
# Placeholder. Implementasi penuh pada Tahap 8.
# Strategi:
#   1. Bind-mount /dev, /proc, /sys, /tmp ke chroot
#   2. Copy resolv.conf untuk network
#   3. chroot ke folder
#   4. Cleanup mounts saat exit
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="chroot-run.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"

readonly C_RESET=$'\033[0m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_BLUE=$'\033[34m'

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }

print_help() {
  cat <<'EOF'
chroot-run.sh — Chroot ke filesystem mixos (placeholder)

Usage:
  ./scripts/chroot-run.sh --chroot=PATH --command="..."

Options:
  --chroot=PATH      Path ke chroot (wajib).
  --command=CMD      Command yang dijalankan di chroot.
  -h, --help         Tampilkan bantuan.

CATATAN:
  - Placeholder. Implementasi penuh di Tahap 8.
  - Hanya untuk dijalankan di Linux.
  - JANGAN jalankan chroot ke filesystem host.
EOF
}

main() {
  log_warn "chroot-run.sh masih placeholder. Implementasi penuh di Tahap 8."
  print_help
}

main "$@"
