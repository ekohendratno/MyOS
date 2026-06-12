#!/usr/bin/env bash
# =============================================================================
# build.sh — Orchestrator build ISO mixos
# =============================================================================
# Script ini:
# 1. Validasi environment
# 2. Load konfigurasi mixos
# 3. Clone upstream elementary/os
# 4. Set up live-build config (merge upstream + mixos)
# 5. Jalankan lb config + lb build (butuh sudo untuk chroot)
# 6. Output ISO ke builds/
# 7. Generate checksum
#
# Default dry-run: ./build.sh (tidak menjalankan build)
# Build aktual:   ./build.sh --no-dry-run
#
# Build harus dijalankan dengan sudo atau di WSL2/Linux VM.
# =============================================================================

set -euo pipefail

readonly SCRIPT_NAME="build.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_PATH}"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

# === Defaults ===
DRY_RUN=true
VERBOSE=false
USE_CACHE=true
SKIP_UPSTREAM_CLONE=false

# === Colors ===
if [[ -t 1 ]]; then
  readonly C_RESET='\033[0m' C_BOLD='\033[1m' C_DIM='\033[2m'
  readonly C_RED='\033[31m' C_GREEN='\033[32m' C_YELLOW='\033[33m' C_BLUE='\033[34m'
else
  readonly C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

log_info()  { printf "%b[%s] [INFO]%b  %s\n"  "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; }
log_warn()  { printf "%b[%s] [WARN]%b  %s\n"  "${C_YELLOW}" "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_error() { printf "%b[%s] [ERROR]%b %s\n"  "${C_RED}"    "$(date +%H:%M:%S)" "${C_RESET}" "$*" >&2; }
log_step()  { printf "%b==>%b %b%s%b\n"        "${C_GREEN}" "${C_RESET}" "${C_BOLD}" "$*" "${C_RESET}"; }

# === Help ===
print_help() {
  cat <<'EOF'
build.sh — Build ISO mixos

Usage:
  ./build.sh [options]

Options:
  --dry-run            Validasi config + rencana, no changes (default).
  --no-dry-run         Jalankan build aktual (butuh sudo di WSL/Linux).
  --no-cache           Hapus cache chroot sebelum build.
  --skip-upstream      Jangan clone ulang upstream.
  -h, --help           Tampilkan bantuan.

Peringatan:
  - Build butuh sudo untuk chroot. Jalankan di WSL2/Linux VM.
  - Waktu: 2-6 jam, disk: 50+ GB.
EOF
}

# === Arg parsing ===
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)         DRY_RUN=true ;;
      --no-dry-run)      DRY_RUN=false ;;
      --no-cache)         USE_CACHE=false ;;
      --skip-upstream)   SKIP_UPSTREAM_CLONE=true ;;
      -h|--help)         print_help; exit 0 ;;
      *)                 log_error "Argumen tidak dikenal: $1"; print_help; exit 1 ;;
    esac
    shift
  done
}

# === Utility functions ===
require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    log_error "Missing: ${cmd}. Jalankan: sudo apt install ${cmd}"
    return 1
  fi
}

require_path() {
  [[ -e "$1" ]] || { log_error "Path tidak ada: $1"; return 1; }
}

load_config() {
  log_step "Memuat konfigurasi"
  require_path "${CONFIG_FILE}"
  source "${CONFIG_FILE}"

  PROJECT_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  PROJECT_BUILD_BRANCH="$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"

  [[ "${VERBOSE}" == "true" ]] && set -x

  log_info "Project       : ${PROJECT_NAME} ${PROJECT_VERSION} (${PROJECT_CODENAME})"
  log_info "Build date    : ${PROJECT_BUILD_DATE}"
  log_info "Build branch  : ${PROJECT_BUILD_BRANCH}"
  log_info "Base          : ${BASE_DISTRO} ${BASE_DISTRO_VERSION} / ${BASE_ARCH}"
}

