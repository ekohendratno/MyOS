#!/usr/bin/env bash
# =============================================================================
# prepare-build-env.sh — Validasi environment untuk build mixos
# =============================================================================
# Script ini mengecek apakah host memiliki tools yang dibutuhkan untuk
# build ISO mixos. Tidak mengubah host secara destruktif, hanya cek.
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="prepare-build-env.sh"
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
ok()       { printf "  %b✓%b %s\n"            "${C_GREEN}" "${C_RESET}" "$*"; }
fail()     { printf "  %b✗%b %s\n"            "${C_RED}"   "${C_RESET}" "$*"; }
warn()     { printf "  %b!%b %s\n"            "${C_YELLOW}" "${C_RESET}" "$*"; }

# === Required tools untuk build ===
readonly REQUIRED_TOOLS=(
  "git"
  "curl"
  "wget"
  "debootstrap"
  "live-build"
  "xorriso"
  "isolinux"
  "syslinux-common"
  "grub-pc-bin"
  "grub-efi-amd64-bin"
  "grub-efi-ia32-bin"
  "mtools"
  "squashfs-tools"
  "genisoimage"
  "rsync"
  "file"
  "gzip"
  "xz-utils"
  "ca-certificates"
)

# === Recommended tools ===
readonly RECOMMENDED_TOOLS=(
  "qemu-system-x86"
  "docker.io"
  "podman"
  "git-lfs"
  "vim"
  "less"
  "tree"
  "htop"
)

# === Cek satu command ===
check_cmd() {
  local cmd="$1"
  if command -v "${cmd}" >/dev/null 2>&1; then
    ok "Found: ${cmd} ($(command -v "${cmd}"))"
    return 0
  fi
  fail "Missing: ${cmd}"
  return 1
}

# === Cek resource host ===
check_resources() {
  log_step "Cek resource host"

  # CPU
  local cores
  cores=$(nproc 2>/dev/null || echo "unknown")
  log_info "CPU cores  : ${cores}"
  if [[ "${cores}" =~ ^[0-9]+$ ]] && [[ "${cores}" -lt 4 ]]; then
    warn "Disarankan minimal 4 core untuk build cepat"
  else
    ok "CPU OK"
  fi

  # RAM
  local ram_mb
  ram_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo "0")
  log_info "RAM total  : ${ram_mb} MB"
  if [[ "${ram_mb}" -lt 8192 ]]; then
    warn "Disarankan minimal 8 GB RAM"
  else
    ok "RAM OK"
  fi

  # Disk
  local disk_free_kb
  disk_free_kb=$(df -k "${PROJECT_ROOT}" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
  local disk_free_gb=$((disk_free_kb / 1024 / 1024))
  log_info "Disk free  : ${disk_free_gb} GB"
  if [[ "${disk_free_gb}" -lt 50 ]]; then
    warn "Disarankan minimal 50 GB disk kosong"
  else
    ok "Disk OK"
  fi
}

# === Cek sudo ===
check_sudo() {
  log_step "Cek privilege"
  if [[ "${EUID}" -eq 0 ]]; then
    warn "Script dijalankan sebagai root. Build TIDAK seharusnya dijalankan sebagai root di host."
    warn "Gunakan container/VM dengan user non-root."
  elif command -v sudo >/dev/null 2>&1; then
    ok "sudo tersedia"
  else
    warn "sudo tidak tersedia. Beberapa operasi build mungkin gagal."
  fi
}

# === Cek KVM ===
check_kvm() {
  log_step "Cek KVM (opsional, untuk test-vm.sh)"
  if [[ -e /dev/kvm ]]; then
    ok "/dev/kvm tersedia (KVM akan digunakan)"
  else
    warn "/dev/kvm tidak tersedia (test-vm akan lambat tapi masih jalan)"
  fi
}

# === Main check ===
check_all() {
  local missing=0
  for cmd in "${REQUIRED_TOOLS[@]}"; do
    if ! check_cmd "${cmd}"; then
      missing=$((missing + 1))
    fi
  done

  log_step "Recommended tools (opsional)"
  for cmd in "${RECOMMENDED_TOOLS[@]}"; do
    check_cmd "${cmd}" || true
  done

  return "${missing}"
}

# === Main ===
main() {
  log_step "prepare-build-env.sh — Validasi environment"

  log_info "Project    : ${PROJECT_NAME} ${PROJECT_VERSION}"
  log_info "Base       : ${BASE_DISTRO} ${BASE_DISTRO_VERSION}"
  log_info "Arch       : ${BASE_ARCH}"

  local missing=0
  log_step "Cek required tools"
  if ! check_all; then
    missing=1
  fi

  check_resources
  check_sudo
  check_kvm

  log_step "Ringkasan"
  if [[ "${missing}" -eq 0 ]]; then
    ok "Environment siap untuk build mixos"
    log_info "Lanjut dengan: ./scripts/clone-upstream.sh && ./build.sh --no-dry-run"
    exit 0
  else
    log_error "Beberapa tool wajib hilang. Install dengan:"
    log_error "  sudo apt install debootstrap live-build xorriso isolinux \\"
    log_error "    syslinux-common grub-pc-bin grub-efi-amd64-bin mtools \\"
    log_error "    squashfs-tools genisoimage"
    exit 1
  fi
}

main "$@"
