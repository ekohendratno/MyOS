#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_PATH}/.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

FORCE=false
CHECK_ONLY=false
BOOTSTRAP_TOOLS=true
GIT_TIMEOUT_SECONDS="${GIT_TIMEOUT_SECONDS:-180}"

log_info() { printf "[%s] [INFO]  %s\n" "$(date +%H:%M:%S)" "$*"; }
log_warn() { printf "[%s] [WARN]  %s\n" "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n" "$(date +%H:%M:%S)" "$*" >&2; }

run_git() {
  GIT_TERMINAL_PROMPT=0 timeout "${GIT_TIMEOUT_SECONDS}" git "$@"
}

print_help() {
  cat <<'EOF'
build-lingmo-source.sh - build LingmoOS desktop packages from source

Usage:
  scripts/build-lingmo-source.sh [options]

Options:
  --force               Rebuild even when source package cache is current.
  --check-only          Validate tools/source layout, do not build packages.
  --no-bootstrap-tools  Do not build lingmo-pkgbuild automatically.
  -h, --help            Show this help.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) FORCE=true ;;
      --check-only) CHECK_ONLY=true ;;
      --no-bootstrap-tools) BOOTSTRAP_TOOLS=false ;;
      -h|--help) print_help; exit 0 ;;
      *) log_error "Unknown argument: $1"; print_help; exit 1 ;;
    esac
    shift
  done
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "Missing command: $1"
    return 1
  }
}

load_config() {
  [[ -f "${CONFIG_FILE}" ]] || {
    log_error "Config not found: ${CONFIG_FILE}"
    exit 1
  }
  # shellcheck source=/dev/null
  source "${CONFIG_FILE}"

  LINGMO_SOURCE_URL="${LINGMO_SOURCE_URL:-https://github.com/LingmoOS/LingmoOS.git}"
  LINGMO_SOURCE_BRANCH="${LINGMO_SOURCE_BRANCH:-main}"
  LINGMO_SOURCE_DIR="${LINGMO_SOURCE_DIR:-upstream/LingmoOS}"
  LINGMO_SOURCE_OUT_DIR="${LINGMO_SOURCE_OUT_DIR:-artifacts/lingmo-source-debs}"
  LINGMO_SOURCE_BUILD_THIRD_PARTY="${LINGMO_SOURCE_BUILD_THIRD_PARTY:-false}"
  LINGMO_PKGBUILD_URL="${LINGMO_PKGBUILD_URL:-https://github.com/LingmoOS/lingmo-pkgbuild.git}"
  LINGMO_SOURCE_EXCLUDE_DIRS="${LINGMO_SOURCE_EXCLUDE_DIRS:-global OCRServer VideoPlayer Texteditor Notepad Calculator SystemMonitor UpdateTool ScreenShots kgpg-22.12.3 sweeper-3.0.2+lingmo3build1 fcitx5-5.1.12 kscreen osd lingmo-framework lingmo-shell libsys libsysui}"
  LINGMO_SOURCE_REQUIRED_DEBS="${LINGMO_SOURCE_REQUIRED_DEBS:-lingmo-core appmotor lingmo-desktop lingmo-dock lingmo-launcher lingmo-statusbar lingmo-settings lingmo-systemicons lingmo-wallpapers lingmo-filemanager}"
  LINGMO_SOURCE_PREBUILD_DIRS="${LINGMO_SOURCE_PREBUILD_DIRS:-lib/libsys lib/libsysui}"
  LINGMO_SOURCE_DEFAULT_DIRS="${LINGMO_SOURCE_DEFAULT_DIRS:-Icons}"
  UPSTREAM_DIR="${UPSTREAM_DIR:-upstream}"
  ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts}"

  SOURCE_DIR="${PROJECT_ROOT}/${LINGMO_SOURCE_DIR}"
  OUT_DIR="${PROJECT_ROOT}/${LINGMO_SOURCE_OUT_DIR}"
  PKGBUILD_DIR="${PROJECT_ROOT}/${UPSTREAM_DIR}/lingmo-pkgbuild"
  TOOL_BIN_DIR="${PROJECT_ROOT}/${ARTIFACT_DIR}/tools/bin"
  IFS=' ' read -r -a EXCLUDE_DIRS <<< "${LINGMO_SOURCE_EXCLUDE_DIRS}"
  IFS=' ' read -r -a PREBUILD_DIRS <<< "${LINGMO_SOURCE_PREBUILD_DIRS}"
  IFS=' ' read -r -a REQUIRED_DEBS <<< "${LINGMO_SOURCE_REQUIRED_DEBS}"
  IFS=' ' read -r -a DEFAULT_BUILD_DIRS <<< "${LINGMO_SOURCE_DEFAULT_DIRS}"
}

