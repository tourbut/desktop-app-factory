# HTML 폴더를 Wails v2 프로젝트로 감싼다 (Windows).
# 사용: powershell -ExecutionPolicy Bypass -File scaffold.ps1 -Src <html폴더> -Out <프로젝트폴더> -Name <앱이름> [-Slug <영문이름>] [-Title <창제목>] [-Width 1024] [-Height 768]
param(
  [Parameter(Mandatory)][string]$Src,
  [Parameter(Mandatory)][string]$Out,
  [Parameter(Mandatory)][string]$Name,
  [string]$Title = $Name,
  [string]$Slug, # 영문 exe/폴더 이름 (예: memo). 없으면 -Name 에서 만든다

  [int]$Width = 1024,
  [int]$Height = 768
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false) # BOM 이 있으면 wails.json 파싱이 실패한다

$Src = (Resolve-Path $Src).Path
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$index = Join-Path $Src 'index.html'
if (-not (Test-Path $index)) { throw "$index 이 없다. 첫 화면 파일을 index.html 로 두어라." }
# charset 선언이 없으면 WebView2 가 UTF-8 한글을 깨뜨려 보여준다.
if ([IO.File]::ReadAllText($index) -notmatch '<meta[^>]+charset') { Write-Warning 'index.html 에 <meta charset="utf-8"> 이 없다. 한글이 깨질 수 있으니 <head> 에 추가하라.' }
if (Test-Path (Join-Path $Out 'wails.json')) { throw "$Out\wails.json 이 이미 있다. 덮어쓰지 않는다." }

# exe 파일 이름·Go 모듈 이름·데이터 폴더 이름. 한글 등 비ASCII 이름은 비므로 시각 기반 이름을 쓴다.
$slug = ($(if ($Slug) { $Slug } else { $Name }).ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $slug) { $slug = 'app-' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

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
