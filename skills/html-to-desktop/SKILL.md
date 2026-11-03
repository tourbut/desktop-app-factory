---
name: html-to-desktop
description: 간단한 HTML/CSS/JS 페이지를 Wails v2 Windows 데스크톱 앱(.exe, 선택적으로 NSIS 설치 파일)으로 만든다. 빌드 환경(Go, Wails CLI, WebView2)이 없으면 먼저 설치한다. "HTML을 앱으로", "데스크톱 앱으로 만들어줘", "exe로 만들어줘", "Wails로 패키징" 같은 요청에 사용한다. Windows에서 Windows용으로만 빌드한다.
---

# HTML → Windows 데스크톱 앱 (Wails v2)

이 스킬의 스크립트는 이 SKILL.md와 같은 폴더의 `scripts/` 안에, 프로젝트 틀은 `template/` 안에 있다. 아래 `<SKILL_DIR>`는 그 폴더의 절대 경로다.

Windows 전용이다. macOS/Linux 사용자에게는 지원하지 않는다고 알린다.
모든 명령은 PowerShell(또는 Bash 도구에서 `powershell -File ...`)로 실행한다.

## 1. 빌드 환경 점검 (가장 먼저)

HTML을 보기 전에 이 PC에 빌드 환경이 있는지부터 확인한다. Go가 없는 PC도 많다.

```powershell
powershell -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/setup-windows.ps1"
```

항목별로 `[OK]` / `[없음]` / `[부족]` / `[선택]` 줄이 나오고, 마지막 줄이 `READY` 또는 `MISSING: ...`이다.

`READY`면 2단계로 간다. `MISSING: ...`이면:

1. 출력된 항목별 줄을 그대로 보여주며 **무엇이 없고 무엇을 설치할지 안내하고 설치 동의를 받는다.** 시스템에 프로그램을 설치하는 작업이다.
   - `go`: Go 1.26 이상 (약 300MB). Wails v2.17.1이 Go 1.26을 요구한다.
     - winget이 있으면 `GoLang.Go`(MSI)로 설치한다. 관리자 권한(UAC) 창이 뜨면 사용자가 "예"를 눌러야 한다고 미리 알린다.
     - winget이 없거나 winget 설치가 실패하면(UAC 거부 등) go.dev의 공식 zip을 SHA256으로 검증해 `%LOCALAPPDATA%\Programs\Go`에 설치하고 사용자 PATH에 등록한다. 관리자 권한이 필요 없다.
   - `wails`: Wails CLI v2.17.1. `go install`로 `%USERPROFILE%\go\bin`에 설치한다. 관리자 권한 불필요, 약 1~2분.
   - `webview2`: Microsoft Edge WebView2 런타임 (Windows 11은 보통 이미 있음). winget이 없으면 Microsoft 공식 설치 파일을 내려받아 서명을 확인한 뒤 실행한다.
   - `nsis`: `-Nsis`로 점검했을 때만 나온다. 설치 파일(setup.exe)을 만들 때만 필요. winget이 없으면 직접 설치하도록 안내한다.
2. 동의하면 같은 스크립트를 `-Install`로 실행한다(설치 파일도 만들려면 `-Install -Nsis`). 다운로드가 있어 오래 걸리므로 timeout을 최대(600000ms)로 준다.
3. 스크립트가 설치 후 스스로 다시 점검한다. 마지막 줄이 `READY`면 2단계로 간다.
4. 여전히 `MISSING`이면:
   - `go`/`wails`만 남았고 방금 설치했다면 PATH 반영 문제다. 새 터미널(또는 Claude Code 재시작)을 요청한 뒤 1단계부터 다시 한다.
   - 다운로드 실패(`curl exit ...`)면 인터넷·사내 프록시를 확인하도록 안내한다.
   - 사용자가 직접 설치하길 원하면 https://go.dev/dl/ (Go), https://developer.microsoft.com/microsoft-edge/webview2/ (WebView2) 링크를 주고, 설치 후 다시 점검한다.

Rust, Visual Studio C++ 빌드 도구, Node.js는 필요 없다. `wails doctor`가 Node/npm을 보여줘도 이 스킬에서는 쓰지 않는다.

## 2. 입력 확인

- HTML이 있는 폴더를 찾는다. 첫 화면은 `index.html`이어야 한다. 파일 하나뿐이면 새 폴더에 `index.html`로 복사한다.
- 모든 HTML에 `<meta charset="utf-8">`이 있는지 확인하고 없으면 넣는다. 없으면 앱 창에서 한글이 깨진다.
- 앱 이름을 정한다. 사용자가 말하지 않았으면 `<title>` 또는 폴더 이름을 쓴다. 한글 이름 그대로 exe 이름(`한글 메모장.exe`)이 된다. exe 이름을 따로 원하면 `-Slug`로 준다.
- HTML이 외부 CDN을 쓰면 앱도 인터넷이 필요하다고 알린다. 오프라인이 필요하면 파일을 내려받아 상대 경로로 바꾼다.
- 출력 폴더 기본값: HTML 폴더 옆의 `<앱이름>-desktop/`.

