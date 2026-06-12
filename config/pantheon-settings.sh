#!/usr/bin/env bash
# =============================================================================
# pantheon-settings.sh — Default Pantheon shell settings untuk mixos
# =============================================================================
# Script ini dijalankan di dalam chroot. Menulis default gsettings untuk
# gala, wingpanel, dan plank agar desktop mixos terasa lebih compact.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="pantheon-settings"

log_info()  { printf "[%s] [%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*"; }
log_warn()  { printf "[%s] [%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*" >&2; }
log_error() { printf "[%s] [%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*" >&2; }

# === gala (window manager) ===
# Catatan: window control position ke KIRI butuh patch gala (lihat patches/gala/).
# Setting di bawah ini hanya override nilai-nilai yang bisa di-tweak via gsettings.
log_info "Menulis default gala settings"
cat > /etc/dconf/db/mixos.d/02-pantheon-gala <<'EOF'
# org.pantheon.desktop.gala
[org/pantheon/desktop/gala]
animations=1
button-layout='close,minimize,maximize:menu'
workspace-count=4
enable-workspaces=true
hotcorner-topleft=''
hotcorner-topright=''
hotcorner-bottomleft=''
hotcorner-bottomright=''
attach-modal-dialogs=true
window-cycle-list-all-monitors=false
disable-workspaces-on-secondary-monitors=false
EOF

# === wingpanel (top panel) ===
log_info "Menulis default wingpanel settings"
cat > /etc/dconf/db/mixos.d/03-pantheon-wingpanel <<'EOF'
# org.pantheon.desktop.wingpanel
[org/pantheon/desktop/wingpanel]
background-color='#1e1e1e'
opacity=255
transparency-type='solid'
EOF

# === plank (dock) ===
log_info "Menulis default plank settings"
mkdir -p /etc/skel/.config/plank/dock1
cat > /etc/skel/.config/plank/dock1/settings <<'EOF'
# Plank dock settings mixos
[PlankDock]
Alignment=2                       # 0=Left, 1=Right, 2=Center, 3=Top
AutoHide=true
BounceDock=true
DockItemsAlignment=2
EnableTooltips=true
HideMode=1                        # 0=Window dodge, 1=Autohide, 2=Intellihide
IconSize=40
ItemsAlignment=2
ItemPinnedGS='[]'
ItemTime=300
KeepOnScreen=true
LockItems=false
Monitor=""
Offset=0
Position=4                        # 0=Left, 1=Right, 2=Top, 3=Bottom
PressureReveal=false
RevealDelay=200
RevealDuration=300
ShowDockItem=false
ShowOnlyMonitor=""
ShowProgressBar=true
ShowStatus=true
ShowTooltip=true
ShowTransients=true
StrutPolicy=1                     # 0=Follow, 1=Minimized, 2=Always
Theme=mixos-plank
TooltipDelay=350
UnhideDelay=0
UseHardware=false
UseSticky=false
WindowWhitelist=':::GtkWindow'
ZoomEnabled=true
ZoomFactor=1.2
EOF

# === system (host awal) ===
log_info "Menulis default hostname (template)"
cat > /etc/hostname <<'EOF'
mixos-host
EOF

# === Compile dconf ===
log_info "Compile dconf database"
dconf update

log_info "Pantheon settings selesai"
exit 0
