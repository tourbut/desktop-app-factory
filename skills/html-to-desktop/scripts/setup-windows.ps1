# Tauri v2 빌드 환경 점검/설치 (Windows).
# 사용: powershell -ExecutionPolicy Bypass -File setup-windows.ps1 [-Install]
# -Install 없이 실행하면 점검만 한다. 끝에 "MISSING: ..." 또는 "READY" 한 줄을 출력한다.
param([switch]$Install)
$ErrorActionPreference = 'Stop'

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path', 'User') + ';' +
              "$env:USERPROFILE\.cargo\bin"
}

function Has-Cmd($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Has-MSVC {
  $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
  if (-not (Test-Path $vswhere)) { return $false }
  $paths = & $vswhere -all -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  # 컴포넌트가 등록돼 있어도 bin 이 빈 깨진 설치가 있다. link.exe 실물로 확인한다.
  $hasLinker = $false
  foreach ($p in $paths) {
    if (Get-ChildItem "$p\VC\Tools\MSVC\*\bin\Hostx64\x64\link.exe" -ErrorAction SilentlyContinue) { $hasLinker = $true }
  }
  # 링커만 있고 Windows SDK가 없으면 LNK1181 'kernel32.lib' 로 실패한다.
  $hasSdk = [bool](Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\Lib\*\um\x64\kernel32.lib" -ErrorAction SilentlyContinue)
  return ($hasLinker -and $hasSdk)
}

function Has-WebView2 {
  $keys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
    'HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
  )
  foreach ($k in $keys) {
    $v = (Get-ItemProperty $k -ErrorAction SilentlyContinue).pv
    if ($v -and $v -ne '0.0.0.0') { return $true }
  }
  return $false
}

function Check {
  Refresh-Path
  $missing = @()
  if (-not (Has-MSVC)) { $missing += 'msvc' }
  if (-not (Has-WebView2)) { $missing += 'webview2' }
  if (-not (Has-Cmd 'cargo')) { $missing += 'rust' }
  if (-not (Has-Cmd 'node')) { $missing += 'node' }
  return , $missing
}

function Winget-Install($id, [string[]]$extra = @()) {
  Write-Host "==> winget install $id"
  winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --silent @extra
  # winget은 '이미 설치됨' 등에서도 0이 아닌 코드를 낸다. 성공 여부는 마지막 재점검으로 판단한다.
}

$missing = Check
if ($missing.Count -eq 0) { Write-Host 'READY'; exit 0 }
if (-not $Install) { Write-Host ('MISSING: ' + ($missing -join ' ')); exit 1 }

if (-not (Has-Cmd 'winget')) {
  Write-Host 'winget(앱 설치 관리자)이 없다. Microsoft Store에서 "App Installer"를 설치한 뒤 다시 실행하라.'
  exit 2
}

if ($missing -contains 'msvc') {
  # 'C++를 사용한 데스크톱 개발' 워크로드. 수 GB, 관리자 권한(UAC) 필요.
  Winget-Install 'Microsoft.VisualStudio.2022.BuildTools' @('--override', '--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
}
if ($missing -contains 'webview2') { Winget-Install 'Microsoft.EdgeWebView2Runtime' }
if ($missing -contains 'node') { Winget-Install 'OpenJS.NodeJS.LTS' }
if ($missing -contains 'rust') {
  Winget-Install 'Rustlang.Rustup'
  Refresh-Path
  if (Has-Cmd 'rustup') { rustup default stable-msvc }
}

$missing = Check
if ($missing.Count -eq 0) { Write-Host 'READY'; exit 0 }
Write-Host ('MISSING: ' + ($missing -join ' '))
Write-Host '설치 후에도 남아 있다면 새 터미널을 열거나 재부팅한 뒤 다시 점검하라.'
exit 1