## 2-1. 데스크톱 앱답게 디자인 다듬기

사용자가 "그대로 패키징만"을 원하면 건너뛴다. 아니면 HTML을 바꾸기 전에 무엇을 바꿀지 알리고 진행한다. 의존성으로 설치되는 스킬을 쓴다:

- `ui-ux-pro-max`: 앱 성격에 맞는 스타일·팔레트·폰트 조합을 고른다.
- `frontend-design`: 템플릿 티가 나지 않게 미적 방향을 정한다.
- `impeccable`: `/impeccable critique`로 문제를 찾고 `/impeccable polish`로 다듬는다.

웹페이지와 달리 데스크톱 앱 창에서 지킬 것:
- 창 크기(기본 1024×768)에 맞춘 레이아웃. 본문 전체 스크롤 대신 고정 헤더/사이드바 + 내용 영역만 스크롤.
- 폰트·아이콘·라이브러리는 `web/` 안에 로컬 파일로 둔다. 오프라인에서도 같은 모습이어야 한다.
- `prefers-color-scheme`로 OS 다크 모드를 따른다.
- 버튼·메뉴 같은 UI 텍스트는 `user-select: none`, 내용 텍스트는 선택 가능하게 둔다.
- 마우스 hover와 키보드 포커스 상태를 모두 만든다. 링크처럼 보이는 밑줄 텍스트 버튼은 피한다.
- `<title>`, 창 제목, 앱 이름을 일치시킨다.

## 3. Wails 프로젝트 생성

```powershell
powershell -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/scaffold.ps1" -Src "<HTML폴더>" -Out "<출력폴더>" -Name "<앱이름>" [-Slug <exe이름>] [-Title "<창제목>"] [-Width 1024] [-Height 768]
```

`-Slug`는 exe 파일 이름과 데이터 폴더(`%APPDATA%\<slug>`) 이름이다. 생략하면 `-Name`을 그대로 쓴다. 한글·공백 허용, Windows 파일 이름에 못 쓰는 문자(`\ / : * ? " < > |`)만 뺀다. 예: `-Name "한글 메모장"` → `build/bin/한글 메모장.exe`.

결과 구조:
```
<출력폴더>/
  web/          ← HTML 복사본. exe 안에 그대로 들어간다(Go embed). 이후 수정은 여기서 한다
  main.go       ← 창 제목·크기 등 옵션 (wails.Run)
  app.go        ← HTML에서 부를 수 있는 Go 메서드 (App 구조체)
  app_test.go   ← app.go 테스트 (go test ./...)
  wails.json    ← frontend:install/build 가 비어 있어 npm 단계를 건너뛴다
  go.mod, go.sum
```

### HTML에서 Go 부르기

`App`의 공개 메서드는 `window.go.main.App.<메서드>()`로 부르고 Promise를 돌려받는다. Wails 런타임 스크립트는 빌드된 앱이 `index.html`에 자동으로 넣는다. 예제로 들어 있는 메서드:

```js
await window.go.main.App.SaveText('메모.txt', '내용');   // %APPDATA%\<slug>\메모.txt 에 저장
const text = await window.go.main.App.LoadText('메모.txt'); // 없으면 ''
const dir = await window.go.main.App.DataDir();
```

