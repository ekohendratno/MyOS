#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_LB="${PROJECT_ROOT}/upstream/live-build-config"
SOURCE_DEBS="${PROJECT_ROOT}/artifacts/lingmo-source-debs"
WORK_DIR="${PROJECT_ROOT}/builds/lingmo-baseline-amd64"
WIN_OUT="/mnt/c/MyOS/builds"
ARCH="${ARCH:-amd64}"
DIST="${DIST:-trixie}"
VARIANT="${VARIANT:-default}"
DATE_STAMP="$(date +%Y%m%d)"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/lingmo-baseline-build.log"
SAFE_BOOT_APPEND="boot=live components username=lingmo hostname=lingmo-baseline noeject nosplash plymouth.enable=0 systemd.show_status=true loglevel=4 systemd.unit=multi-user.target console=tty0 console=ttyS0,115200n8 modprobe.blacklist=vmwgfx,vmw_vmci,vmw_balloon"
DESKTOP_BOOT_APPEND="boot=live components username=lingmo hostname=lingmo-baseline noeject nosplash plymouth.enable=0 systemd.show_status=true loglevel=4 systemd.unit=multi-user.target console=tty0 console=ttyS0,115200n8 modprobe.blacklist=vmwgfx,vmw_vmci,vmw_balloon mixos.desktop=1"
FAILSAFE_BOOT_APPEND="boot=live components username=lingmo hostname=lingmo-baseline noeject memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash plymouth.enable=0 systemd.show_status=true loglevel=4 systemd.unit=multi-user.target modprobe.blacklist=vmwgfx"

log() {
  printf '[%(%H:%M:%S)T] %s\n' -1 "$*"
}

need_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "Run as root: sudo scripts/build-lingmo-baseline.sh" >&2
    exit 1
  fi
}

ensure_host_deps() {
  local missing=()
  local cmd
  for cmd in lb rsync jq curl wget dpkg-deb xargs sha256sum md5sum; do
    command -v "${cmd}" >/dev/null 2>&1 || missing+=("${cmd}")
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    log "Installing missing host tools: ${missing[*]}"
    apt-get update
    apt-get install -y live-build rsync jq curl wget dpkg-dev coreutils findutils
  fi
}

copy_upstream_config() {
  log "Preparing clean upstream live-build-config in ${WORK_DIR}"
  mkdir -p "${WORK_DIR}" "${LOG_DIR}" "${WIN_OUT}"
  rm -rf "${WORK_DIR}/config/hooks" \
         "${WORK_DIR}/config/includes.chroot" \
         "${WORK_DIR}/config/includes.chroot_after_packages" \
         "${WORK_DIR}/config/includes.chroot_before_packages" \
         "${WORK_DIR}/config/package-lists/9999-mixos-live-x11-fallback.list.chroot" \
         2>/dev/null || true
  rsync -a --delete \
    --exclude='.git/' \
    --exclude='images/' \
    --exclude='chroot/' \
    --exclude='binary/' \
    --exclude='cache/' \
    --exclude='.build/' \
    "${UPSTREAM_LB}/" "${WORK_DIR}/"

  echo "http://deb.debian.org/debian" > "${WORK_DIR}/.mirror"

  # Upstream auto/config tries to parse a public IP geolocation API with jq
  # before it checks .mirror. That API can return non-JSON and break builds.
  sed -i \
    -e 's|^response=.*|response="{}"|' \
    -e 's|^country_code=.*|country_code="ID"|' \
    "${WORK_DIR}/auto/config"
}