ensure_debian_build_tools() {
  local missing=()
  local cmd

  for cmd in dpkg-buildpackage mk-build-deps dpkg-scanpackages; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing+=("${cmd}")
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    log_info "Installing Debian package build helpers"
    apt-get update -qq
    apt-get install -y --no-install-recommends devscripts equivs dpkg-dev
  fi
}

clone_or_update() {
  local url="$1"
  local branch="$2"
  local target="$3"
  local name="$4"

  mkdir -p "$(dirname "${target}")"
  if [[ -d "${target}/.git" ]]; then
    log_info "${name} already exists: ${target}"
    run_git -C "${target}" fetch --depth 1 origin "${branch}" || {
      log_warn "Cannot update ${name}; using existing checkout"
      return 0
    }
    run_git -C "${target}" checkout "${branch}" >/dev/null 2>&1 || true
    run_git -C "${target}" pull --ff-only origin "${branch}" || \
      log_warn "${name} has local changes or non-fast-forward history; using existing checkout"
    return 0
  fi

  log_info "Cloning ${name}: ${url} (${branch})"
  run_git clone --depth 1 --branch "${branch}" "${url}" "${target}"
}

ensure_lingmo_pkgbuild() {
  if command -v lingmo-pkgbuild >/dev/null 2>&1; then
    export PATH="$(dirname "$(command -v lingmo-pkgbuild)"):${PATH}"
    log_info "Using system lingmo-pkgbuild: $(command -v lingmo-pkgbuild)"
    return 0
  fi

  if [[ -x "${TOOL_BIN_DIR}/lingmo-pkgbuild" ]]; then
    export PATH="${TOOL_BIN_DIR}:${PATH}"
    log_info "Using cached lingmo-pkgbuild: ${TOOL_BIN_DIR}/lingmo-pkgbuild"
    return 0
  fi

  if [[ "${BOOTSTRAP_TOOLS}" != "true" ]]; then
    log_error "lingmo-pkgbuild is required but not installed"
    return 1
  fi

  require_cmd git
  require_cmd cmake
  require_cmd make
  require_cmd g++

  clone_or_update "${LINGMO_PKGBUILD_URL}" "main" "${PKGBUILD_DIR}" "lingmo-pkgbuild"

  log_info "Building lingmo-pkgbuild helper"
  cmake -S "${PKGBUILD_DIR}" -B "${PKGBUILD_DIR}/build" -DCMAKE_BUILD_TYPE=Release
  cmake --build "${PKGBUILD_DIR}/build" --parallel "$(nproc 2>/dev/null || echo 2)"

  mkdir -p "${TOOL_BIN_DIR}"
  cp "${PKGBUILD_DIR}/build/lingmo-pkgbuild" "${TOOL_BIN_DIR}/"
  if [[ -x "${PKGBUILD_DIR}/build/lingmo-repotool" ]]; then
    cp "${PKGBUILD_DIR}/build/lingmo-repotool" "${TOOL_BIN_DIR}/"
  fi
  chmod +x "${TOOL_BIN_DIR}/lingmo-pkgbuild" "${TOOL_BIN_DIR}/lingmo-repotool" 2>/dev/null || true
  export PATH="${TOOL_BIN_DIR}:${PATH}"
  log_info "Cached lingmo-pkgbuild at ${TOOL_BIN_DIR}"
}

