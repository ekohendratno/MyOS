#!/usr/bin/env bash
# =============================================================================
# 008-patch-titlebar-size.sh — Patch titlebar size dan window control position
# =============================================================================
# Placeholder. Patch gala yang sebenarnya membutuhkan source code gala
# yang di-clone dan dipatch. Hook ini HANYA mencatat patch yang akan
# diterapkan, dan set gsettings default untuk override.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="008-patch-titlebar-size"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"

log_info "=== ${HOOK_NAME} ==="
log_warn "PATCH PLACEHOLDER. Patch gala aktual membutuhkan:"
log_warn "  1. Clone gala source ke upstream/gala"
log_warn "  2. Apply patch dari patches/gala/*.patch"
log_warn "  3. Build ulang gala (.deb)"
log_warn "  4. Install .deb ke chroot"
log_warn ""
log_warn "Untuk tahap awal, hanya override gsettings yang dipakai:"

# === Override gsettings untuk titlebar ===
# CATATAN: ini tidak benar-benar mengubah ukuran titlebar pixel, hanya
# mengatur beberapa property yang mungkin bisa di-respecting. Patch
# gala yang sebenarnya dibutuhkan untuk perubahan struktural.
log_info "Menulis default gsettings untuk titlebar"
mkdir -p /etc/dconf/db/mixos.d
cat > /etc/dconf/db/mixos.d/08-titlebar <<'EOF'
# mixos titlebar (best-effort, butuh patch gala untuk full effect)
[org/gnome/desktop/wm/preferences]
titlebar-font='Inter Semibold 10'
button-layout='close,minimize,maximize:menu'
EOF

dconf update

# === Simpan marker bahwa patch akan diterapkan saat build ===
mkdir -p /usr/share/mixos-patches
cat > /usr/share/mixos-patches/titlebar.json <<'EOF'
{
  "component": "gala",
  "patch_type": "titlebar-size",
  "status": "pending-actual-patch",
  "notes": [
    "Mengubah DEFAULT_TITLEBAR_HEIGHT dari 28 ke 24 di src/WindowControls.vala",
    "Mengubah DEFAULT_BUTTON_PADDING dari 8 ke 4",
    "Memindahkan window controls ke kiri di src/WindowFrame.vala",
    "Mengubah titlebar font size dari 11pt ke 10pt"
  ]
}
EOF

log_info "${HOOK_NAME} selesai (placeholder, patch aktual belum di-apply)"
exit 0
