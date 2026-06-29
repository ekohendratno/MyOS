#!/usr/bin/env bash
set -euo pipefail

mkdir -p ~/.config/plank/dock1/launchers

cat > ~/.config/plank/dock1/settings <<'EOF'
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
EOF

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

gsettings set com.lingmo.settings default-page appearance 2>/dev/null || true
gsettings set org.pantheon.switchboard default-plug appearance 2>/dev/null || true

pkill plank 2>/dev/null || true
nohup plank >/tmp/plank.log 2>&1 &

echo "Hotfix applied."
