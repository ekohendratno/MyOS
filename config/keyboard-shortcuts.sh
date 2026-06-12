#!/usr/bin/env bash
# =============================================================================
# keyboard-shortcuts.sh — Default keyboard shortcuts mixos (macOS-inspired)
# =============================================================================
# Override default GNOME shortcuts agar lebih mirip macOS:
# - Cmd (Super) sebagai modifier utama
# - Cmd+Space untuk activities
# - Cmd+L untuk location bar
# - Cmd+1/2/3 untuk view mode
# - Cmd+Q untuk quit
# - Cmd+W untuk close
# - Cmd+S untuk save
# - Cmd+N untuk new
# - Cmd+, untuk preferences
# - Cmd+Tab untuk switch
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="keyboard-shortcuts"

log_info()  { printf "[%s] [%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*"; }
log_warn()  { printf "[%s] [%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "${HOOK_NAME}" "$*" >&2; }

log_info "Menulis default keyboard shortcuts"
mkdir -p /etc/dconf/db/mixos.d

# Hapus dulu jika ada, untuk reentrant
rm -f /etc/dconf/db/mixos.d/05-keyboard-shortcuts

cat > /etc/dconf/db/mixos.d/05-keyboard-shortcuts <<'EOF'
# org.gnome.desktop.wm.keybindings
[org/gnome/desktop/wm/keybindings]
close=['<Super>w']
maximize=['<Super>Up']
unmaximize=['<Super>Down']
minimize=['<Super>h']
toggle-maximized=['<Super>m']
begin-resize=['<Super>F8']
begin-move=['<Super>F7']
switch-applications=['<Super>Tab']
switch-applications-backward=['<Super><Shift>Tab']
switch-group=['<Super>grave', '<Super>asciitilde']
switch-group-backward=['<Super>Shift>grave', '<Super><Shift>asciitilde']
switch-panels=['<Super>Escape']
cycle-group=['<Alt>grave', '<Alt>asciitilde']
cycle-group-backward=['<Alt><Shift>grave', '<Alt><Shift>asciitilde']
cycle-windows=['<Alt>Tab']
cycle-windows-backward=['<Alt><Shift>Tab']
show-desktop=['<Super>d']
panel-run-dialog=['<Super>r']
activate-window-menu=['<Super>space']
toggle-shaded=['<Super>u']
move-to-workspace-left=['<Super><Shift>Left']
move-to-workspace-right=['<Super><Shift>Right']
move-to-workspace-up=['<Super><Shift>Up']
move-to-workspace-down=['<Super><Shift>Down']
switch-to-workspace-left=['<Super>Left']
switch-to-workspace-right=['<Super>Right']
switch-to-workspace-up=['<Super>Page_Up']
switch-to-workspace-down=['<Super>Page_Down']

# org.gnome.mutter.keybindings
[org/gnome/mutter/keybindings]
toggle-tiled-left=['<Super>bracketleft']
toggle-tiled-right=['<Super>bracketright']

# org.gnome.shell.keybindings
[org/gnome/shell/keybindings]
open-application-menu=['']
toggle-application-view=['<Super>space']
toggle-message-tray=['<Super>v']
toggle-overview=['<Super>a', '<Super>s']
screenshot=['<Shift><Super>3']
screenshot-window=['<Shift><Super>4']
screenshot-area=['<Shift><Super>5']
show-screenshot-ui=['']

# Custom mixos shortcuts
[org/pantheon/desktop/wingpanel/keybindings]
show-app-menu=['<Super>q']

# org.gnome.settings-daemon.plugins.media-keys
[org/gnome/settings-daemon/plugins/media-keys]
calculator=['<Super>equal']
help=''
home=['<Super>e']
logout=['']
magnifier=['']
mute=['<XF86AudioMute']
next=['<XF86AudioNext']
play=['<XF86AudioPlay']
prev=['<XF86AudioPrev']
screensaver=['<Super>l']
stop=['<XF86AudioStop']
volume-down=['<XF86AudioLowerVolume']
volume-up=['<XF86AudioRaiseVolume']
www=['<XF86WWW']
EOF

# === Touchpad gestures (jika didukung) ===
cat > /etc/dconf/db/mixos.d/05-touchpad-gestures <<'EOF'
# org.gnome.desktop.peripherals.touchpad
[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
two-finger-scrolling=true
edge-scrolling=false
natural-scroll=true
disable-while-typing=true
click-method='fingers'
EOF

log_info "Compile dconf database"
dconf update

log_info "Keyboard shortcuts selesai"
exit 0
