#!/usr/bin/env bash
# =============================================================================
# 006-apply-macos-like-layout.sh — Terapkan layout macOS-inspired
# =============================================================================
# Menjalankan display-settings.sh, default-settings.sh, keyboard-shortcuts.sh.
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="006-apply-macos-like-layout"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"

log_info "=== ${HOOK_NAME} ==="

# === Jalankan default-settings.sh ===
if [[ -x "${PROJECT_ROOT}/config/default-settings.sh" ]]; then
  log_info "Menjalankan default-settings.sh"
  bash "${PROJECT_ROOT}/config/default-settings.sh"
fi

# === Jalankan display-settings.sh ===
if [[ -x "${PROJECT_ROOT}/config/display-settings.sh" ]]; then
  log_info "Menjalankan display-settings.sh"
  bash "${PROJECT_ROOT}/config/display-settings.sh"
fi

# === Jalankan keyboard-shortcuts.sh ===
if [[ -x "${PROJECT_ROOT}/config/keyboard-shortcuts.sh" ]]; then
  log_info "Menjalankan keyboard-shortcuts.sh"
  bash "${PROJECT_ROOT}/config/keyboard-shortcuts.sh"
fi

# === Setup locale ===
if [[ -f "${PROJECT_ROOT}/config/locale.conf" ]]; then
  log_info "Menulis /etc/default/locale"
  # shellcheck disable=SC1090
  source "${PROJECT_ROOT}/config/locale.conf"
  cat > /etc/default/locale <<EOF
LANG=${LANG}
LANGUAGE=${LANGUAGE}
LC_ALL=${LC_ALL}
EOF
fi

# === Keyboard layout (XKB) ===
readonly XKB_CONFIG="/etc/default/keyboard"
if [[ -f "${PROJECT_ROOT}/config/locale.conf" ]]; then
  # shellcheck disable=SC1090
  source "${PROJECT_ROOT}/config/locale.conf"
  log_info "Menulis ${XKB_CONFIG}"
  cat > "${XKB_CONFIG}" <<EOF
XKBLAYOUT="${XKBLAYOUT}"
XKBVARIANT="${XKBVARIANT}"
XKBOPTIONS="${XKBOPTIONS}"
EOF
fi

# === Timezone ===
if [[ -f /etc/timezone ]]; then
  if [[ -n "${TZ:-}" ]]; then
    log_info "Set timezone: ${TZ}"
    echo "${TZ}" > /etc/timezone
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
  fi
fi

log_info "${HOOK_NAME} selesai"
exit 0
