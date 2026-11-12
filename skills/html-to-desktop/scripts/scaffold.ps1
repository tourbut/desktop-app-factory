# HTML 폴더를 Wails v2 프로젝트로 감싼다 (Windows).
# 사용: powershell -ExecutionPolicy Bypass -File scaffold.ps1 -Src <html폴더> -Out <프로젝트폴더> -Name <앱이름> [-Slug <exe이름>] [-Title <창제목>] [-Width 1024] [-Height 768]
param(
  [Parameter(Mandatory)][string]$Src,
  [Parameter(Mandatory)][string]$Out,
  [Parameter(Mandatory)][string]$Name,
  [string]$Title = $Name,
  [string]$Slug, # exe·데이터 폴더 이름 (예: memo, 메모장). 없으면 -Name 을 쓴다
  [int]$Width = 1024,
  [int]$Height = 768
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8 # 없으면 Bash 등 다른 셸을 거칠 때 한글 출력이 깨진다
$utf8 = New-Object System.Text.UTF8Encoding($false) # BOM 이 있으면 wails.json 파싱이 실패한다

$Src = (Resolve-Path $Src).Path
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$index = Join-Path $Src 'index.html'
if (-not (Test-Path $index)) { throw "$index 이 없다. 첫 화면 파일을 index.html 로 두어라." }
# charset 선언이 없으면 WebView2 가 UTF-8 한글을 깨뜨려 보여준다.
if ([IO.File]::ReadAllText($index) -notmatch '<meta[^>]+charset') { Write-Warning 'index.html 에 <meta charset="utf-8"> 이 없다. 한글이 깨질 수 있으니 <head> 에 추가하라.' }
if (Test-Path (Join-Path $Out 'wails.json')) { throw "$Out\wails.json 이 이미 있다. 덮어쓰지 않는다." }

# exe 파일 이름·데이터 폴더(%APPDATA%\<slug>) 이름. 한글 허용, Windows 파일 이름에 못 쓰는 문자만 뺀다.
$slug = ($(if ($Slug) { $Slug } else { $Name }) -replace '[\\/:*?"<>|\x00-\x1f]', '').Trim().TrimEnd('.')
if (-not $slug) { $slug = 'app' }
if ($slug -match '^(con|prn|aux|nul|com\d|lpt\d)$') { $slug += '-app' } # Windows 예약 이름

New-Item -ItemType Directory -Force (Join-Path $Out 'web') | Out-Null
if ($Src -ne (Join-Path $Out 'web')) { Copy-Item -Recurse -Force (Join-Path $Src '*') (Join-Path $Out 'web') }

# JSON/Go 문자열 안에 들어가므로 \ 와 " 를 이스케이프한다.
function Esc($s) { $s.Replace('\', '\\').Replace('"', '\"') }
$vars = @{ '{{SLUG}}' = $slug; '{{NAME}}' = (Esc $Name); '{{TITLE}}' = (Esc $Title); '{{WIDTH}}' = "$Width"; '{{HEIGHT}}' = "$Height" }
$tpl = Join-Path $PSScriptRoot '..\template'
foreach ($f in Get-ChildItem $tpl -File) {
  $text = [IO.File]::ReadAllText($f.FullName, $utf8)
  foreach ($k in $vars.Keys) { $text = $text.Replace($k, $vars[$k]) }
  [IO.File]::WriteAllText((Join-Path $Out $f.Name), $text, $utf8)
}
[IO.File]::WriteAllText((Join-Path $Out '.gitignore'), "build/bin/`nweb/wailsjs/`n", $utf8)

Push-Location $Out
try {
  go mod tidy
  if ($LASTEXITCODE -ne 0) { throw 'go mod tidy 실패 (네트워크/프록시 확인)' }
} finally { Pop-Location }
Write-Host "OK: $Out (exe=$slug.exe)"