current_source_commit() {
  git -C "${SOURCE_DIR}" rev-parse HEAD 2>/dev/null || echo "unknown"
}

source_cache_current() {
  local stamp="${OUT_DIR}/.source-commit"
  local commit
  local required_pkg
  commit="$(current_source_commit)"

  [[ "${FORCE}" != "true" ]] || return 1
  [[ -f "${stamp}" ]] || return 1
  [[ "$(cat "${stamp}")" == "${commit}" ]] || return 1
  compgen -G "${OUT_DIR}/*.deb" >/dev/null || return 1
  for required_pkg in "${REQUIRED_DEBS[@]}"; do
    [[ -n "${required_pkg}" ]] || continue
    compgen -G "${OUT_DIR}/${required_pkg}_*.deb" >/dev/null || return 1
  done
  return 0
}

write_package_index() {
  mkdir -p "${OUT_DIR}"
  (
    cd "${OUT_DIR}"
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    find . -maxdepth 1 -type f -name '*.deb' -printf '%f\n' | sort > manifest.txt
  )
}

package_available() {
  apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ { found=1; ok=($2 != "(none)") } END { exit !(found && ok) }'
}

patch_control_dependency() {
  local control_file="$1"
  local old_pkg="$2"
  local new_pkg="$3"

  [[ -f "${control_file}" ]] || return 0
  grep -q "${old_pkg}" "${control_file}" || return 0

  if package_available "${old_pkg}"; then
    return 0
  fi

  if package_available "${new_pkg}"; then
    log_info "Replacing unavailable build dependency ${old_pkg} -> ${new_pkg}"
    sed -i "s/${old_pkg}/${new_pkg}/g" "${control_file}"
    return 0
  fi

  log_warn "Build dependency ${old_pkg} is unavailable and replacement ${new_pkg} was not found"
}

remove_control_dependency() {
  local control_file="$1"
  local pkg="$2"

  [[ -f "${control_file}" ]] || return 0
  grep -q "${pkg}" "${control_file}" || return 0

  log_warn "Removing unavailable runtime dependency ${pkg} from ${control_file}"
  sed -Ei \
    -e "/^[[:space:]]*${pkg}([[:space:]]*\\([^)]*\\))?,?[[:space:]]*$/d" \
    -e "s/,[[:space:]]*${pkg}([[:space:]]*\\([^)]*\\))?([,])/,/g" \
    -e "s/${pkg}([[:space:]]*\\([^)]*\\))?,[[:space:]]*//g" \
    "${control_file}"
}

patch_debian_control_compat() {
  local stage_dir="$1"
  local control_file="${stage_dir}/debian/control"

  patch_control_dependency "${control_file}" "libkf5screen-dev" "libkscreen-dev"
  patch_control_dependency "${control_file}" "libkf5screen-bin" "libkscreen-bin"
  patch_control_dependency "${control_file}" "libkdecorations2-dev" "libkdecorations3-dev"
  patch_control_dependency "${control_file}" "libkaccounts-dev" "libkaccounts6-dev"
  patch_control_dependency "${control_file}" "libkf5sysguard-dev" "libksysguard-dev"
  patch_control_dependency "${control_file}" "lingmo-workspace-dev" "plasma-workspace-dev"
  remove_control_dependency "${control_file}" "libkf5kdelibs4support-dev"
  if [[ "${stage_dir}" == */Settings ]]; then
    remove_control_dependency "${control_file}" "lingmo-shell"
  fi
}

