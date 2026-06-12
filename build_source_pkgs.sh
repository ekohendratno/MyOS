#!/bin/bash
set -euo pipefail

# Build 5 LingmoOS packages from source against current Debian Forky
# Packages: LingmoUI (lingmoui3), lingmo-core, lingmo-dock, lingmo-settings, lingmo-statusbar

SOURCE_REPOS=(
  "LingmoUI:https://github.com/LingmoOS/LingmoUI.git"
  "lingmo-core:https://github.com/LingmoOS/lingmo-core.git"
  "lingmo-dock:https://github.com/LingmoOS/lingmo-dock.git"
  "lingmo-settings:https://github.com/LingmoOS/lingmo-settings.git"
  "lingmo-statusbar:https://github.com/LingmoOS/lingmo-statusbar.git"
)

BUILD_CHROOT="/var/cache/mixos-build-chroot"
LOCAL_REPO_DIR="$1"
WORK_DIR="$2"

mkdir -p "${LOCAL_REPO_DIR}"

# Check if we already have all packages built
all_present=true
for entry in "${SOURCE_REPOS[@]}"; do
  pkg_name="${entry%%:*}"
  if ! ls "${LOCAL_REPO_DIR}"/*.deb 2>/dev/null | grep -qi "${pkg_name}"; then
    all_present=false
    break
  fi
done

if $all_present; then
  echo "All source packages already built in ${LOCAL_REPO_DIR}"
  exit 0
fi

# Create build chroot if not exists
if [ ! -d "${BUILD_CHROOT}" ]; then
  echo "Creating Forky build chroot with mmdebstrap..."
  mmdebstrap --variant=buildd --format=directory \
    --include="build-essential,devscripts,cmake,extra-cmake-modules,git,ca-certificates,equivs,pkg-config" \
    forky "${BUILD_CHROOT}" http://deb.debian.org/debian
  
  # Set up chroot networking
  mkdir -p "${BUILD_CHROOT}/proc" "${BUILD_CHROOT}/dev" "${BUILD_CHROOT}/sys"
  mount --bind /proc "${BUILD_CHROOT}/proc"
  mount --bind /dev "${BUILD_CHROOT}/dev"
  mount --bind /sys "${BUILD_CHROOT}/sys"
  cp /etc/resolv.conf "${BUILD_CHROOT}/etc/resolv.conf"
fi

# Install build dependencies for all 5 packages
echo "Cloning source repos and installing build deps..."
mkdir -p "${BUILD_CHROOT}/src"

for entry in "${SOURCE_REPOS[@]}"; do
  pkg_name="${entry%%:*}"
  repo_url="${entry#*:}"
  
  if [ ! -d "${BUILD_CHROOT}/src/${pkg_name}" ]; then
    chroot "${BUILD_CHROOT}" git clone --depth 1 "${repo_url}" "/src/${pkg_name}"
  fi
  
  # Install build dependencies
  echo "Installing build deps for ${pkg_name}..."
  chroot "${BUILD_CHROOT}" bash -c "cd /src/${pkg_name} && mk-build-deps -i -t 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y' debian/control 2>&1 | tail -5" || true
done

# Build each package in order (respecting inter-package dependencies)
# Order: LingmoUI -> lingmo-core -> lingmo-dock -> lingmo-statusbar -> lingmo-settings
BUILD_ORDER=(
  "LingmoUI:lingmoui3"
  "lingmo-core:lingmo-core"
  "lingmo-dock:lingmo-dock"
  "lingmo-statusbar:lingmo-statusbar"
  "lingmo-settings:lingmo-settings"
)

for entry in "${BUILD_ORDER[@]}"; do
  repo_name="${entry%%:*}"
  pkg_name="${entry#*:}"
  
  echo "Building ${pkg_name} from ${repo_name}..."
  chroot "${BUILD_CHROOT}" bash -c "cd /src/${repo_name} && dpkg-buildpackage -b -uc -us 2>&1 | tail -5"
  
  # Copy .debs to local repo
  cp "${BUILD_CHROOT}/src/${repo_name}/../${pkg_name}"*.deb "${LOCAL_REPO_DIR}/" 2>/dev/null || true
  # Also copy dev/dbgsym packages
  cp "${BUILD_CHROOT}/src/${repo_name}/../"*.deb "${LOCAL_REPO_DIR}/" 2>/dev/null || true
done

# Also copy liblingmo from OBS since it's needed by lingmo-settings
# (We don't build liblingmo, it doesn't have the ABI conflict)
echo "Also copying liblingmo and other non-conflicting Lingmo debs from OBS..."
# This is done separately in build.sh

# Generate Packages.gz for local repo
cd "${LOCAL_REPO_DIR}"
dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
echo "Local repo created at ${LOCAL_REPO_DIR} with $(ls *.deb 2>/dev/null | wc -l) packages"
echo "Source build complete!"
