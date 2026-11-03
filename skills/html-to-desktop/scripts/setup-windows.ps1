# Wails v2 빌드 환경 점검/설치 (Windows). 필요한 것: Go, Wails CLI, WebView2. 선택: NSIS(설치 파일).
# 사용: powershell -ExecutionPolicy Bypass -File setup-windows.ps1 [-Install] [-Nsis]
# -Install 없이 실행하면 점검만 한다. 끝에 "MISSING: ..." 또는 "READY" 한 줄을 출력한다.
# -Nsis 를 주면 NSIS 도 필수로 보고 (-Install 과 함께면) 설치한다.
param([switch]$Install, [switch]$Nsis)
$ErrorActionPreference = 'Stop'
$WailsVersion = 'v2.17.1'
$MinGo = [version]'1.26.0' # wails v2.17.1 의 go.mod 요구 버전

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path', 'User') + ';' +
              "$env:ProgramFiles\Go\bin;$env:USERPROFILE\go\bin;${env:ProgramFiles(x86)}\NSIS"
}

function Has-Cmd($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Go-Ok {
  if (-not (Has-Cmd 'go')) { return $false }
  # "go version go1.26.0 windows/amd64"
  if ((go version) -match 'go(\d+\.\d+(\.\d+)?)') { return ([version]$Matches[1] -ge $MinGo) }
  return $false
}

function Wails-Ok {
  if (-not (Has-Cmd 'wails')) { return $false }
  return ((wails version 2>$null) -match '^v2\.')
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
  if (-not (Go-Ok)) { $missing += 'go' }
  if (-not (Wails-Ok)) { $missing += 'wails' }
  if (-not (Has-WebView2)) { $missing += 'webview2' }
  if ($Nsis -and -not (Has-Cmd 'makensis')) { $missing += 'nsis' }
  return , $missing
}

function Winget-Install($id) {
  Write-Host "==> winget install $id"
  winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --silent
  # winget은 '이미 설치됨' 등에서도 0이 아닌 코드를 낸다. 성공 여부는 마지막 재점검으로 판단한다.
}

$missing = Check
if (-not $Nsis -and -not (Has-Cmd 'makensis')) { Write-Host 'INFO: NSIS 없음 (설치 파일 -nsis 빌드에만 필요, -Nsis 로 설치)' }
if ($missing.Count -eq 0) { Write-Host 'READY'; exit 0 }
if (-not $Install) { Write-Host ('MISSING: ' + ($missing -join ' ')); exit 1 }

if (($missing | Where-Object { $_ -ne 'wails' }) -and -not (Has-Cmd 'winget')) {
  Write-Host 'winget(앱 설치 관리자)이 없다. Microsoft Store에서 "App Installer"를 설치한 뒤 다시 실행하라.'
  exit 2
}

if ($missing -contains 'go') {
  # 이미 낮은 버전이 있으면 install 대신 upgrade 가 필요하다.
  if (Has-Cmd 'go') { winget upgrade --id GoLang.Go -e --source winget --accept-package-agreements --accept-source-agreements --silent }
  else { Winget-Install 'GoLang.Go' }
  Refresh-Path
}
if ($missing -contains 'webview2') { Winget-Install 'Microsoft.EdgeWebView2Runtime' }
if ($missing -contains 'nsis') { Winget-Install 'NSIS.NSIS' }
if (($missing -contains 'wails') -and (Has-Cmd 'go')) {
  Write-Host "==> go install github.com/wailsapp/wails/v2/cmd/wails@$WailsVersion"
  go install "github.com/wailsapp/wails/v2/cmd/wails@$WailsVersion"
}

$missing = Check
if ($missing.Count -eq 0) { Write-Host 'READY'; exit 0 }
Write-Host ('MISSING: ' + ($missing -join ' '))
Write-Host '설치 후에도 남아 있다면 새 터미널을 열거나 Claude Code 를 재시작한 뒤 다시 점검하라.'
exit 1