patch_lingmo_shell_compat() {
  local stage_dir="$1"
  local cmake_file="${stage_dir}/CMakeLists.txt"
  local kcms_file="${stage_dir}/kcms/CMakeLists.txt"

  [[ "$(basename "${stage_dir}")" == "lingmo-shell" ]] || return 0

  if [[ -f "${cmake_file}" ]] && grep -q "KDELibs4Support" "${cmake_file}"; then
    log_warn "KDELibs4Support is unavailable on this base; disabling lingmo-shell date/time KCM dependency"
    sed -i '/KDELibs4Support/d' "${cmake_file}"
  fi

  if [[ -f "${kcms_file}" ]] && grep -q "dateandtime" "${kcms_file}"; then
    sed -i 's/^[[:space:]]*add_subdirectory *(dateandtime)[[:space:]]*$/# add_subdirectory(dateandtime) # disabled: KF5KDELibs4Support unavailable/' "${kcms_file}"
  fi
}

patch_auto_package_controls() {
  local auto_dir="${SOURCE_DIR}/Build_Pkgs/auto"
  local control_file

  [[ -d "${auto_dir}" ]] || return 0
  while IFS= read -r -d '' control_file; do
    local package_dir
    package_dir="$(dirname "$(dirname "${control_file}")")"
    patch_debian_control_compat "${package_dir}"
    patch_lingmo_shell_compat "${package_dir}"
  done < <(find "${auto_dir}" -path '*/debian/control' -type f -print0)
}

patch_source_tree_controls() {
  local control_file

  while IFS= read -r -d '' control_file; do
    local package_dir
    package_dir="$(dirname "$(dirname "${control_file}")")"
    patch_debian_control_compat "${package_dir}"
    patch_lingmo_shell_compat "${package_dir}"
  done < <(find "${SOURCE_DIR}" -path '*/debian/control' -type f -print0)
}

patch_source_compat() {
  local stage_dir="$1"
  local cmake_file="${stage_dir}/CMakeLists.txt"

  patch_lingmo_shell_compat "${stage_dir}"

  if [[ -f "${stage_dir}/screen/CMakeLists.txt" ]] && ! compgen -G "/usr/lib/*/cmake/KF5Screen/KF5ScreenConfig.cmake" >/dev/null; then
    log_warn "KF5Screen CMake files are unavailable; disabling libsys screen QML plugin for this build"
    sed -i 's/^[[:space:]]*add_subdirectory(screen)[[:space:]]*$/# add_subdirectory(screen) # disabled: KF5Screen unavailable on this base/' "${cmake_file}"
  fi
}

patch_upstream_makefile_compat() {
  local makefile="${SOURCE_DIR}/Makefile"

  [[ -f "${makefile}" ]] || return 0

  # Upstream's build-pkgs shell loop expands to "fi done" with dash unless
  # the closing fi is explicitly terminated before the next continued line.
  if grep -q $'^[\t ]*fi \\\\' "${makefile}" && ! grep -q $'^[\t ]*fi; \\\\' "${makefile}"; then
    log_warn "Patching LingmoOS Makefile build-pkgs loop for POSIX shell parsing"
    sed -i $'s/^[\t ]*fi \\\\/\t\tfi; \\\\/' "${makefile}"
  fi

  # Keep the default package loop in its original working directory. The
  # upstream recipe changes into the first package directory and then the next
  # relative path lookup can fail or leave dash parsing the continued loop
  # incorrectly after the final package.
  if grep -q 'cd "\$\$dir" && \$(DPKG_CMD); \\' "${makefile}"; then
    log_warn "Patching LingmoOS Makefile default package loop to use a subshell"
    sed -i 's|cd "\$\$dir" && $(DPKG_CMD); \\|( cd "$$dir" \&\& $(DPKG_CMD) ); \\|' "${makefile}"
  fi
}

install_stage_build_deps() {
  local stage_dir="$1"

  log_info "Installing build dependencies for ${stage_dir}"
  patch_debian_control_compat "${stage_dir}"
  (
    cd "${stage_dir}"
    mk-build-deps -i -r -t "apt-get -y --no-install-recommends -o Debug::pkgProblemResolver=yes" debian/control
  )
}

