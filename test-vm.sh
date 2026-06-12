#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="test-vm.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_PATH}"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"
source "${CONFIG_FILE}" 2>/dev/null || { printf "[ERROR] Config tidak ditemukan\n" >&2; exit 1; }

readonly VMS_DIR="${PROJECT_ROOT}/builds/vms"

if [[ -t 1 ]]; then
  readonly C_RESET='\033[0m' C_BOLD='\033[1m' C_DIM='\033[2m'
  readonly C_RED='\033[31m' C_GREEN='\033[32m' C_YELLOW='\033[33m' C_BLUE='\033[34m' C_CYAN='\033[36m'
else
  readonly C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN=''
fi

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_GREEN}" "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_step()  { printf "%b==>%b %s\n"            "${C_GREEN}" "${C_RESET}" "$*"; }

require_qemu() {
  command -v qemu-system-x86_64 >/dev/null 2>&1 || {
    log_error "Install: sudo apt install qemu-system-x86 qemu-utils"; exit 1
  }
}

# ========== VM Storage ==========
# Setiap VM adalah folder di builds/vms/<name>/
#   config        — file konfigurasi (key=value)
#   disk.qcow2    — disk image
#   vm.pid        — PID QEMU (jika running)

vm_dir()   { echo "${VMS_DIR}/$1"; }
vm_cfg()   { echo "$(vm_dir "$1")/config"; }
vm_disk()  { echo "$(vm_dir "$1")/disk.qcow2"; }
vm_pid()   { echo "$(vm_dir "$1")/vm.pid"; }

vm_running() {
  local pid_file; pid_file=$(vm_pid "$1")
  [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}")" 2>/dev/null
}

# ========== Commands ==========

