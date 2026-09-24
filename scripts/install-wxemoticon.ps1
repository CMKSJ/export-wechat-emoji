<#
wxemoticon installer (Windows)

Usage (cmd / PowerShell):
  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/liusheng22/export-wechat-emoji/main/scripts/install-wxemoticon.ps1 | iex"

Options:
  $env:WXEMOTICON_REPO           default: liusheng22/export-wechat-emoji
  $env:INSTALL_DIR               default: %LOCALAPPDATA%\Programs\wxemoticon
  $env:WXEMOTICON_VERSION        default: latest
  $env:WXEMOTICON_NO_PATH_MODIFY set to skip adding INSTALL_DIR to the user PATH

NOTE: keep this file ASCII-only and BOM-less. PowerShell 5.1 reads BOM-less
scripts as ANSI (garbling non-ASCII), while a UTF-8 BOM breaks the
"irm | iex" one-liner (the BOM survives HTTP decoding as U+FEFF).
#>

$ErrorActionPreference = 'Stop'

$Repo = if ($env:WXEMOTICON_REPO) { $env:WXEMOTICON_REPO } else { 'liusheng22/export-wechat-emoji' }
# Windows convention: per-user programs live under %LOCALAPPDATA%\Programs
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\wxemoticon' }
$Version = if ($env:WXEMOTICON_VERSION) { $env:WXEMOTICON_VERSION } else { 'latest' }

if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
  throw "unsupported architecture: $($env:PROCESSOR_ARCHITECTURE) (x86_64 only)"
}

$Asset = 'wxemoticon-x86_64-windows.zip'

if ($Version -eq 'latest') {
  $Url = "https://github.com/$Repo/releases/latest/download/$Asset"
} else {
  $Url = "https://github.com/$Repo/releases/download/$Version/$Asset"
}

$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wxemoticon-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TmpDir | Out-Null

try {
  Write-Host "download: $Url"
  $ProgressPreference = 'SilentlyContinue'
  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile (Join-Path $TmpDir $Asset)

  Expand-Archive -Path (Join-Path $TmpDir $Asset) -DestinationPath $TmpDir -Force

  $Exe = Join-Path $TmpDir 'wxemoticon.exe'
  if (-not (Test-Path $Exe)) {
    throw 'invalid package: wxemoticon.exe not found'
  }

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  Copy-Item $Exe (Join-Path $InstallDir 'wxemoticon.exe') -Force

  Write-Host "installed: $InstallDir\wxemoticon.exe"
  Write-Host 'verify: wxemoticon --help'

  # Add to the user PATH (HKCU\Environment, idempotent).
  $NormDir = $InstallDir.TrimEnd('\').ToLowerInvariant()
  $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $InPath = @($UserPath -split ';' | ForEach-Object { $_.Trim().TrimEnd('\').ToLowerInvariant() } |
    Where-Object { $_ -eq $NormDir }).Count -gt 0
  if ($InPath) {
    Write-Host "PATH already contains $InstallDir"
  } elseif ($env:WXEMOTICON_NO_PATH_MODIFY) {
    Write-Host "skipped PATH modification (WXEMOTICON_NO_PATH_MODIFY is set); add $InstallDir to PATH manually"
  } else {
    if ([string]::IsNullOrEmpty($UserPath)) {
      $NewPath = $InstallDir
    } else {
      $NewPath = $UserPath.TrimEnd(';') + ';' + $InstallDir
    }
    [Environment]::SetEnvironmentVariable('Path', $NewPath, 'User')
    Write-Host "added $InstallDir to user PATH (takes effect in new terminals)"
  }
} finally {
  Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}
