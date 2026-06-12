<#
.SYNOPSIS
  windows-prepare.ps1 — Setup WSL2 + prepare build environment untuk mixos ISO build.

.DESCRIPTION
  Script ini mengotomatiskan persiapan WSL2 untuk build ISO mixos di Windows 11.
  Menjalankan dari PowerShell sebagai Administrator.

  Step yang dilakukan:
    1. Cek admin privileges
    2. Cek hardware requirements
    3. Enable WSL2 + Virtual Machine Platform
    4. Install Debian WSL distro
    5. Setup .wslconfig
    6. Clone project dan install build deps
    7. Verifikasi environment

.NOTES
  File: scripts/windows-prepare.ps1
  Author: mixos project
  Lisensi: MIT

.EXAMPLE
  # Cek kesiapan saja (dry-run)
  .\scripts\windows-prepare.ps1 -CheckOnly

  # Full setup (butuh admin)
  .\scripts\windows-prepare.ps1 -FullSetup
#>

param(
  [switch]$CheckOnly,
  [switch]$FullSetup,
  [string]$DistroName = "Debian",
  [string]$WslUsername = "mixos",
  [string]$ProjectPath = ""
)

# === Konstanta ===
$ScriptName = "windows-prepare.ps1"
$RequiredDiskGB = 50
$RequiredRAMGB = 8

# === Colors ===
$Cyan = [System.ConsoleColor]::Cyan
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$Red = [System.ConsoleColor]::Red
$Reset = [System.ConsoleColor]::Gray

function Write-Info  { Write-Host "[INFO]  $($args -join ' ')" -ForegroundColor $Cyan }
function Write-OK    { Write-Host "[OK]    $($args -join ' ')" -ForegroundColor $Green }
function Write-Warn  { Write-Host "[WARN]  $($args -join ' ')" -ForegroundColor $Yellow }
function Write-Error { Write-Host "[ERROR] $($args -join ' ')" -ForegroundColor $Red }
function Write-Step  { Write-Host "`n=== $($args -join ' ') ===" -ForegroundColor $Green }

# === Cek Admin ===
function Test-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal $identity
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# === Cek Sistem ===
function Check-System {
  Write-Step "Cek Sistem"

  # OS Version
  $os = Get-CimInstance Win32_OperatingSystem
  Write-Info "OS: $($os.Caption) build $($os.Version)"
  if ($os.Version -lt "10.0.22000") {
    Write-Error "Minimal Windows 11 build 22000. Upgrade dulu."
    return $false
  }
  Write-OK "Windows version OK"

  # RAM
  $ramGB = $os.TotalVisibleMemorySize / 1MB
  Write-Info "RAM: $([math]::Round($ramGB, 1)) GB"
  if ($ramGB -lt $RequiredRAMGB) {
    Write-Warn "Minimal $RequiredRAMGB GB RAM direkomendasikan"
  } else {
    Write-OK "RAM OK"
  }

  # Disk
  $disk = Get-PSDrive C
  $freeGB = $disk.Free / 1GB
  Write-Info "Disk C: kosong: $([math]::Round($freeGB, 1)) GB"
  if ($freeGB -lt $RequiredDiskGB) {
    Write-Warn "Hanya $([math]::Round($freeGB, 1)) GB kosong. Build ISO butuh ~$RequiredDiskGB GB"
    Write-Warn "Bersihkan disk dulu: cleanmgr /sageset:1 & cleanmgr /sagerun:1"
  } else {
    Write-OK "Disk OK"
  }

  # Architecture
  if ($os.OSArchitecture -ne "64-bit") {
    Write-Error "Harus 64-bit untuk WSL2"
    return $false
  }
  Write-OK "Architecture OK"

  # Virtualization
  $virt = Get-CimInstance Win32_ComputerSystem
  if ($virt.HypervisorPresent) {
    Write-OK "Virtualization enabled"
  } else {
    Write-Warn "Virtualization NOT detected. Enable di BIOS."
    Write-Warn "Cek: taskmgr > Performance > Virtualization: Enabled"
  }

  return $true
}

# === Cek WSL ===
function Check-WSL {
  Write-Step "Cek WSL Status"

  $wslPath = Get-Command "wsl.exe" -ErrorAction SilentlyContinue
  if (-not $wslPath) {
    Write-Warn "wsl.exe tidak ditemukan"
    return $false
  }

  try {
    $wslStatus = & wsl --status 2>&1 | Out-String
    Write-Info $wslStatus.Trim()

    $wslList = & wsl -l -v 2>&1 | Out-String
    Write-Info $wslList.Trim()

    # Cek apakah Debian sudah terinstall
    if ($wslList -match "Debian") {
      Write-OK "Debian WSL sudah terinstall"
      return $true
    }
  } catch {
    Write-Warn "WSL belum terinstall sempurna"
    return $false
  }

  Write-Warn "Debian belum terinstall"
  return $false
}

# === Enable WSL ===
function Enable-WSL {
  Write-Step "Enable WSL2"

  if (-not (Test-Admin)) {
    Write-Error "Harus Administrator untuk mengaktifkan WSL"
    Write-Info "Jalankan ulang PowerShell sebagai Administrator"
    return $false
  }

  try {
    Write-Info "Enable VirtualMachinePlatform..."
    & dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>&1 | Out-Null

    Write-Info "Enable WSL..."
    & dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>&1 | Out-Null

    Write-Info "Set WSL2 default..."
    & wsl --set-default-version 2 2>$null

    Write-OK "WSL2 enabled (mungkin perlu restart)"
    Write-Warn "Restart komputer dulu sebelum lanjut ke install Debian"
    return $true
  } catch {
    Write-Error "Gagal enable WSL: $_"
    return $false
  }
}