run_lb_config() {
  cd "${WORK_DIR}"
  log "Running upstream lb config: dist=${DIST}, variant=${VARIANT}, arch=${ARCH}"
  lb config -a "${ARCH}" --distribution "${DIST}" -- --variant "${VARIANT}"

  # The upstream config writes kernel append values into config/binary. Patch
  # that file directly so the generated bootloader cannot silently keep the old
  # "quiet splash" entry that hides early graphics failures.
  sed -i \
    -e "s|^LB_BOOTAPPEND_LIVE=.*|LB_BOOTAPPEND_LIVE=\"${SAFE_BOOT_APPEND}\"|" \
    -e "s|^LB_BOOTAPPEND_LIVE_FAILSAFE=.*|LB_BOOTAPPEND_LIVE_FAILSAFE=\"${FAILSAFE_BOOT_APPEND}\"|" \
    config/binary

  mkdir -p config/archives
  cat > config/archives/lingmo_pkg.list.chroot <<'ARCHIVE'
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE
  cat > config/archives/lingmo_pkg.list.binary <<'ARCHIVE'
deb [trusted=yes] https://download.opensuse.org/repositories/home:/elysia:/LingmoOS:/CI/Debian_Testing/ ./
ARCHIVE

  # These package names are present in the upstream live-build lists, but are
  # not available from the current Lingmo OBS repo nor from our source build.
  # Keep the baseline build focused on the actual desktop shell packages.
  find config/package-lists -type f -name '*.list.chroot' -print0 \
    | xargs -0 sed -i \
      -e '/^lingmo-base-files$/d' \
      -e '/^lingmo-workspace-base$/d' \
      -e '/^lingmo-plymouth$/d' \
      -e '/^lingmo-live$/d' \
      -e '/^lingmo-screenshot$/d' \
      -e '/^open-vm-tools$/d' \
      -e '/^open-vm-tools-desktop$/d' \
      -e '/^qemu-guest-agent$/d' \
      -e '/^xrdp$/d' \
      -e '/^xrdp-sesman$/d'

  cat > config/package-lists/9999-mixos-live-x11-fallback.list.chroot <<'PACKAGES'
xinit
kbd
x11-xserver-utils
xterm
xserver-xorg-legacy
xserver-xorg-video-all
xserver-xorg-video-fbdev
xserver-xorg-video-vesa
PACKAGES

  if [ -f config/hooks/live/lingmo-hacks.chroot ]; then
    perl -0pi -e 's/# Install OnlyOffice.*?# Fixing os-release/# Install OnlyOffice skipped for baseline ISO\n# Fixing os-release/s' \
      config/hooks/live/lingmo-hacks.chroot
  fi

  add_binary_boot_menu_hook
}

add_binary_boot_menu_hook() {
  local hook_dir="${WORK_DIR}/config/hooks/normal"
  mkdir -p "${hook_dir}"

  cat > "${hook_dir}/9990-mixos-safe-boot-menu.hook.binary" <<EOF
#!/bin/sh
set -e

safe_append='${SAFE_BOOT_APPEND}'
desktop_append='${DESKTOP_BOOT_APPEND}'
failsafe_append='${FAILSAFE_BOOT_APPEND}'

if [ -f binary/isolinux/live.cfg ]; then
  binary_dir="binary"
elif [ -f ../binary/isolinux/live.cfg ]; then
  binary_dir="../binary"
elif [ -f ../../binary/isolinux/live.cfg ]; then
  binary_dir="../../binary"
else
  binary_dir=""
fi

echo "mixos safe boot hook pwd=\$(pwd) binary_dir=\${binary_dir}"

if [ -n "\${binary_dir}" ] && [ -f "\${binary_dir}/isolinux/live.cfg" ]; then
  cat > "\${binary_dir}/isolinux/live.cfg" <<MENU
label live-safe
        menu label ^Live system safe console (no desktop)
        menu default
        linux /live/vmlinuz
        initrd /live/initrd.img
        append \${safe_append}

label live-desktop
        menu label Live system Lingmo desktop (safe graphics)
        linux /live/vmlinuz
        initrd /live/initrd.img
        append \${desktop_append}

label live-failsafe
        menu label Live system fail-safe console
        linux /live/vmlinuz
        initrd /live/initrd.img
        append \${failsafe_append}
MENU
fi

if [ -n "\${binary_dir}" ] && [ -f "\${binary_dir}/boot/grub/grub.cfg" ]; then
  awk -v safe="\${safe_append}" -v desktop="\${desktop_append}" -v failsafe="\${failsafe_append}" '
    BEGIN {
      print "set default=0"
      print "set timeout=8"
      print "menuentry \"Live system safe console (no desktop)\" {"
      print " linux /live/vmlinuz " safe
      print " initrd /live/initrd.img"
      print "}"
      print "menuentry \"Live system Lingmo desktop (safe graphics)\" {"
      print " linux /live/vmlinuz " desktop
      print " initrd /live/initrd.img"
      print "}"
      print "menuentry \"Live system fail-safe console\" {"
      print " linux /live/vmlinuz " failsafe
      print " initrd /live/initrd.img"
      print "}"
    }
  ' > "\${binary_dir}/boot/grub/grub.cfg"
fi
EOF
  chmod +x "${hook_dir}/9990-mixos-safe-boot-menu.hook.binary"
}

