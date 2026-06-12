#!/usr/bin/env bash
# =============================================================================
# 005-apply-pantheon-settings.sh — Terapkan default Pantheon settings
# =============================================================================
# Menjalankan config/pantheon-settings.sh dan config/dock-settings.sh.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="005-apply-pantheon-settings"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"

log_info "=== ${HOOK_NAME} ==="

# === Jalankan pantheon-settings.sh ===
if [[ -x "${PROJECT_ROOT}/config/pantheon-settings.sh" ]]; then
  log_info "Menjalankan pantheon-settings.sh"
  bash "${PROJECT_ROOT}/config/pantheon-settings.sh"
else
  log_warn "pantheon-settings.sh tidak ada atau tidak executable"
fi

# === Jalankan dock-settings.sh ===
if [[ -x "${PROJECT_ROOT}/config/dock-settings.sh" ]]; then
  log_info "Menjalankan dock-settings.sh"
  bash "${PROJECT_ROOT}/config/dock-settings.sh" "/etc/skel/.config/plank/dock1"
else
  log_warn "dock-settings.sh tidak ada atau tidak executable"
fi

# === Buat config folder untuk skel user ===
log_info "Menyiapkan /etc/skel/.config"
mkdir -p /etc/skel/.config
mkdir -p /etc/skel/.config/plank
mkdir -p /etc/skel/.config/plank/dock1
mkdir -p /etc/skel/.config/dconf
mkdir -p /etc/skel/.local
mkdir -p /etc/skel/.local/share
mkdir -p /etc/skel/.local/share/applications

# === Copy dock settings ke /etc/skel ===
if [[ -f "/etc/skel/.config/plank/dock1/settings" ]]; then
  log_info "Dock settings sudah ada di /etc/skel"
fi

log_info "${HOOK_NAME} selesai"
exit 0
