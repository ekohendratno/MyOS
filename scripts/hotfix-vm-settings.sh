#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="hotfix-vm-settings.sh"
readonly HOSTNAME="${1:-mixos-aurora-test}"
readonly USERNAME="${2:-srv}"
readonly PASSWORD="${3:-}"

if [[ -z "${PASSWORD}" ]]; then
  echo "Usage: ./scripts/hotfix-vm-settings.sh <vm-name> <user> <password>" >&2
  exit 1
fi

VBoxManage="${VBOXMANAGE:-C:/Program Files/Oracle/VirtualBox/VBoxManage.exe}"

if [[ ! -x "${VBoxManage}" ]]; then
  echo "VBoxManage tidak ditemukan: ${VBoxManage}" >&2
  exit 1
fi

tmp_script="$(mktemp /tmp/mixos-hotfix-XXXXXX.sh)"
cat > "${tmp_script}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mkdir -p ~/.config/plank/dock1/launchers

cat > ~/.config/plank/dock1/settings <<'CONF'
[PlankDock]
Alignment=2
AutoHide=true
BounceDock=true
DockItemsAlignment=2
EnableTooltips=true
HideMode=1
IconSize=40
ItemsAlignment=2
ItemPinnedGS='[]'
ItemTime=300
KeepOnScreen=true
LockItems=false
Monitor=""
Offset=0
Position=3
PressureReveal=false
RevealDelay=200
RevealDuration=300
ShowDockItem=true
ShowOnlyMonitor=""
ShowProgressBar=true
ShowStatus=true
ShowTooltip=true
ShowTransients=true
StrutPolicy=1
Theme=mixos-plank
TooltipDelay=350
UnhideDelay=0
UseHardware=false
UseSticky=false
WindowWhitelist=':::GtkWindow'
ZoomEnabled=true
ZoomFactor=1.2
CONF

create_launcher() {
  local file="$1" name="$2" icon="$3" exec="$4"
  cat > "$file" <<LAUNCHER
[Desktop Entry]
Type=Application
Name=${name}
Exec=${exec}
Icon=${icon}
NoDisplay=true
Terminal=false
StartupNotify=true
Categories=Utility;
LAUNCHER
}

create_launcher ~/.config/plank/dock1/launchers/files.desktop Files system-file-manager lingmo-filemanager
create_launcher ~/.config/plank/dock1/launchers/terminal.desktop Terminal utilities-terminal konsole
create_launcher ~/.config/plank/dock1/launchers/settings.desktop Settings settings-config lingmo-settings
create_launcher ~/.config/plank/dock1/launchers/browser.desktop Browser web-browser chromium
create_launcher ~/.config/plank/dock1/launchers/calculator.desktop Calculator accessories-calculator gnome-calculator

mkdir -p ~/.config/dconf
gsettings set com.lingmo.settings default-page appearance 2>/dev/null || true
gsettings set org.pantheon.switchboard default-plug appearance 2>/dev/null || true

pkill plank 2>/dev/null || true
nohup plank >/tmp/plank.log 2>&1 &
EOF
chmod +x "${tmp_script}"

guest_additions_state="$("${VBoxManage}" guestproperty get "${HOSTNAME}" "/VirtualBox/GuestAdd/Version" 2>/dev/null || true)"
if [[ "${guest_additions_state}" == *"No value set!"* || -z "${guest_additions_state}" ]]; then
  echo "Guest Additions belum terdeteksi. Saya siapkan file hotfix, tapi belum bisa push otomatis ke guest." >&2
  echo "Jalankan script ini dari terminal di VM atau copy isinya via Shared Folder." >&2
  exit 2
fi

"${VBoxManage}" guestcontrol "${HOSTNAME}" run \
  --username "${USERNAME}" \
  --password "${PASSWORD}" \
  --exe /bin/bash \
  -- /bin/bash "${tmp_script}"

echo "Hotfix dikirim ke VM."