copy_local_lingmo_packages() {
  local pkgs_dir="${WORK_DIR}/config/packages.chroot"
  local copied=0
  mkdir -p "${pkgs_dir}"

  if ! compgen -G "${SOURCE_DEBS}/*.deb" >/dev/null; then
    echo "No LingmoOS source packages found in ${SOURCE_DEBS}" >&2
    echo "Run first: sudo scripts/build-lingmo-source.sh --force" >&2
    exit 1
  fi

  log "Copying LingmoOS runtime packages from source build cache"
  rm -f "${pkgs_dir}"/lingmo-*.deb "${pkgs_dir}"/liblingmo*.deb "${pkgs_dir}"/appmotor*.deb "${pkgs_dir}"/ocean*.deb 2>/dev/null || true

  while IFS= read -r -d '' deb; do
    case "$(basename "${deb}")" in
      *-dev_*.deb|*-dbg_*.deb|*-dbgsym_*.deb|*-doc_*.deb)
        continue
        ;;
    esac
    cp -f "${deb}" "${pkgs_dir}/"
    copied=$((copied + 1))
  done < <(find "${SOURCE_DEBS}" -maxdepth 1 -type f -name '*.deb' -print0)

  for compat in \
    "${PROJECT_ROOT}/builds/work-amd64/config/packages.chroot/qt6-base-private-abi-stub_6.9.2_all.deb" \
    "${PROJECT_ROOT}/builds/work-amd64/config/packages.chroot/qt6-declarative-private-abi-stub_6.9.2_all.deb" \
    "${PROJECT_ROOT}/builds/work-amd64/config/packages.chroot/libicu76_76.1-4_amd64.deb"; do
    [ -f "${compat}" ] && cp -f "${compat}" "${pkgs_dir}/"
  done

  patch_local_debs "${pkgs_dir}"
  write_local_package_pins "${pkgs_dir}"
  log "Local package overlay ready: $(find "${pkgs_dir}" -maxdepth 1 -type f -name '*.deb' | wc -l) debs (${copied} from LingmoOS source)"
}

write_local_package_pins() {
  local pkgs_dir="$1"
  local pref_dir="${WORK_DIR}/config/includes.chroot_before_packages/etc/apt/preferences.d"
  local pref="${pref_dir}/00-local-lingmo-source"
  local deb
  local pkg
  local ver

  mkdir -p "${pref_dir}"
  : > "${pref}"
  while IFS= read -r -d '' deb; do
    pkg="$(dpkg-deb -f "${deb}" Package)"
    ver="$(dpkg-deb -f "${deb}" Version)"
    case "${pkg}" in
      appmotor|ocean|liblingmo*|lingmo*)
        {
          echo "Package: ${pkg}"
          echo "Pin: version ${ver}"
          echo "Pin-Priority: 1001"
          echo
        } >> "${pref}"
        ;;
    esac
  done < <(find "${pkgs_dir}" -maxdepth 1 -type f -name '*.deb' -print0)
}