validate_environment() {
  log_step "Validasi environment"

  local req=(bash git find sort xargs sed)
  for cmd in "${req[@]}"; do require_cmd "${cmd}" || exit 1; done

  require_path "${PROJECT_ROOT}/config" || exit 1
  require_path "${PROJECT_ROOT}/scripts" || exit 1
  require_path "${PROJECT_ROOT}/hooks" || exit 1

  if [[ "${DRY_RUN}" == "false" ]]; then
    local build_tools=(debootstrap lb xorriso)
    for cmd in "${build_tools[@]}"; do
      require_cmd "${cmd}" || { log_error "Install: sudo apt install debootstrap live-build xorriso"; exit 1; }
    done

    # Cek root
    if [[ "$(id -u)" != "0" ]]; then
      log_warn "Build butuh root. Re-run dengan: sudo ./build.sh --no-dry-run"
      [[ "${DRY_RUN}" == "false" ]] && exit 1
    fi
  fi

  log_info "Environment OK"
}

prepare_build_dirs() {
  log_step "Menyiapkan folder build"
  local dirs=(
    "${PROJECT_ROOT}/${BUILD_DIR}"
    "${PROJECT_ROOT}/${UPSTREAM_DIR}"
    "${PROJECT_ROOT}/${LOG_DIR}"
  )
  for d in "${dirs[@]}"; do
    mkdir -p "${d}"
    log_info "Folder: ${d}"
  done
}

clone_upstream() {
  log_step "Clone upstream elementary/os"
  local target="${PROJECT_ROOT}/${UPSTREAM_DIR}/elementary-os"

  if [[ -d "${target}/.git" ]] && [[ "${SKIP_UPSTREAM_CLONE}" == "true" ]]; then
    log_info "Skip clone (--skip-upstream)"
    return 0
  fi

  if [[ -d "${target}/.git" ]]; then
    log_info "Upstream sudah ada di ${target}"
    return 0
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Akan clone: ${BASE_DISTRO_URL} -> ${target}"
    return 0
  fi

  log_info "Cloning ${BASE_DISTRO_URL}..."
  git clone --depth 1 "${BASE_DISTRO_URL}" "${target}"
  log_info "Clone selesai"
}

# =============================================================================
# BUILD CORE — live-build integration
# =============================================================================
setup_live_build() {
  local upstream="${PROJECT_ROOT}/${UPSTREAM_DIR}/elementary-os"

  if [[ ! -d "${upstream}/etc" ]]; then
    log_error "Upstream etc/ tidak ditemukan. Jalankan ./scripts/clone-upstream.sh"
    exit 1
  fi

  log_info "Upstream etc/ OK: $(find "${upstream}/etc" -type f | wc -l) files"
}