install_stage_outputs() {
  local stage_parent="$1"
  local stage_pkg

  while IFS= read -r -d '' stage_pkg; do
    cp "${stage_pkg}" "${OUT_DIR}/"
    case "$(basename "${stage_pkg}")" in
      *-dbgsym_*.deb)
        continue
        ;;
    esac
    log_info "Installing prebuilt package $(basename "${stage_pkg}")"
    if ! dpkg -i "${stage_pkg}"; then
      apt-get -f install -y
      dpkg -i "${stage_pkg}"
    fi
  done < <(find "${stage_parent}" -maxdepth 1 -type f -name '*.deb' -print0)
}

build_selected_default_packages() {
  local jobs="$1"
  local default_dir
  local package_dir

  for default_dir in "${DEFAULT_BUILD_DIRS[@]}"; do
    [[ -n "${default_dir}" ]] || continue
    package_dir="${SOURCE_DIR}/Build_Pkgs/default/${default_dir}"
    if [[ ! -d "${package_dir}" ]]; then
      log_warn "Skipping missing LingmoOS default package directory: ${default_dir}"
      continue
    fi

    log_info "Building LingmoOS default package: ${default_dir}"
    (
      cd "${package_dir}"
      dpkg-buildpackage -j"${jobs}" -us -uc
    )
  done
}

