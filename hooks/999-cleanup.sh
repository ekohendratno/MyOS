#!/usr/bin/env bash
# =============================================================================
# 999-cleanup.sh — Cleanup akhir chroot
# =============================================================================
# - Bersihkan apt cache
# - Bersihkan temporary files
# - Hapus bash history
# - Hapus log
# - Cleanup machine-id
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="999-cleanup"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

log_info "=== ${HOOK_NAME} ==="

# === apt cleanup ===
log_info "apt-get clean"
apt-get clean
rm -rf /var/lib/apt/lists/* 2>/dev/null || true
rm -rf /var/cache/apt/archives/*.deb 2>/dev/null || true

# === Hapus doc dan cache yang tidak perlu ===
log_info "Menghapus doc dan cache"
rm -rf /usr/share/doc/* 2>/dev/null || true
rm -rf /usr/share/man/* 2>/dev/null || true
rm -rf /usr/share/locale/* 2>/dev/null || true
rm -rf /usr/share/info/* 2>/dev/null || true

# === Hapus bash history user root ===
log_info "Membersihkan history bash"
rm -f /root/.bash_history 2>/dev/null || true
rm -f /home/*/.bash_history 2>/dev/null || true

# === Hapus log ===
log_info "Membersihkan log"
find /var/log -type f -name '*.log' -delete 2>/dev/null || true
find /var/log -type f -name '*.gz' -delete 2>/dev/null || true
find /tmp -type f -delete 2>/dev/null || true
find /var/tmp -type f -delete 2>/dev/null || true

# === Reset machine-id (akan di-generate saat first boot) ===
log_info "Reset machine-id"
truncate -s 0 /etc/machine-id 2>/dev/null || true
rm -f /var/lib/dbus/machine-id 2>/dev/null || true

# === Hapus SSH host key (akan di-generate saat first boot) ===
log_info "Hapus SSH host key"
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true

# === Hapus cache mixos-patches marker (sudah dicatat di build log) ===
# TIDAK dihapus, untuk dokumentasi

# === Hapus cache live-build temporary ===
log_info "Membersihkan cache live-build"
rm -rf /tmp/*.tmp 2>/dev/null || true
rm -rf /var/cache/live 2>/dev/null || true
rm -rf /var/lib/live 2>/dev/null || true

log_info "${HOOK_NAME} selesai — chroot siap untuk squashfs"
exit 0