repack_without_dep() {
  local deb="$1"
  local dep="$2"
  local tmp
  tmp="$(mktemp -d)"
  dpkg-deb -R "${deb}" "${tmp}" >/dev/null
  if [ -f "${tmp}/DEBIAN/control" ] && grep -q "${dep}" "${tmp}/DEBIAN/control"; then
    log "Removing unavailable dependency ${dep} from $(basename "${deb}")"
    sed -Ei \
      -e "s/,[[:space:]]*${dep}([[:space:]]*\\([^)]*\\))?//g" \
      -e "s/${dep}([[:space:]]*\\([^)]*\\))?,[[:space:]]*//g" \
      -e "/^[[:space:]]*${dep}([[:space:]]*\\([^)]*\\))?[[:space:]]*$/d" \
      "${tmp}/DEBIAN/control"
    dpkg-deb -b "${tmp}" "${deb}" >/dev/null
  fi
  rm -rf "${tmp}"
}

patch_local_debs() {
  local pkgs_dir="$1"
  local deb

  while IFS= read -r -d '' deb; do
    repack_without_dep "${deb}" "appmenu-gtk2-module"
  done < <(find "${pkgs_dir}" -maxdepth 1 -type f -name 'lingmo-core_*.deb' -print0)

  while IFS= read -r -d '' deb; do
    repack_without_dep "${deb}" "lingmo-kwin-plugins-roundedwindow"
  done < <(find "${pkgs_dir}" -maxdepth 1 -type f -name 'lingmo-kwin-plugins_*.deb' -print0)

  while IFS= read -r -d '' deb; do
    repack_without_dep "${deb}" "liblingmo"
  done < <(find "${pkgs_dir}" -maxdepth 1 -type f \( -name 'lingmo-desktop_*.deb' -o -name 'lingmo-launcher_*.deb' -o -name 'lingmo-settings_*.deb' -o -name 'lingmo-terminal_*.deb' \) -print0)
}

