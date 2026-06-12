#!/usr/bin/env bash
# =============================================================================
# rebuild-iso.sh — Repack ISO mixos dari filesystem yang sudah dimodifikasi
# =============================================================================
# Placeholder. Implementasi penuh pada Tahap 8.
# Strategi: xorriso -indev original.iso -outdev new.iso -map folder ... -boot_image ...
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="rebuild-iso.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"

readonly C_RESET=$'\033[0m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_BLUE=$'\033[34m'

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }

print_help() {
  cat <<'EOF'
rebuild-iso.sh — Repack ISO mixos (placeholder)

Usage:
  ./scripts/rebuild-iso.sh --source=DIR --output=PATH --volume-id=ID

Options:
  --source=DIR       Folder isi ISO (hasil unsquashfs + copy).
  --output=PATH      Path ISO output.
  --volume-id=ID     Volume ID (default: MIXOS).
  -h, --help         Tampilkan bantuan.

CATATAN:
  - Placeholder. Implementasi penuh di Tahap 8.
  - Butuh xorriso, isolinux, grub-efi untuk hybrid ISO.
EOF
}

main() {
  log_warn "rebuild-iso.sh masih placeholder. Implementasi penuh di Tahap 8."
  print_help
}

main "$@"