파일 이름만 받고 경로(`..`, `\`, `/`)는 거부한다. HTML 쪽 스크립트가 데이터 폴더 밖을 건드리지 못하게 하려는 것이다.

메서드를 추가하려면 `app.go`에 아래 형태로 쓰고 다시 빌드한다. `error`를 돌려주면 JS 쪽 Promise가 reject된다. 인자·반환값은 JSON으로 바뀌는 타입(문자열, 숫자, bool, 구조체, 슬라이스, 맵)만 쓴다.
```go
func (a *App) Add(x, y int) (int, error) { return x + y, nil }
```
빌드하면 `web/wailsjs/go/main/App.js`에 import용 래퍼도 생긴다(`import { Add } from './wailsjs/go/main/App.js'`). 전역 `window.go...`만 써도 된다.
파일 선택 창·메시지 박스 등은 Wails 런타임(`github.com/wailsapp/wails/v2/pkg/runtime`)의 `runtime.OpenFileDialog(a.ctx, ...)` 등을 메서드 안에서 쓴다.

선택 조정:
- 창 크기·최소 크기: `main.go`의 `Width`/`Height`/`MinWidth`/`MinHeight`
- 아이콘: 사용자가 PNG(정사각형, 1024px 권장)를 주면 `build/appicon.png`에 덮어쓰고 `build/windows/icon.ico`를 지운 뒤 다시 빌드한다. 첫 빌드 전이면 `build/` 폴더를 만들고 `appicon.png`만 넣는다.
- 버전·제품 이름: `wails.json`의 `info.productVersion` / `info.productName`

## 4. 빌드 → 화면 확인

출력 폴더에서:
```powershell
go test ./...     # app.go 를 고쳤으면
wails build       # build/bin/<slug>.exe (설치 없이 실행되는 단일 exe)
```

화면 확인(추가 설치 없음. Windows 기본 .NET으로 앱 창을 PNG로 찍는다):
```powershell
powershell -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/screenshot.ps1" -Exe "<출력폴더>/build/bin/<slug>.exe" -Png "<저장경로>.png"
```
1. 찍은 PNG를 Read 도구로 본다. 한글이 깨지지 않았는지, 레이아웃이 창 크기에 맞는지 확인한다.
2. 디자인 문제가 보이면 `web/`을 고치고 다시 빌드해 찍는다. `/impeccable audit`도 돌린다.
3. JS 오류가 의심되면 `wails build -devtools`로 빌드한다. 앱 창에서 Ctrl+Shift+F12를 누르면 개발자 도구(콘솔·요소 검사)가 열린다. 이 키는 사용자가 직접 눌러야 하므로 필요하면 요청한다. 배포용은 `-devtools` 없이 다시 빌드한다.

개발 중 빠르게 보려면 `wails dev`(파일 변경 시 다시 불러옴)를 백그라운드로 실행할 수 있다. 창을 닫을 때까지 끝나지 않으므로 확인 후 종료한다.

### (선택) 설치 파일

사용자가 설치 파일을 원하면 1단계를 `-Nsis`로 점검·설치한 뒤:
```powershell
wails build -nsis   # build/bin/<slug>-amd64-installer.exe
```
설치 파일은 시작 메뉴·바탕화면 바로가기를 만들고, WebView2가 없는 PC에서는 설치 중에 내려받는다.

결과 파일 경로를 사용자에게 알려준다. 단일 exe는 WebView2가 있는 Windows 10/11에서 그대로 실행된다.

### 배포 시 알려줄 것 (기본 방침)

- **사용자 데이터는 제거 후에도 남긴다.** 설치 파일로 앱을 제거해도 `%APPDATA%\<slug>`(SaveText로 저장한 파일)는 지우지 않는다. 재설치·업데이트 때 데이터를 잃지 않게 하려는 Windows 앱의 일반적인 동작이다. 완전히 지우려면 그 폴더를 직접 삭제하라고 알린다.
- **UPX 압축(`-upx`)은 쓰지 않는다.** exe가 몇 MB 줄지만 백신 오탐이 늘어난다.
- **코드 서명은 하지 않는다.** 처음 실행할 때 SmartScreen이 "Windows의 PC 보호" 창을 띄울 수 있다. "추가 정보" → "실행"으로 연다고 알린다. 회사 배포라면 코드 서명 인증서를 따로 마련해야 한다.

## 문제 해결

- `wails: command not found` / `'wails'은(는) ... 아닙니다`: `%USERPROFILE%\go\bin`이 PATH에 없다. 새 터미널을 열거나 전체 경로로 실행한다.
- `go: go.mod requires go >= 1.26.0`: Go가 낮다. 1단계를 `-Install`로 다시 실행한다.
- 설치 후에도 `go version`이 옛 버전: PATH에서 옛 Go가 앞에 있다. 새 터미널을 열고, 그래도 같으면 옛 Go를 제거하도록 안내한다.
- `curl exit ...` / `go mod tidy` 실패 / 빌드 중 모듈 다운로드 실패: 인터넷·사내 프록시 문제. `go env -w GOPROXY=...`로 사내 프록시를 지정하거나 재시도한다.
- 한글이 `ì•ˆë…•`처럼 깨짐: HTML에 `<meta charset="utf-8">`이 없거나 파일이 UTF-8이 아니다.
- `window.go is undefined`: 브라우저로 `web/index.html`을 직접 열었다. Go 호출은 빌드된 앱(또는 `wails dev`) 안에서만 된다.
- `Error: ... wails.json` 파싱 오류: BOM 있는 UTF-8로 저장됐다. BOM 없는 UTF-8로 다시 저장한다.
- 앱이 바로 꺼짐 / 빈 창: WebView2 런타임 미설치. 1단계로 돌아간다.
- `makensis` 없음(`-nsis`): NSIS 미설치. `setup-windows.ps1 -Install -Nsis`.
- 백신이 새 exe를 막음 / SmartScreen 경고: 서명 안 된 exe라 생길 수 있다. "배포 시 알려줄 것"을 본다.