add_live_autologin_hook() {
  local hook_dir="${WORK_DIR}/config/hooks/normal"
  mkdir -p "${hook_dir}"

  cat > "${hook_dir}/9990-lingmo-baseline-autologin.hook.chroot" <<'EOF'
#!/bin/sh
set -e

mkdir -p /usr/local/bin /usr/local/sbin /usr/share/xsessions /etc/sddm.conf.d /etc/live/config.conf.d /etc/xdg/autostart /etc/systemd/system/multi-user.target.wants /etc/X11/xorg.conf.d /etc/modprobe.d

cat > /etc/modprobe.d/blacklist-vmwgfx-live.conf <<'MODPROBE'
blacklist vmwgfx
MODPROBE

rm -f /etc/X11/xorg.conf.d/20-mixos-live-safe-video.conf
cat > /etc/X11/xorg.conf.d/20-mixos-live-video.conf <<'XORG'
Section "Device"
    Identifier "MixOS VirtualBox Video"
    Driver "modesetting"
    Option "AccelMethod" "none"
EndSection
XORG

cat > /etc/X11/Xwrapper.config <<'XWRAPPER'
allowed_users=anybody
needs_root_rights=yes
XWRAPPER

for pkg in open-vm-tools open-vm-tools-desktop hyperv-daemons qemu-guest-agent xrdp; do
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
    apt-get purge -y "$pkg"
  fi
done
apt-get autoremove --purge -y || true
blocked_pkgs="$(dpkg-query -W -f='${Package}\n' open-vm-tools open-vm-tools-desktop qemu-guest-agent xrdp 2>/dev/null || true)"
if [ -n "${blocked_pkgs}" ]; then
  echo "Blocked VM/remote packages still installed:" >&2
  echo "${blocked_pkgs}" >&2
  exit 1
fi
rm -f /usr/lib/systemd/system-generators/systemd-ssh-generator \
      /lib/systemd/system-generators/systemd-ssh-generator \
      2>/dev/null || true

cat > /usr/local/bin/startlingmo-live-x11 <<'SESSION'
#!/bin/sh
set +e

log_dir="${HOME:-/tmp}/.cache"
mkdir -p "${log_dir}"
exec >>"${log_dir}/lingmo-live-session.log" 2>&1
echo "=== startlingmo-live-x11 $(date -Is) ==="

export DESKTOP_SESSION=lingmo
export XDG_CURRENT_DESKTOP=Lingmo:KDE
export XDG_SESSION_DESKTOP=lingmo
export XDG_SESSION_TYPE=x11
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"
export KDE_SESSION_VERSION=5
export KDE_FULL_SESSION=true
export QT_QPA_PLATFORM=xcb
export QT_QUICK_BACKEND=software
export QSG_RHI_BACKEND=software
export LIBGL_ALWAYS_SOFTWARE=1
export KWIN_COMPOSE=O2
export QT_STYLE_OVERRIDE=ocean

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    DISPLAY XAUTHORITY DESKTOP_SESSION XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP \
    XDG_SESSION_TYPE KDE_SESSION_VERSION KDE_FULL_SESSION QT_QPA_PLATFORM \
    QT_QUICK_BACKEND QSG_RHI_BACKEND LIBGL_ALWAYS_SOFTWARE QT_STYLE_OVERRIDE || true
fi

command -v xsetroot >/dev/null 2>&1 && xsetroot -solid '#151525' || true
if command -v xterm >/dev/null 2>&1; then
  xterm -geometry 100x18+40+40 -title "MixOS desktop diagnostics" \
    -e sh -lc 'printf "%s\n" "Xorg is running. Starting Lingmo desktop components..."; printf "%s\n" "Logs: /var/log/lingmo-live-display.log and ~/.cache/lingmo-live-session.log"; sleep 20' &
fi

start_once() {
  name="$1"
  shift
  if command -v "$name" >/dev/null 2>&1 && ! pgrep -u "$(id -u)" -x "$name" >/dev/null 2>&1; then
    echo "starting $name"
    "$name" "$@" &
    sleep 1
  else
    echo "skip $name"
  fi
}

start_once kwin_x11 --replace
sleep 2
start_once lingmo-settings-daemon
start_once lingmo-daemon
start_once lingmo-polkit-agent
start_once lingmo-notificationd
start_once lingmo-statusbar
start_once lingmo-desktop
start_once lingmo-dock
start_once lingmo-launcher

if command -v lingmo-session >/dev/null 2>&1; then
  echo "starting lingmo-session supervisor"
  lingmo-session &
fi

while :; do
  sleep 5
  for svc in lingmo-statusbar lingmo-desktop lingmo-dock lingmo-daemon; do
    if command -v "$svc" >/dev/null 2>&1 && ! pgrep -u "$(id -u)" -x "$svc" >/dev/null 2>&1; then
      echo "restarting $svc"
      "$svc" &
      sleep 1
    fi
  done
done
SESSION
chmod +x /usr/local/bin/startlingmo-live-x11

cat > /usr/local/sbin/startlingmo-live-x11-root <<'ROOTSESSION'
#!/bin/sh
set +e

export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY=

command -v xhost >/dev/null 2>&1 && xhost +SI:localuser:lingmo || true
exec /bin/su - lingmo -c 'export DISPLAY=:0; unset XAUTHORITY; exec /usr/local/bin/startlingmo-live-x11'
ROOTSESSION
chmod +x /usr/local/sbin/startlingmo-live-x11-root

cat > /usr/local/sbin/startlingmo-live-display <<'DISPLAY'
#!/bin/sh
set +e

exec >>/var/log/lingmo-live-display.log 2>&1
echo "=== startlingmo-live-display $(date -Is) ==="

if ! grep -qw 'mixos.desktop=1' /proc/cmdline && [ ! -f /run/mixos-force-desktop ]; then
  echo "Desktop autostart disabled. Boot menu selected safe console."
  echo "To test desktop manually, run: sudo mixos-start-desktop"
  exit 0
fi

systemctl stop sddm display-manager 2>/dev/null || true

for n in $(seq 1 60); do
  if id lingmo >/dev/null 2>&1; then
    break
  fi
  echo "waiting for live user lingmo ($n)"
  sleep 1
done

if ! id lingmo >/dev/null 2>&1; then
  echo "live user lingmo was not created"
  exit 1
fi

mkdir -p /home/lingmo/.cache /home/lingmo/.config
chown -R lingmo:lingmo /home/lingmo

rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=Lingmo:KDE
export DESKTOP_SESSION=lingmo

exec /usr/bin/xinit /usr/local/sbin/startlingmo-live-x11-root -- /usr/bin/Xorg :0 vt7 -nolisten tcp -ac
DISPLAY
chmod +x /usr/local/sbin/startlingmo-live-display

cat > /usr/local/sbin/mixos-start-desktop <<'STARTDESKTOP'
#!/bin/sh
set -e
if [ "$(id -u)" != "0" ]; then
  exec sudo /usr/local/sbin/mixos-start-desktop "$@"
fi
echo "Starting Lingmo desktop from console..."
touch /run/mixos-force-desktop
exec /usr/local/sbin/startlingmo-live-display
STARTDESKTOP
chmod +x /usr/local/sbin/mixos-start-desktop

cat > /etc/systemd/system/lingmo-live-display.service <<'SERVICE'
[Unit]
Description=Start Lingmo live desktop without login manager
After=systemd-user-sessions.service live-config.service getty@tty1.service
Wants=systemd-user-sessions.service
Conflicts=display-manager.service sddm.service
Before=display-manager.service sddm.service

[Service]
Type=simple
ExecStart=/usr/local/sbin/startlingmo-live-display
Restart=on-failure
RestartSec=3
StandardInput=tty
TTYPath=/dev/tty7
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes

[Install]
WantedBy=multi-user.target
SERVICE
ln -sf /etc/systemd/system/lingmo-live-display.service /etc/systemd/system/multi-user.target.wants/lingmo-live-display.service
ln -sf /dev/null /etc/systemd/system/sddm.service
ln -sf /dev/null /etc/systemd/system/display-manager.service

# Keep the diagnostic live boot small and predictable. These services are not
# needed to reach a local console and can add VM-specific side effects or long
# waits before we have a working desktop session.
for unit in \
  open-vm-tools.service vmtoolsd.service vgauth.service run-vmblock\\x2dfuse.mount \
  xrdp.service xrdp-sesman.service hostapd.service smartmontools.service \
  systemd-storagetm.service packagekit-offline-update.service; do
  ln -sf /dev/null "/etc/systemd/system/${unit}"
done
rm -f \
  /etc/systemd/system/multi-user.target.wants/open-vm-tools.service \
  /etc/systemd/system/multi-user.target.wants/xrdp.service \
  /etc/systemd/system/multi-user.target.wants/xrdp-sesman.service \
  /etc/systemd/system/multi-user.target.wants/hostapd.service \
  /etc/systemd/system/multi-user.target.wants/smartmontools.service \
  /etc/systemd/system/multi-user.target.wants/run-vmblock\\x2dfuse.mount \
  /etc/systemd/system/system-update.target.wants/packagekit-offline-update.service \
  2>/dev/null || true

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'GETTY'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin lingmo --noclear %I $TERM
GETTY

cat > /usr/share/xsessions/lingmo-xsession.desktop <<'DESKTOP'
[Desktop Entry]
Type=XSession
Exec=/usr/local/bin/startlingmo-live-x11
TryExec=/usr/local/bin/startlingmo-live-x11
DesktopNames=KDE
Name=Lingmo OS Desktop (Live X11)
Comment=Lingmo OS Desktop live fallback session
DESKTOP

for item in \
  "lingmo-settings-daemon:Lingmo Settings Daemon" \
  "lingmo-daemon:Lingmo Daemon" \
  "lingmo-polkit-agent:Lingmo Polkit Agent" \
  "lingmo-notificationd:Lingmo Notifications" \
  "lingmo-statusbar:Lingmo Statusbar" \
  "lingmo-desktop:Lingmo Desktop" \
  "lingmo-dock:Lingmo Dock"; do
  bin="${item%%:*}"
  name="${item#*:}"
  if command -v "${bin}" >/dev/null 2>&1; then
    cat > "/etc/xdg/autostart/${bin}.desktop" <<AUTOSTART
[Desktop Entry]
Type=Application
Name=${name}
Exec=${bin}
OnlyShowIn=KDE;Lingmo;
X-KDE-autostart-phase=1
NoDisplay=true
AUTOSTART
  fi
done

cat > /etc/live/config.conf.d/lingmo-baseline-user.conf <<'LIVEUSER'
LIVE_HOSTNAME="lingmo-baseline"
LIVE_USERNAME="lingmo"
LIVE_USER_FULLNAME="Lingmo Live User"
LIVE_USER_DEFAULT_GROUPS="audio cdrom dip floppy video plugdev netdev sudo"
LIVEUSER

rm -f /etc/sddm.conf
cat > /etc/sddm.conf.d/10-theme.conf <<'THEME'
[Theme]
Current=lingmo

[Users]
DefaultPath=/usr/bin:/bin
THEME

cat > /etc/sddm.conf.d/20-autologin.conf <<'AUTOLOGIN'
[Autologin]
User=lingmo
Session=lingmo-xsession
Relogin=true
AUTOLOGIN
EOF
  chmod +x "${hook_dir}/9990-lingmo-baseline-autologin.hook.chroot"
}