run_live_build() {
  local upstream="${PROJECT_ROOT}/${UPSTREAM_DIR}/elementary-os"
  local work_dir="${PROJECT_ROOT}/${BUILD_DIR}/work-${BASE_ARCH}"

  log_step "Setup working directory: ${work_dir}"
  rm -rf "${work_dir}"
  mkdir -p "${work_dir}"

  # --- Copy upstream etc/ ---
  log_info "Copy upstream etc/ -> working dir"
  cp -r "${upstream}/etc/"* "${work_dir}/"

  # --- Buat terraform config untuk mixos ---
  log_info "Buat terraform-amd64.conf untuk mixos"
  cat > "${work_dir}/terraform.conf" <<EOF
# === mixos terraform config ===
ARCH="${BASE_ARCH}"
BASECODENAME="noble"
BASEVERSION="24.04"
CODENAME="${PROJECT_CODENAME}"
VERSION="${PROJECT_VERSION_ID}"
CHANNEL="stable"
NAME="${PROJECT_NAME}"
MIRROR_URL="http://archive.ubuntu.com/ubuntu/"
HWE_KERNEL="yes"
HWE_X11="no"
OUTPUT_SUFFIX="-${PROJECT_CODENAME}-${PROJECT_VERSION_ID}"
EOF

  log_info "Config: $(cat "${work_dir}/terraform.conf")"

  # --- Generate chroot-safe hooks ---
  # Hooks di chroot TIDAK bisa akses PROJECT_ROOT. Semua path dan
  # konfigurasi harus di-embed langsung ke dalam hook script.
  log_info "Generate chroot hooks dengan nilai embedded"
  local hooks_target="${work_dir}/config/hooks/live"
  mkdir -p "${hooks_target}"

  # -- Hook: mixos-setup.chroot (setup branding + settings) --
  cat > "${hooks_target}/mixos-setup.chroot" <<CHROOTHOOK
#!/usr/bin/env bash
set -euo pipefail

HOOK_NAME="mixos-setup"
log_info()  { printf "[%s] [INFO]  %s\n"  "\$(date +%H:%M:%S)" "\$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "\$(date +%H:%M:%S)" "\$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "\$(date +%H:%M:%S)" "\$*" >&2; }

log_info "=== \${HOOK_NAME} ==="

# --- /etc/os-release ---
log_info "Menulis /etc/os-release"
cat > /etc/os-release <<OSEOF
NAME="${PROJECT_NAME}"
PRETTY_NAME="${PROJECT_DISPLAY_NAME} ${PROJECT_PRETTY_VERSION}"
ID="${PROJECT_NAME}"
ID_LIKE="elementary ubuntu debian"
VERSION="${PROJECT_PRETTY_VERSION}"
VERSION_ID="${PROJECT_VERSION_ID}"
VERSION_CODENAME="${PROJECT_CODENAME}"
HOME_URL="https://github.com/ekohe/mixos"
SUPPORT_URL="https://github.com/ekohe/mixos/issues"
BUG_REPORT_URL="https://github.com/ekohe/mixos/issues/new"
OSEOF

# --- /etc/hostname ---
echo "${PROJECT_DEFAULT_HOSTNAME}" > /etc/hostname

# --- /etc/lsb-release (jika ada) ---
if [[ -f /etc/lsb-release ]]; then
  cat > /etc/lsb-release <<LSBEOF
DISTRIB_ID=${PROJECT_NAME}
DISTRIB_RELEASE=${PROJECT_VERSION_ID}
DISTRIB_CODENAME=${PROJECT_CODENAME}
DISTRIB_DESCRIPTION="${PROJECT_DISPLAY_NAME} ${PROJECT_PRETTY_VERSION}"
LSBEOF
fi

# --- Copy wallpaper to backgrounds (jika ada di includes) ---
if [[ -d /usr/share/backgrounds/mixos ]]; then
  log_info "Wallpaper mixos ditemukan di /usr/share/backgrounds/mixos"
fi

# --- Patches marker ---
mkdir -p /usr/share/mixos-patches
cat > /usr/share/mixos-patches/mixos-info.json <<PEOF
{
  "name": "${PROJECT_NAME}",
  "version": "${PROJECT_VERSION}",
  "codename": "${PROJECT_CODENAME}",
  "build": "${PROJECT_BUILD_DATE}"
}
PEOF

# --- GTK settings.ini ---
log_info "Setup GTK settings"
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini <<GTKEOF
[Settings]
gtk-theme-name=mixos-gtk
gtk-icon-theme-name=mixos-icons
gtk-cursor-theme-name=mixos-cursors
gtk-cursor-theme-size=24
gtk-font-name=Inter 10.5
gtk-application-prefer-dark-theme=true
gtk-decoration-layout=close,minimize,maximize:menu
gtk-enable-animations=true
GTKEOF

mkdir -p /etc/gtk-4.0
cat > /etc/gtk-4.0/settings.ini <<GTK4EOF
[Settings]
gtk-theme-name=mixos-gtk
gtk-icon-theme-name=mixos-icons
gtk-cursor-theme-name=mixos-cursors
gtk-cursor-theme-size=24
gtk-font-name=Inter 10.5
gtk-application-prefer-dark-theme=1
GTK4EOF

# --- issue / motd ---
cat > /etc/issue <<ISS
${PROJECT_DISPLAY_NAME} ${PROJECT_VERSION} \\\\n \\\\l

ISS

log_info "\${HOOK_NAME} selesai"
CHROOTHOOK

  chmod +x "${hooks_target}/mixos-setup.chroot"
  log_info "  Generated: mixos-setup.chroot"

  # -- Hook: mixos-packages.chroot (install additional packages) --
  log_info "Generated: mixos-packages.chroot"
  cat > "${hooks_target}/mixos-packages.chroot" <<PKGEOF
#!/usr/bin/env bash
set -euo pipefail
HOOK_NAME="mixos-packages"
log_info()  { printf "[%s] [INFO]  %s\n"  "\$(date +%H:%M:%S)" "\$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "\$(date +%H:%M:%S)" "\$*" >&2; }
log_info "=== \${HOOK_NAME} ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update
PKGEOF

  # Note: actual package installation is handled by live-build's native
  # package-list mechanism (see mixos-packages.list.chroot generation below).
  # This hook only ensures apt is updated and cleaned.
  cat >> "${hooks_target}/mixos-packages.chroot" <<PKGENDF
apt-get clean
log_info "mixos-packages selesai"
PKGENDF

  chmod +x "${hooks_target}/mixos-packages.chroot"

  # -- Hook: mixos-security.chroot --
  log_info "Generated: mixos-security.chroot"
  cat > "${hooks_target}/mixos-security.chroot" <<SECEOF
#!/usr/bin/env bash
set -euo pipefail
HOOK_NAME="mixos-security"
log_info()  { printf "[%s] [INFO]  %s\n"  "\$(date +%H:%M:%S)" "\$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "\$(date +%H:%M:%S)" "\$*" >&2; }
log_info "=== \${HOOK_NAME} ==="

# Lock root account (non-fatal di chroot)
passwd -l root 2>/dev/null || true

# Set permissions
chmod 644 /etc/passwd 2>/dev/null || true
chmod 000 /etc/shadow 2>/dev/null || true
chmod 000 /etc/gshadow 2>/dev/null || true

# Disable SSH
systemctl disable ssh.service 2>/dev/null || true
systemctl disable sshd.service 2>/dev/null || true

# Sysctl hardening
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-mixos.conf <<SYSEOF
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
SYSEOF

log_info "Security hardening selesai"
SECEOF

  chmod +x "${hooks_target}/mixos-security.chroot"

  # -- Hook: mixos-cleanup.chroot --
  log_info "Generated: mixos-cleanup.chroot"
  cat > "${hooks_target}/mixos-cleanup.chroot" <<CLNEOF
#!/usr/bin/env bash
set -euo pipefail
HOOK_NAME="mixos-cleanup"
log_info()  { printf "[%s] [INFO]  %s\n"  "\$(date +%H:%M:%S)" "\$*"; }
log_info "=== \${HOOK_NAME} ==="

apt-get clean
rm -rf /var/lib/apt/lists/* 2>/dev/null || true
rm -rf /usr/share/doc/* 2>/dev/null || true
rm -rf /usr/share/man/* 2>/dev/null || true
rm -f /root/.bash_history 2>/dev/null || true
rm -f /home/*/.bash_history 2>/dev/null || true
find /var/log -type f -name '*.log' -delete 2>/dev/null || true
truncate -s 0 /etc/machine-id 2>/dev/null || true
rm -f /var/lib/dbus/machine-id 2>/dev/null || true
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true

log_info "Cleanup selesai"
CLNEOF

  chmod +x "${hooks_target}/mixos-cleanup.chroot"

  # --- Merge mixos package lists ---
  log_info "Merge mixos packages -> config/package-lists/"
  local pkg_target="${work_dir}/config/package-lists"
  mkdir -p "${pkg_target}"

  # Ekstrak hanya nama paket valid dari packages.list
  # Filter: skip baris komentar (#), skip baris kosong, skip placeholder (paket yang
  # diawali '#' di tengah baris atau berisi 'mixos-*' di packages.list)
  if [[ -f "${PROJECT_ROOT}/config/packages.list" ]]; then
    grep -vE '^\s*(#|$)' "${PROJECT_ROOT}/config/packages.list" \
      | grep -vE 'mixos-' \
      | grep -vE '^\s*$' \
      | grep -vE 'placeholder|akan dibuat|Tahap' \
      | awk '{print $1}' \
      | grep -vE 'glib2.0-tools|pomodoro|papers' \
      > "${pkg_target}/mixos-packages.list.chroot" || true
    log_info "Packages: $(wc -l < "${pkg_target}/mixos-packages.list.chroot") valid entries"
  fi

  # --- Merge branding ---
  log_info "Setup branding di includes.chroot/"
  local includes_chroot="${work_dir}/config/includes.chroot"
  mkdir -p "${includes_chroot}/usr/share/mixos-branding/logo"
  mkdir -p "${includes_chroot}/usr/share/mixos-branding/wallpaper"
  mkdir -p "${includes_chroot}/usr/share/mixos-branding/about"
  mkdir -p "${includes_chroot}/usr/share/backgrounds/mixos"
  mkdir -p "${includes_chroot}/etc"

  # Copy logo (jika ada)
  if [[ -f "${PROJECT_ROOT}/branding/logo/mixos-logo.svg" ]]; then
    cp "${PROJECT_ROOT}/branding/logo/mixos-logo.svg" "${includes_chroot}/usr/share/mixos-branding/logo/"
    log_info "  Logo: mixos-logo.svg"
  fi
  if [[ -f "${PROJECT_ROOT}/branding/logo/mixos-icon.svg" ]]; then
    cp "${PROJECT_ROOT}/branding/logo/mixos-icon.svg" "${includes_chroot}/usr/share/mixos-branding/logo/"
  fi

  # Copy wallpaper (jika ada)
  if [[ -f "${PROJECT_ROOT}/branding/wallpaper/mixos-default.svg" ]]; then
    cp "${PROJECT_ROOT}/branding/wallpaper/mixos-default.svg" "${includes_chroot}/usr/share/backgrounds/mixos/"
    log_info "  Wallpaper: mixos-default.svg"
  fi
  if [[ -f "${PROJECT_ROOT}/branding/wallpaper/mixos-dark.svg" ]]; then
    cp "${PROJECT_ROOT}/branding/wallpaper/mixos-dark.svg" "${includes_chroot}/usr/share/backgrounds/mixos/"
  fi

  # Pre-buat /etc/hostname
  echo "mixos-host" > "${includes_chroot}/etc/hostname"
  log_info "  /etc/hostname: mixos-host"

  # --- Update bootloader config ---
  log_info "Update bootloader config"
  local grub_cfg="${work_dir}/config/bootloaders/grub-pc/grub.cfg"
  if [[ -f "${grub_cfg}" ]]; then
    sed -i "s/elementary OS/${PROJECT_DISPLAY_NAME}/g" "${grub_cfg}" 2>/dev/null || true
    sed -i "s/elementary/${PROJECT_NAME}/g" "${grub_cfg}" 2>/dev/null || true
  fi

  local isolinux_cfg="${work_dir}/config/bootloaders/isolinux/live.cfg.in"
  if [[ -f "${isolinux_cfg}" ]]; then
    sed -i "s/elementary/${PROJECT_NAME}/g" "${isolinux_cfg}" 2>/dev/null || true
  fi

  # Update binary disk info
  local disk_info="${work_dir}/config/includes.binary/.disk/info"
  if [[ -f "${disk_info}" ]]; then
    cat > "${disk_info}" <<DISKEOF
${PROJECT_NAME} ${PROJECT_VERSION} (${PROJECT_CODENAME}) ${BASE_ARCH} - $(date +%Y%m%d)
DISKEOF
    log_info "  .disk/info updated"
  fi

  # --- Show final config structure ---
  log_info "Config structure:"
  find "${work_dir}/config" -maxdepth 2 -type f | sort | while read -r f; do
    log_info "  ${f#${work_dir}/}"
  done

  # --- Run live-build ---
  cd "${work_dir}"

  log_step "=== LIVE-BUILD CLEAN ==="
  lb clean 2>&1 | while IFS= read -r line; do log_info "  ${line}"; done

  log_step "=== LIVE-BUILD CONFIG ==="
  lb config 2>&1 | while IFS= read -r line; do log_info "  ${line}"; done

  log_step "=== LIVE-BUILD BUILD ==="
  log_warn "Build dimulai. Ini akan memakan waktu 2-6 jam tergantung koneksi dan CPU."
  log_warn "Output build ditampilkan langsung di bawah ini:"
  echo "---[ live-build output start ]---"
  lb build 2>&1
  echo "---[ live-build output end ]---"

  # --- Move ISO to builds/ ---
  log_step "Move ISO output"
  local iso_file
  iso_file="$(find . -maxdepth 1 -name 'live-image-*.hybrid.iso' -type f | head -1)"

  if [[ -z "${iso_file}" ]]; then
    log_error "ISO file tidak ditemukan! Cek log build."
    ls -la "${work_dir}/"
    exit 1
  fi

  local yyyymmdd
  yyyymmdd="$(date +%Y%m%d)"
  local output_name="${PROJECT_NAME}-${PROJECT_CODENAME}-${PROJECT_VERSION_ID}-${BASE_ARCH}.${yyyymmdd}.iso"
  local output_dir="${PROJECT_ROOT}/${BUILD_DIR}"
  mkdir -p "${output_dir}"

  log_info "Move: ${iso_file} -> ${output_dir}/${output_name}"
  mv "${iso_file}" "${output_dir}/${output_name}"

  # --- Checksum ---
  cd "${output_dir}"
  sha256sum "${output_name}" > "${output_name}.sha256"
  md5sum "${output_name}" > "${output_name}.md5"

  log_info "Checksum dibuat"
  log_info "SHA256: $(cat "${output_name}.sha256")"
}

# === Install build dependencies (sama seperti upstream) ===
install_build_deps() {
  log_step "Install build dependencies"

  local deps=(live-build patch gnupg2 binutils zstd)
  local missing=()
  for pkg in "${deps[@]}"; do
    if ! dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"; then
      missing+=("${pkg}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_info "Install missing packages: ${missing[*]}"
    apt-get update -qq
    apt-get install -y --no-install-recommends "${missing[@]}"
  else
    log_info "All build dependencies already installed"
  fi

  # Import Ubuntu signing key (seperti upstream)
  log_info "Import Ubuntu signing key"
  gpg --homedir /tmp --no-default-keyring --keyring /etc/apt/trusted.gpg \
    --recv-keys --keyserver keyserver.ubuntu.com F6ECB3762474EDA9D21B7022871920D1991BC93C 2>&1 || \
    log_warn "GPG key import failed (might already exist)"

  # Symlink untuk debootstrap noble
  if [[ ! -f /usr/share/debootstrap/scripts/noble ]]; then
    log_info "Create debootstrap noble symlink"
    ln -sfn /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/noble
  fi
}

# === Build (actual entrypoint) ===
run_build() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Build tidak dijalankan"
    log_info "[DRY-RUN] Untuk build aktual:"
    log_info "  sudo ./build.sh --no-dry-run"
    return 0
  fi

  install_build_deps
  setup_live_build
  run_live_build
}

print_summary() {
  log_step "Ringkasan Build"
  local output_dir="${PROJECT_ROOT}/${BUILD_DIR}"
  cat <<EOF
Project   : ${PROJECT_NAME} ${PROJECT_VERSION} (${PROJECT_CODENAME})
Build     : ${PROJECT_BUILD_DATE}
Output    : ${output_dir}/
Files     : $(find "${output_dir}" -maxdepth 1 -type f | sort)
Next step : Test ISO dengan: ./test-vm.sh --iso=${output_dir}/*.iso
EOF
}

# === Main ===
main() {
  parse_args "$@"
  log_step "build.sh — mixos ISO builder"

  load_config
  validate_environment
  prepare_build_dirs
  clone_upstream
  run_build
  print_summary

  log_info "build.sh selesai"
}

main "$@"
