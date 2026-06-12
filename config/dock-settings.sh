#!/usr/bin/env bash
# =============================================================================
# dock-settings.sh — Konfigurasi dock (plank) untuk mixos
# =============================================================================
# File ini di-include dari pantheon-settings.sh atau dijalankan terpisah.
# Berisi konfigurasi dock compact, bottom-center, autohide.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="dock-settings"

log_info()  { printf "[%s] [%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*"; }
log_warn()  { printf "[%s] [%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*" >&2; }

readonly DOCK_USER_DIR="${1:-/etc/skel/.config/plank/dock1}"

if [[ ! -d "${DOCK_USER_DIR}" ]]; then
  log_warn "Membuat direktori dock: ${DOCK_USER_DIR}"
  mkdir -p "${DOCK_USER_DIR}"
fi

log_info "Menulis konfigurasi plank: ${DOCK_USER_DIR}/settings"
cat > "${DOCK_USER_DIR}/settings" <<'EOF'
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
ShowDockItem=false
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

log_info "Dock settings selesai"
exit 0
