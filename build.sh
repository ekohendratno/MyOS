#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="build.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_PATH}"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

DRY_RUN=true
VERBOSE=false
SKIP_UPSTREAM=false

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

print_help() {
  cat <<'EOF'
build.sh — Build ISO mixos (LingmoOS base)

Usage:  ./build.sh [options]

Options:
  --dry-run            Validasi saja (default).
  --no-dry-run         Jalankan build (butuh sudo).
  --skip-upstream      Jangan clone ulang upstream.
  -h, --help           Tampilkan bantuan.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)         DRY_RUN=true ;;
      --no-dry-run)      DRY_RUN=false ;;
      --skip-upstream)   SKIP_UPSTREAM=true ;;
      -h|--help)         print_help; exit 0 ;;
      *)                 log_error "Argumen tidak dikenal: $1"; print_help; exit 1 ;;
    esac
    shift
  done
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log_error "Missing: $1"; exit 1; }
}

require_path() {
  [[ -e "$1" ]] || { log_error "Path tidak ada: $1"; exit 1; }
}

load_config() {
  log_step "Memuat konfigurasi"
  require_path "${CONFIG_FILE}"
  source "${CONFIG_FILE}"
  PROJECT_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  PROJECT_BUILD_BRANCH="$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  log_info "Project: ${PROJECT_NAME} ${PROJECT_VERSION} (${PROJECT_CODENAME})"
  log_info "Base:    ${BASE_DISTRO} ${BASE_DISTRO_VERSION} / Debian ${DEBIAN_CODENAME} / ${BASE_ARCH}"
}

validate_environment() {
  log_step "Validasi environment"
  local req=(bash git find sed)
  for cmd in "${req[@]}"; do require_cmd "${cmd}"; done
  require_path "${PROJECT_ROOT}/config"
  if [[ "${DRY_RUN}" == "false" ]]; then
    local build_tools=(debootstrap lb xorriso)
    for cmd in "${build_tools[@]}"; do require_cmd "${cmd}"; done
    if [[ "$(id -u)" != "0" ]]; then
      log_warn "Build butuh root. Jalankan: sudo ./build.sh --no-dry-run"; exit 1
    fi
    # Cek live-build version
    local ver
    ver=$(dpkg-query -f '${Version}' -W live-build 2>/dev/null || echo "0")
    if dpkg --compare-versions "$ver" lt "1:20230502"; then
      log_error "Need live-build >= 1:20230502, have $ver"; exit 1
    fi
  fi
  log_info "Environment OK"
}

prepare_dirs() {
  mkdir -p "${PROJECT_ROOT}/${BUILD_DIR}"
  mkdir -p "${PROJECT_ROOT}/${UPSTREAM_DIR}"
  mkdir -p "${PROJECT_ROOT}/${LOG_DIR}"
}

clone_upstream() {
  local target="${PROJECT_ROOT}/${UPSTREAM_DIR}/live-build-config"
  if [[ -d "${target}/.git" ]]; then
    log_info "Upstream sudah ada di ${target}"
    return 0
  fi
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Akan clone: ${BASE_DISTRO_URL} -> ${target}"; return 0
  fi
  log_info "Cloning ${BASE_DISTRO_URL}..."
  git clone --depth 1 --branch "2.1-debian12-final" "${BASE_DISTRO_URL}" "${target}"
  log_info "Clone selesai"
}

