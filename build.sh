#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="build.sh"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_PATH}"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

DRY_RUN=true
CLEAN=false
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
  --no-dry-run         Jalankan build.
  --clean              Hapus cache & build ulang dari awal (download ulang).
  --skip-upstream      Jangan clone ulang upstream.
  -h, --help           Tampilkan bantuan.

Cache: Secara default build menyimpan cache debootstrap & paket.
       Build ke-2 dan seterusnya jauh lebih cepat & hemat kuota.
       Gunakan --clean untuk build bersih (download ulang).
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)         DRY_RUN=true ;;
      --no-dry-run)      DRY_RUN=false ;;
      --clean)           CLEAN=true ;;
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

setup_config() {
  local work_dir="$1"
  local upstream="${PROJECT_ROOT}/${UPSTREAM_DIR}/live-build-config"

  # Hapus config lama, biarkan cache/ utuh
  rm -rf "${work_dir}/config" "${work_dir}/lingmo-config" "${work_dir}/auto" 2>/dev/null || true

  # Copy upstream config
  cp -r "${upstream}/auto" "${work_dir}/"
  cp -r "${upstream}/lingmo-config" "${work_dir}/"
  cp "${upstream}/.getopt.sh" "${work_dir}/" 2>/dev/null || true

  # Bootloader branding
  sed -i 's/Lingmo Linux/mixos/g; s/Lingmo/mixos/g' \
    "${work_dir}/lingmo-config/common/bootloaders/grub-pc/grub.cfg" 2>/dev/null || true

  # Fix archive files in lingmo-config (source config, not just config/)
  # The auto/config script recopies from lingmo-config/common during lb build
  local src_archives_dir="${work_dir}/lingmo-config/common/archives"
  mkdir -p "${src_archives_dir}"
  cat > "${src_archives_dir}/lingmo_pkg.list.chroot" <<ARCHIVE
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
  cat > "${src_archives_dir}/lingmo_pkg.list.binary" <<ARCHIVE
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
  log_info "Fixed archive files in lingmo-config/common/archives"

  # Create debian-cd symlink for forky -> sid (required by live-build)
  local live_build_data="/usr/share/live/build/data/debian-cd"
  if [[ ! -e "${live_build_data}/${DEBIAN_CODENAME}" ]]; then
    ln -sf sid "${live_build_data}/${DEBIAN_CODENAME}" 2>/dev/null || \
      log_warn "Cannot create debian-cd symlink for ${DEBIAN_CODENAME} (try: sudo ln -sf sid ${live_build_data}/${DEBIAN_CODENAME})"
  fi

  # Replace auto/config with a clean wrapper — bypass upstream complexity
  # (jq dependency, IP-country detection, debian-cd symlink, archive overwrite)
  cat > "${work_dir}/auto/config" << AUTOCFG
#!/bin/bash
set -e

# Create debian-cd symlink if needed (forky -> sid)
dist="\${LB_DISTRIBUTION:-forky}"
if [ ! -e /usr/share/live/build/data/debian-cd/"\$dist" ]; then
  if [ -w /usr/share/live/build/data/debian-cd ]; then
    ln -sf sid /usr/share/live/build/data/debian-cd/"\$dist"
  fi
fi

# Re-apply our custom archive files (they may get overwritten)
mkdir -p config/archives
cat > config/archives/lingmo_pkg.list.chroot << 'ARCHIVE'
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
cat > config/archives/lingmo_pkg.list.binary << 'ARCHIVE'
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE

# Always use forky distribution
exec lb config noauto --distribution forky "\$@"
AUTOCFG
  chmod +x "${work_dir}/auto/config"
  log_info "Replaced auto/config with clean wrapper"

  # Hooks
  local hooks_dir="${work_dir}/lingmo-config/common/hooks/live"
  mkdir -p "${hooks_dir}"

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

  # Package list
  local pkgs_dir="${work_dir}/lingmo-config/common/package-lists"
  mkdir -p "${pkgs_dir}"
  if [[ -f "${PROJECT_ROOT}/config/packages.list" ]]; then
    grep -vE '^\s*(#|$)' "${PROJECT_ROOT}/config/packages.list" \
      | grep -vE 'mixos-' \
      | awk '{print $1}' \
      > "${pkgs_dir}/mixos-packages.list.chroot" || true
    log_info "Packages: $(wc -l < "${pkgs_dir}/mixos-packages.list.chroot") extra"
  fi

  # Branding includes
  local inc="${work_dir}/lingmo-config/common/includes.chroot_after_packages"
  mkdir -p "${inc}/usr/share/mixos-branding/logo" "${inc}/usr/share/backgrounds/mixos" "${inc}/etc"
  [[ -f "${PROJECT_ROOT}/branding/logo/mixos-logo.svg" ]] && \
    cp "${PROJECT_ROOT}/branding/logo/mixos-logo.svg" "${inc}/usr/share/mixos-branding/logo/"
  [[ -f "${PROJECT_ROOT}/branding/wallpaper/mixos-default.svg" ]] && \
    cp "${PROJECT_ROOT}/branding/wallpaper/mixos-default.svg" "${inc}/usr/share/backgrounds/mixos/"
  [[ -f "${PROJECT_ROOT}/branding/wallpaper/mixos-dark.svg" ]] && \
    cp "${PROJECT_ROOT}/branding/wallpaper/mixos-dark.svg" "${inc}/usr/share/backgrounds/mixos/"
  echo "${PROJECT_DEFAULT_HOSTNAME}" > "${inc}/etc/hostname"

  # Copy ke config/ (LingmoOS pattern)
  cp -rT "${work_dir}/lingmo-config/common" "${work_dir}/config"
  local variant_src="${work_dir}/lingmo-config/variant-default"
  if [[ -L "${variant_src}" ]]; then
    variant_src="$(readlink -f "${variant_src}")"
    log_info "Variant symlink resolved: variant-default -> ${variant_src}"
  fi
  cp -rT "${variant_src}" "${work_dir}/config" 2>/dev/null || true

  # Fix OBS repo URL & bypass GPG v3 rejection
  local archives_dir="${work_dir}/config/archives"
  mkdir -p "${archives_dir}"
  cat > "${archives_dir}/lingmo_pkg.list.chroot" <<ARCHIVE
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
  cat > "${archives_dir}/lingmo_pkg.list.binary" <<ARCHIVE
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
  log_info "Created archive files with correct OBS repo URL"

  # Fix package lists — remove packages not available in OBS repo or Debian Forky
  for list_file in "${work_dir}"/config/package-lists/*.list.chroot; do
    [[ -f "${list_file}" ]] || continue
    sed -i \
      -e '/^lingmo-base-files/d' \
      -e '/^lingmo-workspace-base/d' \
      -e '/^lingmo-plymouth/d' \
      -e '/^lingmo-grub-config/d' \
      -e '/^lingmo-live/d' \
      -e '/^lingmo-screenshot/d' \
      -e '/^neofetch/d' \
      -e '/^firmware-/d' \
      -e '/^bluez-firmware/d' \
      -e '/^broadcom-/d' \
      -e '/^reiserfsprogs/d' \
      -e '/^packagekit-tools/d' \
      -e '/^qml-module-org/d' \
      "${list_file}"
  done

  # Rewrite variant package list with verified available packages
  local variant_pkgs="${work_dir}/config/package-lists/lingmo.list.chroot"
  if [[ -f "${variant_pkgs}" ]]; then
    cat > "${variant_pkgs}" <<LINGMO_LIST
# LingmoOS packages (available in OBS CI repo)
liblingmo
lingmoui3
lingmo-core
lingmo-dock
lingmo-filemanager
lingmo-kwin-plugins
lingmo-kwin-plugins-roundedwindow
lingmo-launcher
lingmo-sddm-theme
lingmo-settings
lingmo-statusbar
lingmo-systemicons
lingmo-wallpapers
lingmo-calculator

# Display & window manager
sddm
xorg
kwin-x11
konsole
plymouth

# Live & utils
live-boot
gparted
dirmngr
kscreen
sound-theme-freedesktop
sudo
parted

# Apps
firefox-esr
firefox-esr-l10n-zh-cn

# Input & fonts
fcitx5
fcitx5-chinese-addons
fonts-noto-cjk
LINGMO_LIST
    log_info "Rewrote variant package list: lingmo.list.chroot"
  fi

  # Binary-only package list cleanup
  for list_file in "${work_dir}"/config/package-lists/*.list.binary; do
    [[ -f "${list_file}" ]] || continue
    sed -i \
      -e '/^neofetch/d' \
      "${list_file}"
  done
}

build_stub_pkgs() {
  local work_dir="$1"
  local pkgs_dir="${work_dir}/config/packages.chroot"
  local stub_base="qt6-base-private-abi-stub"
  local stub_decl="qt6-declarative-private-abi-stub"

  mkdir -p "${pkgs_dir}"

  # Build qt6-base-private-abi stub
  if ! ls "${pkgs_dir}/${stub_base}"*.deb >/dev/null 2>&1; then
    log_info "Building ${stub_base} (provides qt6-base-private-abi = 6.9.2)"
    local ctrl="/tmp/lingmo-stub-base.control"
    cat > "${ctrl}" << EOF
Section: misc
Priority: optional
Standards-Version: 4.6.0
Package: ${stub_base}
Version: 6.9.2
Provides: qt6-base-private-abi (= 6.9.2)
Architecture: all
Description: Stub for qt6-base-private-abi (= 6.9.2) Lingmo OBS compat
EOF
    pushd /tmp >/dev/null
    equivs-build "${ctrl}"
    popd >/dev/null
    cp /tmp/${stub_base}_*.deb "${pkgs_dir}/"
    rm -f "${ctrl}" /tmp/${stub_base}_*.deb
  fi

  # Build qt6-declarative-private-abi stub
  if ! ls "${pkgs_dir}/${stub_decl}"*.deb >/dev/null 2>&1; then
    log_info "Building ${stub_decl} (provides qt6-declarative-private-abi = 6.9.2)"
    local ctrl="/tmp/lingmo-stub-decl.control"
    cat > "${ctrl}" << EOF
Section: misc
Priority: optional
Standards-Version: 4.6.0
Package: ${stub_decl}
Version: 6.9.2
Provides: qt6-declarative-private-abi (= 6.9.2)
Architecture: all
Description: Stub for qt6-declarative-private-abi (= 6.9.2) Lingmo OBS compat
EOF
    pushd /tmp >/dev/null
    equivs-build "${ctrl}"
    popd >/dev/null
    cp /tmp/${stub_decl}_*.deb "${pkgs_dir}/"
    rm -f "${ctrl}" /tmp/${stub_decl}_*.deb
  fi

  log_info "Stub packages placed in config/packages.chroot/"
}

build_lingmo_settings() {
  local work_dir="$1"
  local pkgs_dir="${work_dir}/config/packages.chroot"
  local build_chroot="/var/cache/mixos-build-chroot"

  if ls "${pkgs_dir}"/lingmo-settings*.deb >/dev/null 2>&1; then
    log_info "lingmo-settings already built, skipping"
    return 0
  fi

  if [ ! -d "${build_chroot}" ]; then
    log_info "Creating Forky build chroot..."
    mmdebstrap --variant=buildd --format=directory \
      --include="build-essential,devscripts,cmake,extra-cmake-modules,git,ca-certificates,pkg-config" \
      forky "${build_chroot}" http://deb.debian.org/debian
    mount --bind /proc "${build_chroot}/proc"
    mount --bind /dev "${build_chroot}/dev"
    mount --bind /sys "${build_chroot}/sys"
    cp /etc/resolv.conf "${build_chroot}/etc/resolv.conf"
  fi

  # Add OBS repo and stub packages to build chroot
  mkdir -p "${build_chroot}/etc/apt/sources.list.d"
  echo "deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./" \
    > "${build_chroot}/etc/apt/sources.list.d/lingmo-obs.list"
  mkdir -p "${build_chroot}/tmp/pkgs"
  cp "${pkgs_dir}"/*.deb "${build_chroot}/tmp/pkgs/"

  chroot "${build_chroot}" bash -c "
    apt-get update -qq 2>&1 | tail -3 || true
    # Install stub packages FIRST to satisfy ABI deps
    dpkg -i /tmp/pkgs/*.deb 2>&1 | tail -3 || true
    apt-get install -f -y 2>&1 | tail -3 || true
    # Now install OBS packages and build deps
    apt-get install -y --no-install-recommends -o DPkg::Options::=--force-confnew \
      liblingmo lingmoui3 libkf6config-dev libkf6networkmanagerqt-dev \
      libkf6modemmanagerqt-dev libkf6bluezqt-dev libkf6kio-dev libkscreen-dev \
      qt6-base-dev qt6-declarative-dev qt6-tools-dev qt6-tools-dev-tools qt6-5compat-dev \
      2>&1 | tail -10
  " 2>&1 | tail -5

  # Clone and build lingmo-settings
  if [ ! -d "${build_chroot}/src/lingmo-settings" ]; then
    chroot "${build_chroot}" git clone --depth 1 \
      https://github.com/LingmoOS/lingmo-settings.git /src/lingmo-settings
  fi

  # Install build deps from debian/control
  chroot "${build_chroot}" bash -c "cd /src/lingmo-settings && \
    mk-build-deps -i -t 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y' debian/control 2>&1 | tail -5" || true

  # Install extra private Qt deps not in debian/control
  chroot "${build_chroot}" apt-get install -y --no-install-recommends \
    qt6-base-private-dev libxcb-errors-dev 2>&1 | tail -3

  # Patch CMakeLists.txt: Qt6GuiPrivate not auto-loaded in Qt 6.10
  if ! grep -q 'find_package(Qt6GuiPrivate' "${build_chroot}/src/lingmo-settings/CMakeLists.txt" 2>/dev/null; then
    sed -i 's/find_package(LingmoLogger REQUIRED)/find_package(LingmoLogger REQUIRED)\nfind_package(Qt6GuiPrivate REQUIRED)/' \
      "${build_chroot}/src/lingmo-settings/CMakeLists.txt"
  fi

  # Fix invalid date in debian/changelog (Tue, 46 Jul 2024)
  sed -i 's/Tue, 46 Jul 2024/Tue, 30 Jul 2024/' \
    "${build_chroot}/src/lingmo-settings/debian/changelog"

  # Build
  chroot "${build_chroot}" bash -c "cd /src/lingmo-settings && dpkg-buildpackage -b -uc -us 2>&1 | tail -5"

  # Copy result
  cp "${build_chroot}/src/"lingmo-settings*.deb "${pkgs_dir}/" 2>/dev/null || true
  log_info "lingmo-settings built and placed in config/packages.chroot/"
}

run_build() {
  local upstream="${PROJECT_ROOT}/${UPSTREAM_DIR}/live-build-config"
  local work_dir="${PROJECT_ROOT}/${BUILD_DIR}/work-${BASE_ARCH}"

  log_step "Setup working directory"
  if [[ "${CLEAN}" == "true" || ! -d "${work_dir}/cache" ]]; then
    log_info "Clean build: hapus work dir"
    rm -rf "${work_dir}"
    mkdir -p "${work_dir}"
  else
    log_info "Cache ditemukan, pakai build incremental (--clean untuk bersih)"
  fi

  setup_config "${work_dir}"
  cd "${work_dir}"

  log_step "lb config"
  DEBIAN_FRONTEND=noninteractive \
  lb config noauto \
    --distribution "${DEBIAN_CODENAME}" \
    --debian-installer-distribution "${DEBIAN_CODENAME}" \
    --archive-areas "main contrib non-free non-free-firmware" \
    --apt-recommends false \
    --apt-indices false \
    --apt-options "-o DPkg::Options::=\"--force-confnew\" -o Acquire::Check-Valid-Until=false -y" \
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
    --memtest none \
    --bootappend-live "boot=live components noeject" \
    --bootappend-live-failsafe "boot=live components noeject memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal" \
    --debootstrap-options "--include=apt-transport-https,ca-certificates,openssl" \
    --security false \
    --win32-loader false \
    --cache-packages true \
    --cache-stages bootstrap \
    -a "${BASE_ARCH}"

  # Remove ALL stale chroot stage stamps so all stages re-run
  # with correct repos (preserves bootstrap cache, avoids full redownload)
  rm -f "${work_dir}"/.build/chroot_* \
        "${work_dir}"/.build/bootstrap* \
        2>/dev/null || true
  log_info "Removed stale chroot stamps, bootstrap cache preserved"

  build_stub_pkgs "${work_dir}"
  build_lingmo_settings "${work_dir}"

  log_step "lb build"
  echo "---[ live-build output start ]---"
  lb build 2>&1
  echo "---[ live-build output end ]---"

  log_step "Move ISO output"
  local iso_file
  iso_file="$(find . -maxdepth 1 -name 'live-image-*.hybrid.iso' -type f | head -1)"
  if [[ -z "${iso_file}" ]]; then
    log_error "ISO tidak ditemukan!"; ls -la "${work_dir}"; exit 1
  fi
  local yyyymmdd
  yyyymmdd="$(date +%Y%m%d)"
  local output_name="${PROJECT_NAME}-${PROJECT_CODENAME}-${PROJECT_VERSION_ID}-${BASE_ARCH}.${yyyymmdd}.iso"
  local output_dir="${PROJECT_ROOT}/${BUILD_DIR}"
  mkdir -p "${output_dir}"
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
    genisoimage curl wget rsync git equivs mmdebstrap)
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