build_debian_stage() {
  local stage_rel="$1"
  local stage_dir="${SOURCE_DIR}/${stage_rel}"
  local stage_parent

  if [[ ! -d "${stage_dir}/debian" ]]; then
    log_warn "Skipping ${stage_rel}: debian/ directory not found"
    return 0
  fi

  patch_source_compat "${stage_dir}"
  stage_parent="$(dirname "${stage_dir}")"
  mkdir -p "${OUT_DIR}"
  rm -f "${stage_parent}"/*.deb "${stage_parent}"/*.buildinfo "${stage_parent}"/*.changes 2>/dev/null || true

  install_stage_build_deps "${stage_dir}"
  log_info "Prebuilding Debian source stage: ${stage_rel}"
  (
    cd "${stage_dir}"
    dpkg-buildpackage -b -uc -us -j"$(nproc 2>/dev/null || echo 2)"
  )
  install_stage_outputs "${stage_parent}"
}

collect_packages() {
  local candidate_dirs=(
    "${SOURCE_DIR}/Target/pkgs_out"
    "${SOURCE_DIR}/pkg_out"
    "${SOURCE_DIR}/Build_Pkgs/pkg_out"
  )
  local copied=0
  local dir

  mkdir -p "${OUT_DIR}"
  find "${OUT_DIR}" -maxdepth 1 -type f \( -name '*.deb' -o -name 'Packages.gz' -o -name 'manifest.txt' \) -delete

  for dir in "${candidate_dirs[@]}"; do
    [[ -d "${dir}" ]] || continue
    while IFS= read -r -d '' deb; do
      cp "${deb}" "${OUT_DIR}/"
      copied=$((copied + 1))
    done < <(find "${dir}" -maxdepth 1 -type f -name '*.deb' -print0)
  done

  if [[ "${copied}" -eq 0 && -d "${SOURCE_DIR}/Build_Pkgs" ]]; then
    while IFS= read -r -d '' deb; do
      cp "${deb}" "${OUT_DIR}/"
      copied=$((copied + 1))
    done < <(find "${SOURCE_DIR}/Build_Pkgs" -type f -name '*.deb' -print0)
  fi

  if [[ "${copied}" -eq 0 ]]; then
    log_error "No .deb packages found after LingmoOS source build"
    log_error "Expected output in ${SOURCE_DIR}/Target/pkgs_out"
    exit 1
  fi

  local missing_required=()
  local required_pkg
  for required_pkg in "${REQUIRED_DEBS[@]}"; do
    [[ -n "${required_pkg}" ]] || continue
    if ! compgen -G "${OUT_DIR}/${required_pkg}_*.deb" >/dev/null; then
      missing_required+=("${required_pkg}")
    fi
  done
  if [[ "${#missing_required[@]}" -gt 0 ]]; then
    log_error "LingmoOS source build did not produce required desktop shell packages: ${missing_required[*]}"
    log_error "Without these packages the ISO falls back to a plain X11 terminal session."
    exit 1
  fi

  write_package_index
  current_source_commit > "${OUT_DIR}/.source-commit"
  log_info "Collected ${copied} LingmoOS source packages into ${OUT_DIR}"
}

build_source_packages() {
  local jobs
  jobs="$(nproc 2>/dev/null || echo 2)"

  if [[ -d "${SOURCE_DIR}/.git" && "${CHECK_ONLY}" != "true" ]] && source_cache_current; then
    log_info "LingmoOS source package cache is current: ${OUT_DIR}"
    return 0
  fi

  clone_or_update "${LINGMO_SOURCE_URL}" "${LINGMO_SOURCE_BRANCH}" "${SOURCE_DIR}" "LingmoOS source"

  if [[ -f "${SOURCE_DIR}/.gitmodules" ]]; then
    local submodule_path
    log_info "Updating LingmoOS submodules declared in .gitmodules"
    while IFS= read -r submodule_path; do
      [[ -n "${submodule_path}" ]] || continue
      run_git -C "${SOURCE_DIR}" submodule update --init --recursive --depth 1 -- "${submodule_path}" || \
        log_warn "Submodule could not be updated: ${submodule_path}"
    done < <(run_git -C "${SOURCE_DIR}" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
  fi

  ensure_lingmo_pkgbuild
  ensure_debian_build_tools
  require_cmd dpkg-scanpackages
  patch_upstream_makefile_compat

  if [[ "${CHECK_ONLY}" == "true" ]]; then
    log_info "Check OK: source tree and build helper are ready"
    return 0
  fi

  if source_cache_current; then
    log_info "LingmoOS source package cache is current: ${OUT_DIR}"
    return 0
  fi

  log_info "Building LingmoOS source packages with ${jobs} jobs"
  (
    cd "${SOURCE_DIR}"
    if [[ "${FORCE}" == "true" ]]; then
      make clean || true
    fi
    patch_source_tree_controls
    make config-pkgs
    patch_auto_package_controls
    for exclude_dir in "${EXCLUDE_DIRS[@]}"; do
      [[ -n "${exclude_dir}" ]] || continue
      rm -rf "${SOURCE_DIR}/Build_Pkgs/auto/${exclude_dir}" 2>/dev/null || true
    done

    local stage_dir stage_pkg
    for stage_dir in "${PREBUILD_DIRS[@]}"; do
      [[ -n "${stage_dir}" ]] || continue
      build_debian_stage "${stage_dir}"
      for stage_pkg in "${OUT_DIR}"/*.deb; do
        [[ -e "${stage_pkg}" ]] || continue
        case "$(basename "${stage_pkg}")" in
          liblingmo_*.deb|lingmoui_*.deb)
            dpkg -i "${stage_pkg}" >/dev/null 2>&1 || apt-get -f install -y >/dev/null 2>&1
            ;;
        esac
      done
    done

    log_info "Building LingmoOS auto package set"
    (
      cd "${SOURCE_DIR}/Build_Pkgs"
      lingmo-pkgbuild -j"${jobs}" auto/
    )
    build_selected_default_packages "${jobs}"
    if [[ "${LINGMO_SOURCE_BUILD_THIRD_PARTY}" == "true" ]]; then
      make third-party CPU_CORES="${jobs}"
    fi
  )

  collect_packages
}

main() {
  parse_args "$@"
  load_config
  build_source_packages
}

main "$@"
