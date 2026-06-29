#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/home/srv/mixos}"
LOG_OUT="${LOG_OUT:-${ROOT_DIR}/logs/build-native.out.log}"
LOG_ERR="${LOG_ERR:-${ROOT_DIR}/logs/build-native.err.log}"

fmt_size() {
  local size="${1:-0}"
  numfmt --to=iec --suffix=B "${size}" 2>/dev/null || echo "${size}B"
}

count_files() {
  local path="$1"
  if [ -d "${path}" ]; then
    find "${path}" -type f 2>/dev/null | wc -l
  else
    echo 0
  fi
}

dir_size() {
  local path="$1"
  if [ -e "${path}" ]; then
    du -sb "${path}" 2>/dev/null | awk '{print $1}'
  else
    echo 0
  fi
}

sum_newer_bytes() {
  local ref="$1"
  shift
  local total=0
  local f size
  for f in "$@"; do
    if [ -d "${f}" ] && [ -e "${ref}" ]; then
      while IFS= read -r size; do
        total=$((total + size))
      done < <(find "${f}" -type f -newer "${ref}" -printf '%s\n' 2>/dev/null || true)
    fi
  done
  echo "${total}"
}

newer_file_count() {
  local path="$1"
  local ref="$2"
  if [ -d "${path}" ] && [ -e "${ref}" ]; then
    find "${path}" -type f -newer "${ref}" 2>/dev/null | wc -l
  else
    echo 0
  fi
}

last_progress() {
  if [ -f "${LOG_OUT}" ]; then
    grep -oE '\[[0-9]{1,3}%\]' "${LOG_OUT}" | tail -n 1 | tr -d '[]' || true
  fi
}

largest_files() {
  local path="$1"
  if [ -d "${path}" ]; then
    find "${path}" -type f -printf '%s\t%p\n' 2>/dev/null | sort -nr | head -n 8
  fi
}

cache_summary() {
  local apt_cache="/var/cache/apt/archives"
  local lb_cache="${ROOT_DIR}/builds/work-amd64/cache"
  local chroot_cache="/var/cache/mixos-build-chroot/var/cache/apt/archives"
  local ref="${LOG_OUT}"
  local total_files used_files unused_files total_bytes used_bytes unused_bytes
  total_files=$(( $(count_files "${apt_cache}") + $(count_files "${lb_cache}") + $(count_files "${chroot_cache}") ))
  used_files=$(( $(newer_file_count "${apt_cache}" "${ref}") + $(newer_file_count "${lb_cache}" "${ref}") + $(newer_file_count "${chroot_cache}" "${ref}") ))
  unused_files=$(( total_files - used_files ))
  total_bytes=$(( $(dir_size "${apt_cache}") + $(dir_size "${lb_cache}") + $(dir_size "${chroot_cache}") ))
  used_bytes=$(sum_newer_bytes "${ref}" "${apt_cache}" "${lb_cache}" "${chroot_cache}")
  unused_bytes=$(( total_bytes - used_bytes ))
  echo "APT cache:      $(count_files "${apt_cache}") files, $(fmt_size "$(dir_size "${apt_cache}")")"
  echo "LB cache:       $(count_files "${lb_cache}") files, $(fmt_size "$(dir_size "${lb_cache}")")"
  echo "Chroot cache:   $(count_files "${chroot_cache}") files, $(fmt_size "$(dir_size "${chroot_cache}")")"
  echo "Build logs:     $(count_files "${ROOT_DIR}/logs") files, $(fmt_size "$(dir_size "${ROOT_DIR}/logs")")"
  if [ "${total_files}" -gt 0 ]; then
    echo "Cache used:     ${used_files}/${total_files} files ($(( used_files * 100 / total_files ))%)"
  else
    echo "Cache used:     n/a"
  fi
  if [ "${total_bytes}" -gt 0 ]; then
    echo "Bytes used:     $(fmt_size "${used_bytes}") / $(fmt_size "${total_bytes}") ($(( used_bytes * 100 / total_bytes ))%)"
    echo "Bytes unused:   $(fmt_size "${unused_bytes}") / $(fmt_size "${total_bytes}") ($(( unused_bytes * 100 / total_bytes ))%)"
  else
    echo "Bytes used:     n/a"
  fi
}

while true; do
  clear
  echo "MixOS build monitor"
  echo "Time: $(date)"
  echo "Root: ${ROOT_DIR}"
  echo "Progress: ${last_progress:-n/a}"
  echo

  echo "Processes:"
  pgrep -af 'run-native-build|./build.sh|lb build|apt-get -o DPkg::Options::=--force-confnew|dpkg-buildpackage|mmdebstrap' || echo "  (none)"
  echo

  echo "Cache summary:"
  cache_summary
  echo

  echo "Largest cache files:"
  largest_files "/var/cache/apt/archives" | awk -F'\t' '{printf "  %s  %s\n", $1, $2}' || true
  echo

  echo "Latest output:"
  tail -n 20 "${LOG_OUT}" 2>/dev/null || echo "  (no output log yet)"
  echo

  echo "Latest errors:"
  tail -n 20 "${LOG_ERR}" 2>/dev/null || echo "  (no error log yet)"
  echo

  echo "Press Ctrl+C to stop. Refreshes every 10 seconds."
  sleep 10
done
