#Requires -Version 5.1
<#
wxemoticon installer (Windows)

Usage:
  irm https://raw.githubusercontent.com/liusheng22/export-wechat-emoji/main/scripts/install-wxemoticon.ps1 | iex

Options:
  $env:INSTALL_DIR          default: %USERPROFILE%\.local\bin
  $env:WXEMOTICON_VERSION   default: latest
  $env:WXEMOTICON_REPO      default: liusheng22/export-wechat-emoji
#>

$ErrorActionPreference = 'Stop'

$Repo = if ($env:WXEMOTICON_REPO) { $env:WXEMOTICON_REPO } else { 'liusheng22/export-wechat-emoji' }
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:USERPROFILE '.local\bin' }
$Version = if ($env:WXEMOTICON_VERSION) { $env:WXEMOTICON_VERSION } else { 'latest' }

if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
  throw "仅支持 x86_64（当前：$($env:PROCESSOR_ARCHITECTURE)）"
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
  Write-Host "下载：$Url"
  $ProgressPreference = 'SilentlyContinue'
  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile (Join-Path $TmpDir $Asset)

  Expand-Archive -Path (Join-Path $TmpDir $Asset) -DestinationPath $TmpDir -Force

  $Exe = Join-Path $TmpDir 'wxemoticon.exe'
  if (-not (Test-Path $Exe)) {
    throw '安装包结构不正确：缺少 wxemoticon.exe'
  }

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  Copy-Item $Exe (Join-Path $InstallDir 'wxemoticon.exe') -Force

  Write-Host "安装完成：$InstallDir\wxemoticon.exe"
  Write-Host '验证：wxemoticon --help'

  $InPath = ($env:PATH -split ';' | ForEach-Object { $_.TrimEnd('\') } | Where-Object { $_ -eq $InstallDir.TrimEnd('\') }).Count -gt 0
  if (-not $InPath) {
    Write-Host ''
    Write-Host "提示：你的 PATH 里可能还没有 $InstallDir"
    Write-Host '可把下面这行加到 PowerShell 配置文件（$PROFILE）后重开终端：'
    Write-Host "  `$env:Path += `";$InstallDir`""
  }
} finally {
  Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}
