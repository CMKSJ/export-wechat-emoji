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
# Windows 惯例：每用户程序安装到 %LOCALAPPDATA%\Programs（VS Code 用户安装、winget portable 同款位置）
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\wxemoticon' }
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

  # 自动加入用户 PATH（写注册表 HKCU\Environment，幂等；设 WXEMOTICON_NO_PATH_MODIFY=1 可跳过）
  $NormDir = $InstallDir.TrimEnd('\').ToLowerInvariant()
  $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $InPath = @($UserPath -split ';' | ForEach-Object { $_.Trim().TrimEnd('\').ToLowerInvariant() } |
    Where-Object { $_ -eq $NormDir }).Count -gt 0
  if ($InPath) {
    Write-Host "PATH 已包含 $InstallDir"
  } elseif ($env:WXEMOTICON_NO_PATH_MODIFY) {
    Write-Host "已跳过 PATH 修改（WXEMOTICON_NO_PATH_MODIFY 已设置），请自行把 $InstallDir 加入 PATH"
  } else {
    if ([string]::IsNullOrEmpty($UserPath)) {
      $NewPath = $InstallDir
    } else {
      $NewPath = $UserPath.TrimEnd(';') + ';' + $InstallDir
    }
    [Environment]::SetEnvironmentVariable('Path', $NewPath, 'User')
    Write-Host "已把 $InstallDir 加入用户 PATH（新开终端生效）"
  }
} finally {
  Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}