# === Install Debian ===
function Install-DebianWSL {
  Write-Step "Install Debian WSL"

  try {
    Write-Info "Download dan install Debian dari Microsoft Store..."
    & wsl --install -d Debian 2>&1

    Write-OK "Debian WSL terinstall"
    Write-Warn "Selesaikan setup: buka 'Debian' dari Start Menu"
    Write-Warn "Buat username dan password untuk WSL user"
    return $true
  } catch {
    Write-Error "Gagal install Debian: $_"
    return $false
  }
}

# === Setup WSL config ===
function Setup-WSLConfig {
  Write-Step "Setup .wslconfig"

  $wslConfig = "$env:USERPROFILE\.wslconfig"
  $content = @"
[wsl2]
memory=8GB
processors=4
localhostForwarding=true
swap=4GB
"@

  if (-not (Test-Path $wslConfig)) {
    Write-Info "Membuat $wslConfig"
    Set-Content -Path $wslConfig -Value $content -Encoding UTF8
    Write-OK ".wslconfig created"
  } else {
    Write-Info ".wslconfig sudah ada, skip"
  }
}

# === Setup di dalam WSL ===
function Setup-InWSL {
  Write-Step "Setup Build Dependencies di WSL"

  $wslSetup = @'
set -e
echo "=== Update & Upgrade ==="
sudo apt update
sudo apt upgrade -y

echo "=== Install Build Tools ==="
sudo apt install -y \
  debootstrap live-build xorriso isolinux \
  syslinux-common grub-pc-bin grub-efi-amd64-bin \
  grub-efi-ia32-bin mtools squashfs-tools genisoimage \
  git curl wget rsync p7zip-full unzip

echo "=== Setup selesai ==="
echo "Check environment:"
debootstrap --version
xorriso --version | head -1
git --version
'@

  try {
    Write-Info "Menjalankan setup di dalam WSL Debian..."
    & wsl -d Debian bash -c $wslSetup 2>&1 | ForEach-Object { Write-Info $_ }
    Write-OK "Build dependencies installed"
    return $true
  } catch {
    Write-Error "Gagal setup di WSL: $_"
    return $false
  }
}

# === Copy project ke WSL ===
function Copy-ProjectToWSL {
  param([string]$SourcePath)

  Write-Step "Copy Project ke WSL"

  if (-not $SourcePath -or -not (Test-Path $SourcePath)) {
    Write-Warn "Project path tidak valid. Copy manual:"
    Write-Warn "  cd $SourcePath"
    Write-Warn "  wsl cp -r . ~/mixos"
    return $false
  }

  try {
    Write-Info "Copy dari $SourcePath ke WSL ~/mixos"
    & wsl cp -r "$SourcePath" ~/mixos 2>$null

    # Verify
    $result = & wsl ls ~/mixos/build.sh 2>&1
    if ($result -match "build.sh") {
      Write-OK "Project copied to WSL ~/mixos"
      return $true
    }
  } catch {
    Write-Warn "Auto-copy gagal. Copy manual:"
  }

  Write-Warn "Manual: cd $SourcePath && wsl cp -r . ~/mixos"
  return $false
}

# === Main ===
function Main {
  Write-Host "=== mixos — Windows Preparation Tool ===" -ForegroundColor $Cyan
  Write-Host "Script: $ScriptName" -ForegroundColor $Gray
  Write-Host ""

  if (-not (Check-System)) {
    Write-Error "Sistem tidak memenuhi syarat"
    exit 1
  }

  $wslInstalled = Check-WSL

  if ($CheckOnly) {
    Write-Step "Check Only Mode"
    if ($wslInstalled) {
      Write-OK "System siap untuk build mixos"
      Write-Info "Lanjut: copy project ke WSL dan jalankan ./build.sh --no-dry-run"
    } else {
      Write-Warn "WSL2 belum siap. Jalankan: $ScriptName -FullSetup"
    }
    return
  }

  if ($FullSetup) {
    if (-not (Test-Admin)) {
      Write-Error "FullSetup butuh Administrator. Restart PowerShell as Admin."
      exit 1
    }

    if (-not $wslInstalled) {
      Enable-WSL
      Write-Warn "Restart komputer dulu, lalu jalankan ulang script"
      # Jangan lanjut karena perlu restart
      return
    }

    Setup-WSLConfig

    # Shutdown WSL untuk apply config
    & wsl --shutdown
    Start-Sleep -Seconds 3

    Setup-InWSL
    Copy-ProjectToWSL -SourcePath $ProjectPath

    Write-Step "Setup Selesai"
    Write-OK "Langkah selanjutnya:"
    Write-Info "  1. Buka WSL: wsl -d Debian"
    Write-Info "  2. cd ~/mixos"
    Write-Info "  3. Cek environment: ./scripts/prepare-build-env.sh"
    Write-Info "  4. Clone upstream: ./scripts/clone-upstream.sh"
    Write-Info "  5. Build ISO: ./build.sh --no-dry-run"
    Write-Info ""
    Write-Info "  Lihat docs/BUILD_ON_WINDOWS.md untuk detail lengkap."
  }
}

Main
