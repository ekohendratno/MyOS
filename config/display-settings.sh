#!/usr/bin/env bash
# =============================================================================
# display-settings.sh — Default display dan typography mixos
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="display-settings"

log_info()  { printf "[%s] [%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*"; }
log_warn()  { printf "[%s] [%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*" >&2; }

log_info "Menulis default display & typography"
cat > /etc/dconf/db/mixos.d/04-display <<'EOF'
# org.gnome.desktop.interface
[org/gnome/desktop/interface]
font-name='Inter 10.5'
document-font-name='Inter 10.5'
monospace-font-name='JetBrains Mono 10'
text-scaling-factor=1.0

# org.gnome.desktop.wm.preferences
[org/gnome/desktop/wm/preferences]
titlebar-font='Inter Semibold 10'
button-layout='close,minimize,maximize:menu'
focus-mode='sloppy'
raise-on-click=true
double-click-titlebar='toggle-maximize'
theme='mixos-gtk'
num-workspaces=4
workspace-names=['Primary', 'Work', 'Web', 'Misc']

# org.gnome.settings-daemon.peripherals
[org/gnome/settings-daemon/peripherals/mouse]
double-click=400
drag-threshold=8

[org/gnome/settings-daemon/peripherals/touchpad]
tap-to-click=true
natural-scroll=true
two-finger-scrolling=true
edge-scrolling=false
disable-while-typing=true

# org.gnome.settings-daemon.peripherals.keyboard
[org/gnome/settings-daemon/peripherals/keyboard]
repeat=true
delay=250
repeat-interval=33
EOF

log_info "Compile dconf database"
dconf update

log_info "Display settings selesai"
exit 0
