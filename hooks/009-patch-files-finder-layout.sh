#!/usr/bin/env bash
# =============================================================================
# 009-patch-files-finder-layout.sh — Patch pantheon-files untuk Finder-like
# =============================================================================
# Placeholder. Patch pantheon-files yang sebenarnya membutuhkan:
# 1. Clone source ke upstream/pantheon-files
# 2. Apply patch dari patches/files/*.patch
# 3. Build dan install
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="009-patch-files-finder-layout"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"

log_info "=== ${HOOK_NAME} ==="
log_warn "PATCH PLACEHOLDER. Patch pantheon-files aktual membutuhkan:"
log_warn "  1. Clone source ke upstream/pantheon-files"
log_warn "  2. Apply patch dari patches/files/*.patch"
log_warn "  3. Build (.deb) dan install"
log_warn ""
log_warn "Untuk tahap awal, hanya gsettings override:"

# === Default view settings ===
log_info "Set default view mode dan zoom untuk pantheon-files"
mkdir -p /etc/dconf/db/mixos.d
cat > /etc/dconf/db/mixos.d/09-files <<'EOF'
# mixos pantheon-files defaults
[org/pantheon/files/preferences]
default-folder-view='icon-view'
show-hidden-files=false
show-remote-files=true
sort-directories-first=true
thumbnail-size=128
EOF

dconf update

# === Marker patch plan ===
mkdir -p /usr/share/mixos-patches
cat > /usr/share/mixos-patches/files.json <<'EOF'
{
  "component": "pantheon-files",
  "patch_type": "finder-like-layout",
  "status": "pending-actual-patch",
  "notes": [
    "Reorder sidebar sections di src/PropertiesWindow.vala",
    "Default landing ke Home, bukan Root",
    "Tambahkan breadcrumb path bar di src/ViewContainer.vala",
    "Tambahkan status bar jumlah item",
    "Hilangkan double-click ke file (single click open, double click exec)",
    "Custom view-icon-theme untuk FileManagerIconView"
  ],
  "limitations": [
    "Column view: backlog, butuh effort besar",
    "Quick Look: backlog, butuh daemon terpisah",
    "Tabs: tidak akan ditambahkan (SDI design)"
  ]
}
EOF

log_info "${HOOK_NAME} selesai (placeholder, patch aktual belum di-apply)"
exit 0