run_build() {
  local upstream="${PROJECT_ROOT}/${UPSTREAM_DIR}/live-build-config"
  local work_dir="${PROJECT_ROOT}/${BUILD_DIR}/work-${BASE_ARCH}"

  log_step "Setup working directory"
  rm -rf "${work_dir}"
  mkdir -p "${work_dir}"

  # 1. Copy upstream build system
  log_info "Copy upstream live-build config"
  cp -r "${upstream}/auto" "${work_dir}/"
  cp -r "${upstream}/lingmo-config" "${work_dir}/"
  cp "${upstream}/.getopt.sh" "${work_dir}/" 2>/dev/null || true

  # 2. Apply mixos branding overrides
  log_info "Apply mixos branding"

  # --- Bootloader branding ---
  sed -i 's/Lingmo Linux/mixos/g; s/Lingmo/mixos/g' \
    "${work_dir}/lingmo-config/common/bootloaders/grub-pc/grub.cfg" 2>/dev/null || true

  # --- ISO metadata ---
  sed -i 's/Lingmo Linux/mixos/g; s/Lingmo Live/MIXOS Live/g' \
    "${work_dir}/auto/config" 2>/dev/null || true

  # 3. Add mixos hooks
  local hooks_dir="${work_dir}/lingmo-config/common/hooks/live"
  mkdir -p "${hooks_dir}"

  # Hook: mixos-setup
  log_info "Generate chroot hooks"
  cat > "${hooks_dir}/mixos-setup.chroot" <<HOOK
#!/usr/bin/env bash
set -euo pipefail
HOOK_NAME="mixos-setup"
log_info()  { printf "[%s] [INFO]  %s\n"  "\$(date +%H:%M:%S)" "\$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "\$(date +%H:%M:%S)" "\$*" >&2; }
log_info "=== \${HOOK_NAME} ==="

cat > /etc/os-release <<OSEOF
NAME="${PROJECT_NAME}"
PRETTY_NAME="${PROJECT_DISPLAY_NAME} ${PROJECT_PRETTY_VERSION}"
ID="${PROJECT_NAME}"
ID_LIKE="lingmo debian"
VERSION="${PROJECT_PRETTY_VERSION}"
VERSION_ID="${PROJECT_VERSION_ID}"
VERSION_CODENAME="${PROJECT_CODENAME}"
HOME_URL="https://github.com/ekohe/mixos"
SUPPORT_URL="https://github.com/ekohe/mixos/issues"
BUG_REPORT_URL="https://github.com/ekohe/mixos/issues/new"
OSEOF

echo "${PROJECT_DEFAULT_HOSTNAME}" > /etc/hostname

mkdir -p /etc/gtk-3.0 /etc/gtk-4.0
cat > /etc/gtk-3.0/settings.ini <<GTK
[Settings]
gtk-theme-name=mixos-gtk
gtk-icon-theme-name=mixos-icons
gtk-cursor-theme-name=mixos-cursors
gtk-font-name=Inter 10.5
gtk-application-prefer-dark-theme=true
gtk-decoration-layout=close,minimize,maximize:menu
GTK

cat > /etc/gtk-4.0/settings.ini <<GTK4
[Settings]
gtk-theme-name=mixos-gtk
gtk-icon-theme-name=mixos-icons
gtk-cursor-theme-name=mixos-cursors
gtk-font-name=Inter 10.5
gtk-application-prefer-dark-theme=1
GTK4

log_info "\${HOOK_NAME} selesai"
HOOK
  chmod +x "${hooks_dir}/mixos-setup.chroot"

  # Hook: mixos-cleanup
  cat > "${hooks_dir}/mixos-cleanup.chroot" <<CLN
#!/usr/bin/env bash
set -euo pipefail
HOOK_NAME="mixos-cleanup"
log_info()  { printf "[%s] [INFO]  %s\n"  "\$(date +%H:%M:%S)" "\$*"; }
log_info "=== \${HOOK_NAME} ==="
apt-get clean
rm -rf /var/lib/apt/lists/* /usr/share/doc/* /usr/share/man/*
rm -f /root/.bash_history /home/*/.bash_history
find /var/log -type f -name '*.log' -delete 2>/dev/null || true
truncate -s 0 /etc/machine-id 2>/dev/null || true
rm -f /var/lib/dbus/machine-id /etc/ssh/ssh_host_*
log_info "Cleanup selesai"
CLN
  chmod +x "${hooks_dir}/mixos-cleanup.chroot"

  # 4. Add mixos package list
  log_info "Generate mixos package list"
  local pkgs_dir="${work_dir}/lingmo-config/common/package-lists"
  mkdir -p "${pkgs_dir}"
  if [[ -f "${PROJECT_ROOT}/config/packages.list" ]]; then
    grep -vE '^\s*(#|$)' "${PROJECT_ROOT}/config/packages.list" \
      | grep -vE 'mixos-' \
      | awk '{print $1}' \
      > "${pkgs_dir}/mixos-packages.list.chroot" || true
    log_info "Packages: $(wc -l < "${pkgs_dir}/mixos-packages.list.chroot")"
  fi

  # 5. Add mixos branding includes
  log_info "Setup includes.chroot"
  local inc="${work_dir}/lingmo-config/common/includes.chroot"
  mkdir -p "${inc}/usr/share/mixos-branding/logo"
  mkdir -p "${inc}/usr/share/mixos-branding/wallpaper"
  mkdir -p "${inc}/usr/share/backgrounds/mixos"
  mkdir -p "${inc}/etc"

  [[ -f "${PROJECT_ROOT}/branding/logo/mixos-logo.svg" ]] && \
    cp "${PROJECT_ROOT}/branding/logo/mixos-logo.svg" "${inc}/usr/share/mixos-branding/logo/"
  [[ -f "${PROJECT_ROOT}/branding/wallpaper/mixos-default.svg" ]] && \
    cp "${PROJECT_ROOT}/branding/wallpaper/mixos-default.svg" "${inc}/usr/share/backgrounds/mixos/"
  [[ -f "${PROJECT_ROOT}/branding/wallpaper/mixos-dark.svg" ]] && \
    cp "${PROJECT_ROOT}/branding/wallpaper/mixos-dark.svg" "${inc}/usr/share/backgrounds/mixos/"
  echo "${PROJECT_DEFAULT_HOSTNAME}" > "${inc}/etc/hostname"

  # 6. Run live-build
  cd "${work_dir}"

  log_step "lb clean"
  lb clean --purge 2>&1 | while IFS= read -r line; do log_info "  ${line}"; done

  log_step "lb config"
  # Use LingmoOS-style auto/config but with our distribution
  DEBIAN_FRONTEND=noninteractive \
  lb config noauto \
    --distribution "${DEBIAN_CODENAME}" \
    --debian-installer-distribution "${DEBIAN_CODENAME}" \
    --archive-areas "main contrib non-free non-free-firmware" \
    --apt-recommends false \
    --apt-indices false \
    --apt-options "-o DPkg::Options::=\"--force-confnew\" -y" \
    --updates true \
    --backports true \
    --source false \
    --firmware-binary true \
    --firmware-chroot true \
    --uefi-secure-boot enable \
    --initramfs live-boot \
    --mirror-bootstrap "http://deb.debian.org/debian" \
    --mirror-binary "http://deb.debian.org/debian" \
    --mirror-debian-installer "http://deb.debian.org/debian" \
    --iso-application "mixos" \
    --iso-publisher "mixos" \
    --iso-volume "MIXOS" \
    --linux-packages "linux-image linux-headers" \
    --memtest memtest86+ \
    --bootappend-live "boot=live components quiet splash noeject" \
    --bootappend-live-failsafe "boot=live components noeject memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal" \
    --debootstrap-options "--include=apt-transport-https,ca-certificates,openssl" \
    --security false \
    --win32-loader false \
    -a "${BASE_ARCH}"

  log_step "lb build"
  log_warn "Build akan memakan waktu 2-6 jam..."
  echo "---[ live-build output start ]---"
  lb build 2>&1
  echo "---[ live-build output end ]---"

  # 7. Move ISO to builds/
  log_step "Move ISO output"
  local iso_file
  iso_file="$(find . -maxdepth 1 -name 'live-image-*.hybrid.iso' -type f | head -1)"
  if [[ -z "${iso_file}" ]]; then
    log_error "ISO tidak ditemukan!"; ls -la; exit 1
  fi

  local yyyymmdd
  yyyymmdd="$(date +%Y%m%d)"
  local output_name="${PROJECT_NAME}-${PROJECT_CODENAME}-${PROJECT_VERSION_ID}-${BASE_ARCH}.${yyyymmdd}.iso"
  local output_dir="${PROJECT_ROOT}/${BUILD_DIR}"
  mkdir -p "${output_dir}"

  log_info "Move: ${iso_file} -> ${output_dir}/${output_name}"
  mv "${iso_file}" "${output_dir}/${output_name}"
  cd "${output_dir}"
  sha256sum "${output_name}" > "${output_name}.sha256"
  md5sum "${output_name}" > "${output_name}.md5"
  log_info "SHA256: $(cat "${output_name}.sha256")"
}

install_deps() {
  log_step "Install build dependencies"
  local deps=(live-build debootstrap xorriso isolinux syslinux-common
    grub-pc-bin grub-efi-amd64-bin grub-efi-ia32-bin mtools squashfs-tools
    genisoimage curl wget rsync git)
  local missing=()
  for pkg in "${deps[@]}"; do
    if ! dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"; then
      missing+=("${pkg}")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_info "Install missing: ${missing[*]}"
    apt-get update -qq && apt-get install -y --no-install-recommends "${missing[@]}"
  else
    log_info "All deps already installed"
  fi
}

print_summary() {
  log_step "Ringkasan Build"
  echo "Project   : ${PROJECT_NAME} ${PROJECT_VERSION} (${PROJECT_CODENAME})"
  echo "Build     : ${PROJECT_BUILD_DATE}"
  echo "Output    : ${PROJECT_ROOT}/${BUILD_DIR}/"
  echo "Next step : Test ISO dengan test-vm.sh atau VirtualBox"
}

main() {
  parse_args "$@"
  log_step "build.sh — mixos ISO builder (LingmoOS base)"
  load_config
  validate_environment
  prepare_dirs
  clone_upstream
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Build tidak dijalankan. Jalankan: sudo ./build.sh --no-dry-run"
    print_summary
    return 0
  fi
  install_deps
  run_build
  print_summary
  log_info "build.sh selesai"
}

main "$@"
