#!/usr/bin/env bash
# =============================================================================
# 011-security-hardening.sh — Terapkan baseline security
# =============================================================================
# - Disable root login
# - Setup ufw default deny
# - Disable services yang tidak perlu
# - Set permissions yang aman
# - Setup fail2ban (opsional)
# =============================================================================

set -euo pipefail

readonly HOOK_NAME="011-security-hardening"

log_info()  { printf "[%s] [INFO]  %s\n"  "$(date +%H:%M:%S)" "$*"; }
log_warn()  { printf "[%s] [WARN]  %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }
log_error() { printf "[%s] [ERROR] %s\n"  "$(date +%H:%M:%S)" "$*" >&2; }

readonly HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${HOOK_DIR}/../.." && pwd)"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/mixos.conf"

# shellcheck disable=SC1090
source "${CONFIG_FILE}" 2>/dev/null || {
  log_error "Config tidak ditemukan"
  exit 1
}

log_info "=== ${HOOK_NAME} ==="

ENABLE_SECURITY_HARDENING="${ENABLE_SECURITY_HARDENING:-true}"

if [[ "${ENABLE_SECURITY_HARDENING}" != "true" ]]; then
  log_info "ENABLE_SECURITY_HARDENING=false, skip"
  exit 0
fi

# === 1. Lock root account (tidak bisa login) ===
log_info "Lock root account"
passwd -l root 2>/dev/null || true

# === 2. Setup ufw ===
if [[ "${ENABLE_FIREWALL_UFW:-true}" == "true" ]]; then
  log_info "Setup ufw default deny"
  if command -v ufw >/dev/null 2>&1; then
    # Setup di chroot, hanya tulis config. ufw aktif saat runtime.
    cat > /etc/ufw/ufw.conf <<'EOF'
ENABLED=no
LOGLEVEL=low
EOF
    # Default policy via /etc/default/ufw
    sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/' /etc/default/ufw 2>/dev/null || true
    sed -i 's/^DEFAULT_OUTPUT_POLICY=.*/DEFAULT_OUTPUT_POLICY="ACCEPT"/' /etc/default/ufw 2>/dev/null || true
    log_info "ufw config ditulis (aktif saat first boot oleh service)"
  else
    log_warn "ufw tidak terinstall, skip"
  fi
fi

# === 3. Disable SSH jika tidak perlu ===
if [[ "${ENABLE_SSHD:-false}" != "true" ]]; then
  log_info "Disable SSH server"
  if [[ -f /etc/ssh/sshd_not_to_be_run ]]; then
    echo "ListenAddress 0.0.0.0" > /etc/ssh/sshd_not_to_be_run
  fi
  systemctl disable ssh.service 2>/dev/null || true
  systemctl disable sshd.service 2>/dev/null || true
fi

# === 4. Set permission yang aman ===
log_info "Set permission aman"
chmod 644 /etc/passwd
chmod 000 /etc/shadow
chmod 000 /etc/gshadow
chmod 644 /etc/group
chmod 600 /etc/crontab 2>/dev/null || true

# === 5. Setup sysctl (network hardening) ===
log_info "Setup sysctl hardening"
cat > /etc/sysctl.d/99-mixos-security.conf <<'EOF'
# mixos security baseline

# IP forwarding (off, mixos adalah desktop, bukan router)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_abort_on_overflow = 1

# Ignore ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore source routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable IP redirect
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Kernel hardening
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2

# Filesystem
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

# === 6. Disable core dumps ===
log_info "Disable core dumps"
cat > /etc/security/limits.d/10-mixos-core.conf <<'EOF'
* hard core 0
* soft core 0
EOF

# === 7. Setup AppArmor ===
log_info "Aktifkan AppArmor"
if command -v aa-enabled >/dev/null 2>&1; then
  systemctl enable apparmor.service 2>/dev/null || true
fi

# === 8. Set telemetry off (mixos WAJIB no telemetry) ===
log_info "Disable semua telemetry"
mkdir -p /etc/dconf/db/mixos.d
cat > /etc/dconf/db/mixos.d/11-security <<'EOF'
# mixos privacy
[org/gnome/desktop/privacy]
report-technical-problems=false
EOF

# === 9. Hapus paket telemetry (jika terinstall) ===
# HATI-HATI: ini best-effort, paket tertentu mungkin tidak ada
TELEMETRY_PKGS=(
  "whoopsie"
  "ubuntu-report"
  "popularity-contest"
  "apport"
)
for pkg in "${TELEMETRY_PKGS[@]}"; do
  if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "install ok installed"; then
    log_info "Remove: ${pkg}"
    apt-get remove -y --purge "${pkg}" 2>/dev/null || log_warn "Gagal remove ${pkg}"
  fi
done

dconf update
apt-get autoremove -y 2>/dev/null || true

log_info "${HOOK_NAME} selesai"
exit 0
