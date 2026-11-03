# Wails v2 빌드 환경 점검/설치 (Windows). 필요한 것: Go, Wails CLI, WebView2. 선택: NSIS(설치 파일).
# 사용: powershell -ExecutionPolicy Bypass -File setup-windows.ps1 [-Install] [-Nsis]
# -Install 없이 실행하면 점검만 한다. 항목별 상태를 출력하고 끝에 "MISSING: ..." 또는 "READY" 한 줄을 출력한다.
# -Nsis 를 주면 NSIS 도 필수로 보고 (-Install 과 함께면) 설치한다.
param([switch]$Install, [switch]$Nsis)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # PowerShell 5.1 의 진행 표시줄은 다운로드를 크게 느리게 한다
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$WailsVersion = 'v2.17.1'
$MinGo = [version]'1.26.0' # wails v2.17.1 의 go.mod 요구 버전
$GoZipDir = "$env:LOCALAPPDATA\Programs\Go" # winget 이 없을 때 관리자 권한 없이 설치하는 위치

function Refresh-Path {
  # 사용자 설치 Go 를 앞에 둔다. Machine PATH 의 오래된 Go 가 가리지 않게 한다.
  $env:Path = "$GoZipDir\bin;" +
              [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path', 'User') + ';' +
              "$env:ProgramFiles\Go\bin;$env:USERPROFILE\go\bin;${env:ProgramFiles(x86)}\NSIS"
}

function Has-Cmd($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Go-Version {
  if (-not (Has-Cmd 'go')) { return $null }
  # "go version go1.26.0 windows/amd64"
  if ((go version) -match 'go(\d+\.\d+(\.\d+)?)') { return [version]$Matches[1] }
  return $null
}

function Wails-Version {
  if (-not (Has-Cmd 'wails')) { return $null }
  $v = (wails version 2>$null | Select-Object -First 1)
  if ($v -match '^v2\.') { return $v }
  return $null
}

function WebView2-Version {
  $keys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
    'HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
  )
  foreach ($k in $keys) {
    $v = (Get-ItemProperty $k -ErrorAction SilentlyContinue).pv
    if ($v -and $v -ne '0.0.0.0') { return $v }
  }
  return $null
}

function Check {
  Refresh-Path
  $missing = @()
  $go = Go-Version
  if ($go -and $go -ge $MinGo) { $s = "[OK]   Go $go" }
  else {
    $missing += 'go'
    $s = if ($go) { "[부족] Go $go -> $MinGo 이상 필요 (업그레이드, 약 300MB)" } else { "[없음] Go -> $MinGo 이상 설치 필요 (약 300MB)" }
  }
  Write-Host $s

  $w = Wails-Version
  if ($w) { $s = "[OK]   Wails CLI $w" } else { $missing += 'wails'; $s = "[없음] Wails CLI -> go install 로 설치 (관리자 권한 불필요, 약 1~2분)" }
  Write-Host $s

  $wv = WebView2-Version
  if ($wv) { $s = "[OK]   WebView2 $wv" } else { $missing += 'webview2'; $s = "[없음] WebView2 런타임 -> 설치 필요 (약 150MB)" }
  Write-Host $s

  if (Has-Cmd 'makensis') { $s = '[OK]   NSIS (설치 파일 만들기)' }
  elseif ($Nsis) { $missing += 'nsis'; $s = '[없음] NSIS -> 설치 필요 (약 5MB)' }
  else { $s = '[선택] NSIS 없음 -> 설치 파일(-nsis)을 만들 때만 필요. -Nsis 로 설치' }
  Write-Host $s
  return , $missing
}

function Winget-Install($id) {
  Write-Host "==> winget install $id"
  winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --silent
  # winget은 '이미 설치됨' 등에서도 0이 아닌 코드를 낸다. 성공 여부는 재점검으로 판단한다.
}

function Download($url, $file) {
  Write-Host "==> 다운로드 $url"
  # Windows 기본 curl.exe(별도 프로세스)를 쓴다. 이유는 Install-GoZip 의 tar.exe 주석 참고.
  & "$env:SystemRoot\System32\curl.exe" -fsSL -o $file $url
  if ($LASTEXITCODE -ne 0) { throw "다운로드 실패 (curl exit $LASTEXITCODE): $url" }
}

# winget 없이 Go 를 사용자 폴더에 설치한다. go.dev 가 알려주는 SHA256 으로 파일을 검증한다.
function Install-GoZip {
  $rel = (Invoke-RestMethod -UseBasicParsing 'https://go.dev/dl/?mode=json') | Where-Object { $_.stable } | Select-Object -First 1
  $f = $rel.files | Where-Object { $_.os -eq 'windows' -and $_.arch -eq 'amd64' -and $_.kind -eq 'archive' } | Select-Object -First 1
  if (-not $f) { throw 'go.dev 에서 Windows amd64 zip 을 찾지 못했다.' }
  $zip = Join-Path $env:TEMP $f.filename
  Download "https://go.dev/dl/$($f.filename)" $zip
  if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $f.sha256.ToUpper()) { Remove-Item $zip; throw 'Go zip SHA256 불일치. 다운로드가 손상됐다.' }
  $tmp = Join-Path $env:TEMP "go-extract-$PID"
  # Windows 기본 tar.exe(별도 프로세스)로 푼다. 내려받은 PowerShell 프로세스가 직접 exe 를 풀어 쓰면
  # 보안 소프트웨어가 그 프로세스를 강제 종료하는 PC 가 있다 (이 PC 에서 Expand-Archive/ZipFile 모두 재현).
  New-Item -ItemType Directory -Force $tmp | Out-Null
  & "$env:SystemRoot\System32\tar.exe" -xf $zip -C $tmp
  if ($LASTEXITCODE -ne 0) { throw "Go zip 압축 해제 실패 (tar exit $LASTEXITCODE)" }
  if (Test-Path $GoZipDir) { Remove-Item -Recurse -Force $GoZipDir } # 이 스크립트가 만든 이전 버전만 지운다
  New-Item -ItemType Directory -Force (Split-Path $GoZipDir) | Out-Null
  Move-Item (Join-Path $tmp 'go') $GoZipDir
  Remove-Item -Recurse -Force $tmp, $zip
  # 사용자 PATH 에 영구 등록 (새 터미널부터 적용)
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  foreach ($p in "$GoZipDir\bin", "$env:USERPROFILE\go\bin") {
    if (($userPath -split ';') -notcontains $p) { $userPath = ($userPath.TrimEnd(';') + ";$p").TrimStart(';') }
  }
  [Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
  Write-Host "Go $($rel.version) 를 $GoZipDir 에 설치했다."
}

Write-Host '== 빌드 환경 점검 =='
$missing = Check
if ($missing.Count -eq 0) { Write-Host 'READY'; exit 0 }
if (-not $Install) { Write-Host ('MISSING: ' + ($missing -join ' ')); exit 1 }

Write-Host '== 설치 =='
$hasWinget = Has-Cmd 'winget'
if (-not $hasWinget) { Write-Host 'winget 없음: Go 와 WebView2 는 공식 사이트에서 직접 내려받아 설치한다.' }

if ($missing -contains 'go') {
  if ($hasWinget) {
    # 이미 낮은 버전이 있으면 install 대신 upgrade 가 필요하다. MSI 라 관리자 권한(UAC) 창이 뜰 수 있다.
    if (Has-Cmd 'go') { winget upgrade --id GoLang.Go -e --source winget --accept-package-agreements --accept-source-agreements --silent }
    else { Winget-Install 'GoLang.Go' }
    Refresh-Path
  }
  # winget 이 없거나, UAC 거부 등으로 winget 설치가 실패했으면 사용자 폴더에 zip 으로 설치한다.
  $go = Go-Version
  if (-not $go -or $go -lt $MinGo) { Install-GoZip; Refresh-Path }
}
if ($missing -contains 'webview2') {
  if ($hasWinget) { Winget-Install 'Microsoft.EdgeWebView2Runtime' }
  else {
    # Microsoft 공식 Evergreen 부트스트래퍼 (https://developer.microsoft.com/microsoft-edge/webview2/)
    $exe = Join-Path $env:TEMP 'MicrosoftEdgeWebview2Setup.exe'
    Download 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' $exe
    $sig = Get-AuthenticodeSignature $exe
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch '^CN=Microsoft Corporation,') { Remove-Item $exe; throw 'WebView2 설치 파일 서명이 Microsoft 것이 아니다. 실행하지 않는다.' }
    Start-Process $exe -ArgumentList '/silent', '/install' -Wait
    Remove-Item $exe
  }
}
if ($missing -contains 'nsis') {
  if ($hasWinget) { Winget-Install 'NSIS.NSIS' }
  else { Write-Host 'NSIS: https://nsis.sourceforge.io/Download 에서 설치 파일을 받아 직접 설치하라.' }
}
if (($missing -contains 'wails') -or ($missing -contains 'go')) {
  if (Has-Cmd 'go') {
    Write-Host "==> go install github.com/wailsapp/wails/v2/cmd/wails@$WailsVersion"
    go install "github.com/wailsapp/wails/v2/cmd/wails@$WailsVersion"
  }
}

Write-Host '== 다시 점검 =='
$missing = Check
if ($missing.Count -eq 0) { Write-Host 'READY'; exit 0 }
Write-Host ('MISSING: ' + ($missing -join ' '))
Write-Host '설치 후에도 남아 있다면 새 터미널을 열거나 Claude Code 를 재시작한 뒤 다시 점검하라.'
exit 1