cmd_list() {
  log_step "Daftar VM"
  mkdir -p "${VMS_DIR}"
  local found=false
  for dir in "${VMS_DIR}"/*/; do
    [[ -d "${dir}" ]] || continue
    local name; name=$(basename "${dir}")
    found=true
    local status="OFF"
    vm_running "${name}" && status="RUNNING"
    local ram cpus disk iso
    ram=$(grep -s '^RAM=' "${dir}config" | cut -d= -f2) || ram="?"
    cpus=$(grep -s '^CPUS=' "${dir}config" | cut -d= -f2) || cpus="?"
    disk=$(grep -s '^DISK_GB=' "${dir}config" | cut -d= -f2) || disk="?"
    iso=$(grep -s '^ISO=' "${dir}config" | cut -d= -f2) || iso="-"
    local status_color="${C_RED}"
    [[ "${status}" == "RUNNING" ]] && status_color="${C_GREEN}"
    printf "  %b%-12s%b  %b%-7s%b  RAM=%s  CPU=%s  DISK=%sG\n" \
      "${C_BOLD}" "${name}" "${C_RESET}" \
      "${status_color}" "${status}" "${C_RESET}" \
      "${ram}" "${cpus}" "${disk}"
  done
  [[ "${found}" == false ]] && echo "  (belum ada VM. Buat: ./test-vm.sh create <nama>)"
}

cmd_create() {
  local name="$1"
  if [[ -z "${name}" ]]; then
    log_error "Gunakan: ./test-vm.sh create <nama> [--ram=4096] [--cpus=2] [--disk=20] [--iso=path]"; exit 1
  fi
  shift
  local dir; dir=$(vm_dir "${name}")
  if [[ -d "${dir}" ]]; then
    log_error "VM '${name}' sudah ada"; exit 1
  fi

  mkdir -p "${dir}"
  local RAM=4096 CPUS=2 DISK_GB=20 ISO=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ram=*)   RAM="${1#*=}" ;;
      --cpus=*)  CPUS="${1#*=}" ;;
      --disk=*)  DISK_GB="${1#*=}" ;;
      --iso=*)   ISO="${1#*=}" ;;
      *)         log_error "Argumen tidak dikenal: $1"; exit 1 ;;
    esac
    shift
  done

  # Cari ISO otomatis jika tidak ditentukan
  if [[ -z "${ISO}" ]]; then
    ISO=$(find "${PROJECT_ROOT}/${BUILD_DIR}" -maxdepth 2 -name '*.iso' -type f -printf '%T@ %p\n' 2>/dev/null \
      | sort -rn | head -1 | cut -d' ' -f2- || true)
  fi

  cat > "$(vm_cfg "${name}")" <<CFG
RAM=${RAM}
CPUS=${CPUS}
DISK_GB=${DISK_GB}
ISO=${ISO}
CFG

  log_info "Membuat disk ${DISK_GB}G..."
  qemu-img create -f qcow2 "$(vm_disk "${name}")" "${DISK_GB}G"
  log_info "VM '${name}' dibuat"
  cmd_info "${name}"
}

cmd_delete() {
  local name="$1"
  if [[ -z "${name}" ]]; then log_error "Gunakan: ./test-vm.sh delete <nama>"; exit 1; fi
  local dir; dir=$(vm_dir "${name}")
  [[ -d "${dir}" ]] || { log_error "VM '${name}' tidak ditemukan"; exit 1; }

  if vm_running "${name}"; then
    log_warn "VM '${name}' sedang running. Stop dulu: ./test-vm.sh stop ${name}"
    exit 1
  fi

  local size
  size=$(du -sh "${dir}" 2>/dev/null | cut -f1)
  log_warn "Hapus VM '${name}' (${size})? [y/N]"
  read -r confirm
  [[ "${confirm}" == "y" || "${confirm}" == "Y" ]] || { log_info "Dibatalkan"; exit 0; }

  rm -rf "${dir}"
  log_info "VM '${name}' dihapus"
}

cmd_start() {
  local name="$1"
  if [[ -z "${name}" ]]; then log_error "Gunakan: ./test-vm.sh start <nama>"; exit 1; fi
  local dir; dir=$(vm_dir "${name}")
  [[ -f "$(vm_cfg "${name}")" ]] || { log_error "VM '${name}' tidak ditemukan"; exit 1; }

  if vm_running "${name}"; then
    log_warn "VM '${name}' sudah running"; exit 1
  fi

  source "$(vm_cfg "${name}")"
  require_qemu

  local kvm_opts=""
  [[ -e /dev/kvm ]] && kvm_opts="-enable-kvm -cpu host"

  local display_opts="-display gtk"
  local pid_file; pid_file=$(vm_pid "${name}")

  log_info "Start VM: ${name} (RAM=${RAM}, CPU=${CPUS}, DISK=${DISK_GB}G)"
  [[ -n "${ISO}" ]] && log_info "ISO: ${ISO}"

  local qemu_args=(
    -m "${RAM:-4096}" -smp "${CPUS:-2}"
    -vga virtio
    -netdev user,id=net0 -device virtio-net,netdev=net0
    -usb -device usb-tablet
    -drive "file=$(vm_disk "${name}"),format=qcow2,if=virtio"
    ${display_opts}
    ${kvm_opts}
    -daemonize -pidfile "${pid_file}"
  )
  if [[ -n "${ISO}" && -f "${ISO}" ]]; then
    qemu_args+=(-cdrom "${ISO}" -boot d)
  else
    qemu_args+=(-boot c)
  fi
  qemu-system-x86_64 "${qemu_args[@]}"

  sleep 1
  if vm_running "${name}"; then
    log_info "VM '${name}' started (PID: $(cat "${pid_file}"))"
    log_info "Stop: ./test-vm.sh stop ${name}"
  else
    log_error "VM '${name}' gagal start"; exit 1
  fi
}

cmd_stop() {
  local name="$1"
  if [[ -z "${name}" ]]; then log_error "Gunakan: ./test-vm.sh stop <nama>"; exit 1; fi
  local pid_file; pid_file=$(vm_pid "${name}")

  if [[ ! -f "${pid_file}" ]]; then
    log_warn "VM '${name}' tidak running"; exit 0
  fi

  local pid; pid=$(cat "${pid_file}")
  if ! kill -0 "${pid}" 2>/dev/null; then
    log_warn "VM '${name}' sudah mati"; rm -f "${pid_file}"; exit 0
  fi

  log_info "Menghentikan VM '${name}' (PID: ${pid})..."
  kill "${pid}" 2>/dev/null || true
  for i in 1 2 3 4 5; do
    sleep 1
    if ! kill -0 "${pid}" 2>/dev/null; then
      rm -f "${pid_file}"
      log_info "VM '${name}' berhenti"
      return 0
    fi
  done
  log_warn "Force stop..."
  kill -9 "${pid}" 2>/dev/null || true
  rm -f "${pid_file}"
  log_info "VM '${name}' di-stop (force)"
}

cmd_info() {
  local name="$1"
  if [[ -z "${name}" ]]; then log_error "Gunakan: ./test-vm.sh info <nama>"; exit 1; fi
  local dir; dir=$(vm_dir "${name}")
  [[ -f "$(vm_cfg "${name}")" ]] || { log_error "VM '${name}' tidak ditemukan"; exit 1; }

  local status="OFF"
  vm_running "${name}" && status="RUNNING"
  log_step "VM: ${name} (${status})"
  cat "$(vm_cfg "${name}")"
  echo "DISK_PATH=$(vm_disk "${name}")"
  if [[ -f "$(vm_disk "${name}")" ]]; then
    echo "DISK_SIZE=$(du -h "$(vm_disk "${name}")" | cut -f1)"
  fi
  if vm_running "${name}"; then
    echo "PID=$(cat "$(vm_pid "${name}")")"
  fi
}

cmd_help() {
  cat <<EOF
test-vm.sh — Manajemen VM QEMU untuk mixos

Usage:
  ./test-vm.sh list                          # Daftar VM
  ./test-vm.sh create <nama> [options]       # Buat VM baru
  ./test-vm.sh start <nama>                  # Jalankan VM
  ./test-vm.sh stop <nama>                   # Hentikan VM
  ./test-vm.sh delete <nama>                 # Hapus VM (berhenti dulu)
  ./test-vm.sh info <nama>                   # Detail VM

Options untuk create:
  --ram=4096      RAM dalam MB (default: 4096)
  --cpus=2        Jumlah CPU (default: 2)
  --disk=20       Ukuran disk GB (default: 20)
  --iso=path      Path ke ISO (default: cari otomatis)

Contoh:
  ./test-vm.sh create mixos-test --ram=4096 --cpus=2 --disk=20
  ./test-vm.sh start mixos-test
  ./test-vm.sh list
  ./test-vm.sh stop mixos-test
  ./test-vm.sh delete mixos-test
EOF
}

# ========== Main ==========
main() {
  mkdir -p "${VMS_DIR}"

  if [[ $# -eq 0 ]]; then
    cmd_help; exit 0
  fi

  local cmd="$1"; shift

  case "${cmd}" in
    list|ls)    cmd_list ;;
    create)     cmd_create "$@" ;;
    start)      cmd_start "$@" ;;
    stop)       cmd_stop "$@" ;;
    delete|rm)  cmd_delete "$@" ;;
    info)       cmd_info "$@" ;;
    help|--help|-h) cmd_help ;;
    *)
      if [[ -d "$(vm_dir "${cmd}")" ]]; then
        cmd_start "${cmd}"
      else
        log_error "Perintah tidak dikenal: ${cmd}"; cmd_help; exit 1
      fi
      ;;
  esac
}

main "$@"