build_iso() {
  cd "${WORK_DIR}"
  rm -f "${LOG_FILE}"
  rm -f .build/chroot_package-lists* \
        .build/chroot_install-packages* \
        .build/chroot_archives* \
        .build/chroot_includes_before_packages* \
        .build/chroot_hooks* \
        .build/binary_iso* \
        .build/binary_checksums* \
        .build/binary_hooks* \
        .build/binary_chroot* \
        .build/binary_syslinux* \
        .build/binary_grub* \
        .build/binary_bootloader_splash* \
        .build/binary_includes* \
        .build/binary_linux-image* \
        .build/binary_memtest* \
        .build/binary_rootfs* \
        .build/binary_manifest* \
        .build/binary_package-lists* \
        binary_iso \
        binary/live/filesystem.* \
        binary/live/*.squashfs \
        binary/live/vmlinuz* \
        binary/live/initrd.img* \
        binary/isolinux/live.cfg \
        binary/boot/grub/grub.cfg \
        chroot/binary \
        live-image-${ARCH}.hybrid.iso \
        chroot/root/packages.chroot \
        chroot/root/packages.binary \
        chroot/onlyoffice.deb \
        2>/dev/null || true
  rm -rf chroot/binary 2>/dev/null || true
  log "Starting live-build. Log: ${LOG_FILE}"
  lb build 2>&1 | tee "${LOG_FILE}"
  local code=${PIPESTATUS[0]}
  if [ "${code}" -ne 0 ]; then
    echo "live-build failed with exit code ${code}" >&2
    tail -80 "${LOG_FILE}" >&2 || true
    exit "${code}"
  fi

  local src="${WORK_DIR}/live-image-${ARCH}.hybrid.iso"
  local dst="${WIN_OUT}/lingmo-baseline-${DIST}-${ARCH}.${DATE_STAMP}.iso"
  if [ ! -f "${src}" ]; then
    echo "Build succeeded but ISO was not found: ${src}" >&2
    exit 1
  fi

  sha256sum "${src}" | sed "s|  ${src}$|  ${dst}|" > "${src}.sha256"
  md5sum "${src}" | sed "s|  ${src}$|  ${dst}|" > "${src}.md5"
  mv -f "${src}" "${dst}"
  mv -f "${src}.sha256" "${dst}.sha256"
  mv -f "${src}.md5" "${dst}.md5"
  sync "${dst}" "${dst}.sha256" "${dst}.md5" 2>/dev/null || sync
  if [ ! -s "${dst}" ]; then
    echo "ISO move verification failed: ${dst} is missing or empty" >&2
    exit 1
  fi
  local bytes
  bytes="$(stat -c '%s' "${dst}")"
  if [ "${bytes}" -lt 1000000000 ]; then
    echo "ISO move verification failed: ${dst} is unexpectedly small (${bytes} bytes)" >&2
    exit 1
  fi
  log "ISO moved to ${dst}"
}

main() {
  need_root
  ensure_host_deps
  copy_upstream_config
  run_lb_config
  copy_local_lingmo_packages
  add_live_autologin_hook
  build_iso
}

main "$@"
