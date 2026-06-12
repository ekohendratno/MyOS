#!/usr/bin/env bash
# =============================================================================
# test-vm.sh — Uji ISO mixos di QEMU/KVM
# =============================================================================
# Script ini menjalankan ISO mixos dalam QEMU VM untuk smoke test.
# JANGAN jalankan di Windows host langsung. Gunakan WSL atau Linux VM.
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="test-vm.sh"
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

# === Validasi QEMU ===
require_qemu() {
  if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    log_error "qemu-system-x86_64 tidak ditemukan"
    log_error "Install dengan: sudo apt install qemu-system-x86"
    return 1
  fi
}

# === Default args ===
ISO_FILE=""
RAM_MB=4096
CPU_CORES=2
DISK_GB=20
HEADLESS=false
USE_KVM=false
SNAPSHOT=true
TIMEOUT_SEC=0

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iso=*)           ISO_FILE="${1#*=}" ;;
      --ram=*)           RAM_MB="${1#*=}" ;;
      --cores=*)         CPU_CORES="${1#*=}" ;;
      --disk=*)          DISK_GB="${1#*=}" ;;
      --headless)        HEADLESS=true ;;
      --kvm)             USE_KVM=true ;;
      --no-snapshot)     SNAPSHOT=false ;;
      --timeout=*)       TIMEOUT_SEC="${1#*=}" ;;
      -h|--help)         print_help; exit 0 ;;
      *)                 log_error "Argumen tidak dikenal: $1"; print_help; exit 1 ;;
    esac
    shift
  done
}

print_help() {
  cat <<'EOF'
test-vm.sh — Uji ISO mixos di QEMU

Usage:
  ./test-vm.sh --iso=builds/mixos-0.1-amd64.iso [options]

Options:
  --iso=PATH         Path ke ISO (wajib).
  --ram=MB           RAM untuk VM (default: 4096).
  --cores=N          Jumlah core CPU (default: 2).
  --disk=GB          Ukuran disk VM (default: 20).
  --headless         Tidak buka display window.
  --kvm              Gunakan KVM akselerasi.
  --no-snapshot      Tulis perubahan ke disk (default: snapshot).
  --timeout=SEC      Auto-shutdown setelah N detik (0 = manual, default).
  -h, --help         Tampilkan bantuan.

Contoh:
  ./test-vm.sh --iso=builds/mixos-0.1-amd64.iso --kvm
  ./test-vm.sh --iso=builds/mixos-0.1-amd64.iso --headless --timeout=300

PERINGATAN:
  - Hanya jalankan di Linux host (atau WSL2 Linux).
  - ISO harus sudah ada. Build dulu dengan ./build.sh --no-dry-run.
EOF
}

# === Cari ISO otomatis ===
find_iso() {
  if [[ -n "${ISO_FILE}" ]]; then
    return 0
  fi
  log_info "Mencari ISO terbaru di ${PROJECT_ROOT}/${BUILD_DIR}/"
  local found
  found=$(find "${PROJECT_ROOT}/${BUILD_DIR}" -maxdepth 2 -name '*.iso' -type f -printf '%T@ %p\n' 2>/dev/null \
          | sort -rn | head -1 | cut -d' ' -f2-)
  if [[ -z "${found}" ]]; then
    log_error "ISO tidak ditemukan di ${PROJECT_ROOT}/${BUILD_DIR}/"
    log_error "Pastikan sudah menjalankan ./build.sh --no-dry-run terlebih dahulu"
    return 1
  fi
  ISO_FILE="${found}"
  log_info "Menggunakan ISO: ${ISO_FILE}"
}

# === Build QEMU command ===
build_qemu_cmd() {
  local cmd=(
    qemu-system-x86_64
    -m "${RAM_MB}"
    -smp "${CPU_CORES}"
    -cdrom "${ISO_FILE}"
    -boot d
    -vga virtio
    -netdev user,id=net0
    -device virtio-net,netdev=net0
    -usb
    -device usb-tablet
  )

  # Snapshot
  if [[ "${SNAPSHOT}" == "true" ]]; then
    cmd+=( -snapshot )
  fi

  # Disk
  cmd+=( -drive "file=mixos-test.qcow2,format=qcow2,if=virtio" )

  # Display
  if [[ "${HEADLESS}" == "true" ]]; then
    cmd+=( -display none -monitor stdio )
  else
    cmd+=( -display gtk )
  fi

  # KVM
  if [[ "${USE_KVM}" == "true" ]]; then
    if [[ -e /dev/kvm ]]; then
      cmd+=( -enable-kvm -cpu host )
    else
      log_warn "/dev/kvm tidak tersedia, fallback ke TCG"
    fi
  fi

  # Timeout (background watchdog)
  if [[ "${TIMEOUT_SEC}" -gt 0 ]]; then
    log_info "VM akan auto-shutdown setelah ${TIMEOUT_SEC} detik"
  fi

  printf '%s\n' "${cmd[@]}"
}

# === Main ===
main() {
  parse_args "$@"
  log_step "test-vm.sh — Uji ISO mixos di QEMU"

  require_qemu
  find_iso

  if [[ ! -f "${ISO_FILE}" ]]; then
    log_error "ISO file tidak ada: ${ISO_FILE}"
    exit 1
  fi

  log_info "ISO           : ${ISO_FILE}"
  log_info "RAM           : ${RAM_MB} MB"
  log_info "CPU cores     : ${CPU_CORES}"
  log_info "Disk          : ${DISK_GB} GB"
  log_info "Headless      : ${HEADLESS}"
  log_info "KVM           : ${USE_KVM}"
  log_info "Snapshot      : ${SNAPSHOT}"
  log_info "Timeout       : ${TIMEOUT_SEC} detik"

  log_info "Membuat disk image mixos-test.qcow2 (${DISK_GB}GB)"
  if [[ ! -f mixos-test.qcow2 ]]; then
    qemu-img create -f qcow2 mixos-test.qcow2 "${DISK_GB}G"
  fi

  log_info "Menjalankan QEMU"
  log_warn "Tekan Ctrl+C di window QEMU atau ketik 'quit' di monitor untuk keluar"

  local qemu_cmd
  qemu_cmd=$(build_qemu_cmd)
  # shellcheck disable=SC2086
  eval "${qemu_cmd}"
}

main "$@"
