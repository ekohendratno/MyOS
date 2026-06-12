#!/usr/bin/env bash
# =============================================================================
# 010-patch-settings-layout.sh — Patch switchboard layout
# =============================================================================
# Placeholder. Patch switchboard aktual butuh source switchboard.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="010-patch-settings-layout"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"

log_info "=== ${HOOK_NAME} ==="
log_warn "PATCH PLACEHOLDER. Patch switchboard aktual membutuhkan:"
log_warn "  1. Clone source ke upstream/switchboard"
log_warn "  2. Rewrite SwitchboardWindow untuk pakai NavigationView (sidebar)"
log_warn "  3. Apply patch dari patches/switchboard/*.patch"
log_warn "  4. Build (.deb) dan install"

# === Default landing plug ===
log_info "Set switchboard default landing"
mkdir -p /etc/dconf/db/mixos.d
cat > /etc/dconf/db/mixos.d/10-switchboard <<'EOF'
# mixos switchboard defaults
[org/pantheon/switchboard]
default-plug='appearance'
EOF

dconf update

# === Marker patch plan ===
mkdir -p /usr/share/mixos-patches
cat > /usr/share/mixos-patches/switchboard.json <<'EOF'
{
  "component": "switchboard",
  "patch_type": "macos-settings-like",
  "status": "pending-actual-patch",
  "notes": [
    "Replace grid layout dengan sidebar NavigationView",
    "Grouping: System, Personal, Hardware",
    "Tambah search bar di header",
    "Standardisasi title bar 14pt dan body 10pt",
    "Plug About: branding mixos"
  ],
  "limitations": [
    "Detail panel tidak akan 100% seragam (setiap plug render sendiri)",
    "Live preview tidak akan ditambahkan ke semua plug"
  ]
}
EOF

log_info "${HOOK_NAME} selesai (placeholder)"
exit 0
