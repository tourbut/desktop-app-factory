---
name: html-to-desktop
description: 간단한 HTML/CSS/JS 페이지를 Tauri v2 데스크톱 앱(Windows .exe/.msi, macOS .app/.dmg, Linux .deb/.AppImage)으로 만든다. 빌드 환경(Rust, C++ 빌드 도구, WebView2, Node.js)이 없으면 먼저 설치한다. "HTML을 앱으로", "데스크톱 앱으로 만들어줘", "exe로 만들어줘", "Tauri로 패키징" 같은 요청에 사용한다.
---

# HTML → 데스크톱 앱 (Tauri v2)

이 스킬의 스크립트는 이 SKILL.md와 같은 폴더의 `scripts/` 안에 있다. 아래 `<SKILL_DIR>`는 그 폴더의 절대 경로다.

## 1. 입력 확인

- HTML이 있는 폴더를 찾는다. 첫 화면은 `index.html`이어야 한다. 파일 하나뿐이면 새 폴더에 `index.html`로 복사한다.
- 모든 HTML에 `<meta charset="utf-8">`이 있는지 확인하고 없으면 넣는다. 없으면 Windows 앱 창에서 한글이 깨진다.
- 앱 이름을 정한다. 사용자가 말하지 않았으면 `<title>` 또는 폴더 이름을 쓴다.
- HTML이 외부 CDN을 쓰면 앱도 인터넷이 필요하다고 알린다. 오프라인이 필요하면 파일을 내려받아 상대 경로로 바꾼다.
- 출력 폴더 기본값: HTML 폴더 옆의 `<앱이름>-desktop/`.

## 1-1. 데스크톱 앱답게 디자인 다듬기

사용자가 "그대로 패키징만"을 원하면 건너뛴다. 아니면 HTML을 바꾸기 전에 무엇을 바꿀지 알리고 진행한다. 의존성으로 설치되는 스킬을 쓴다:

- `ui-ux-pro-max`: 앱 성격에 맞는 스타일·팔레트·폰트 조합을 고른다.
- `frontend-design`: 템플릿 티가 나지 않게 미적 방향을 정한다.
- `impeccable`: `/impeccable critique`로 문제를 찾고 `/impeccable polish`로 다듬는다.

웹페이지와 달리 데스크톱 앱 창에서 지킬 것:
- 창 크기(기본 800×600)에 맞춘 레이아웃. 본문 전체 스크롤 대신 고정 헤더/사이드바 + 내용 영역만 스크롤.
- 폰트·아이콘·라이브러리는 `web/` 안에 로컬 파일로 둔다. 오프라인에서도 같은 모습이어야 한다.
- `prefers-color-scheme`로 OS 다크 모드를 따른다.
- 버튼·메뉴 같은 UI 텍스트는 `user-select: none`, 내용 텍스트는 선택 가능하게 둔다.
- 마우스 hover와 키보드 포커스 상태를 모두 만든다. 링크처럼 보이는 밑줄 텍스트 버튼은 피한다.
- `<title>`, 창 제목, 앱 이름을 일치시킨다.

## 2. 빌드 환경 점검

Windows:
```powershell
powershell -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/setup-windows.ps1"
```
macOS / Linux:
```bash
bash "<SKILL_DIR>/scripts/setup-unix.sh"
```

마지막 줄이 `READY`면 3단계로 간다. `MISSING: ...`이면:

1. 빠진 항목과 설치 내용을 사용자에게 알리고 **설치 동의를 받는다.** 시스템에 프로그램을 설치하는 작업이다.
   - `msvc`: Visual Studio Build Tools의 "C++를 사용한 데스크톱 개발" (수 GB, 관리자 권한 창이 뜬다)
   - `webview2`: Microsoft Edge WebView2 런타임 (Windows 11은 보통 이미 있음)
   - `rust`: rustup + stable 툴체인
   - `node`: Node.js LTS
   - `xcode-clt`: Xcode Command Line Tools (macOS, 설치 창에서 직접 눌러야 함)
   - `system-libs`: webkit2gtk-4.1 등 (Linux, sudo 비밀번호 필요)
2. 동의하면 같은 스크립트를 `-Install`(Windows) 또는 `--install`(macOS/Linux)로 실행한다. 설치는 오래 걸리므로 timeout을 최대(600000ms)로 주거나 백그라운드로 실행한다.
3. sudo 비밀번호나 설치 창 클릭이 필요하면 사용자에게 `! <명령>`으로 직접 실행하도록 안내한다.
4. 다시 점검한다. 설치 직후 PATH가 안 잡혀 `rust`/`node`가 계속 빠지면 새 터미널(또는 Claude Code 재시작)을 요청한다.

## 3. Tauri 프로젝트 생성

```bash
node "<SKILL_DIR>/scripts/scaffold.mjs" --src "<HTML폴더>" --out "<출력폴더>" --name "<앱이름>" [--title "<창제목>"] [--id com.회사.앱] [--mcp-bridge]
```

`--mcp-bridge`: 실제 앱 창 화면을 검수하려면 붙인다(1-1단계를 했으면 기본으로 붙인다). 디버그 빌드에만 `tauri-plugin-mcp-bridge`를 등록하고 `127.0.0.1`에만 연다. 배포 빌드(`npm run build`)의 동작에는 들어가지 않는다.

결과 구조:
```
<출력폴더>/
  web/                 ← HTML 복사본. 이후 수정은 여기서 한다
  src-tauri/           ← Rust 셸, tauri.conf.json, icons/
  package.json
```

선택 조정 (`src-tauri/tauri.conf.json`):
- 창 크기: `app.windows[0].width` / `height`
- 아이콘: 사용자가 PNG(정사각형, 1024px 권장)를 주면 출력 폴더에서 `npx tauri icon <png경로>`
- 번들 종류 제한(빌드 시간 단축): `bundle.targets`를 `["nsis"]`(Windows), `["dmg"]`(macOS), `["deb","appimage"]`(Linux) 등으로

## 4. 실행 확인 → 빌드

출력 폴더에서:
```bash
npm run dev     # 창이 뜨는지 확인. 첫 실행은 Rust 컴파일로 수 분 걸린다. 확인 후 종료
npm run build   # 배포용 빌드
```
Windows에서는 반드시 PowerShell(또는 cmd)로 실행한다. Git Bash는 `/usr/bin/link`가 MSVC `link.exe`를 가려 `link: extra operand` 오류가 난다.
`npm run dev`는 창을 닫을 때까지 끝나지 않으므로 백그라운드로 실행하고, 확인 후 종료한다.

`--mcp-bridge`로 만들었으면 이 플러그인의 `tauri` MCP 서버로 직접 확인한다:
1. `driver_session`으로 세션을 시작한다(포트 9223).
2. `webview_screenshot`으로 실제 창을 찍어 본다. `read_logs`로 콘솔 오류를 확인한다.
3. 디자인 문제가 보이면 `web/`을 고친다. `/impeccable audit`도 돌린다. dev 서버는 파일 변경 시 다시 불러온다.
4. 끝나면 세션을 멈춘다.

브리지가 없으면 사용자에게 창 확인을 요청한다.

빌드 결과 위치: `src-tauri/target/release/bundle/`
- Windows: `nsis/*-setup.exe`, `msi/*.msi` / 설치 없이 쓰는 exe: `src-tauri/target/release/<이름>.exe`
- macOS: `macos/*.app`, `dmg/*.dmg`
- Linux: `deb/*.deb`, `appimage/*.AppImage`

결과 파일 경로를 사용자에게 알려준다. 다른 OS용 파일은 그 OS에서 빌드해야 한다고 알린다(크로스 빌드 미지원).

## 문제 해결

- `link.exe not found` / `MSVC` 오류 / `LNK1181 kernel32.lib`: C++ 빌드 도구 또는 Windows SDK 미설치. 2단계로 돌아간다.
- `link: extra operand`: Git Bash에서 빌드했다. PowerShell에서 다시 실행한다.
- `identifier ... com.tauri.dev`: `tauri.conf.json`의 `identifier`를 고유값으로 바꾼다.
- MSI(WiX) `LGHT0311 ... code page '1252'`: 비ASCII 앱 이름. scaffold는 한글 이름이면 `bundle.windows.wix.language`를 `"ko-KR"`로 넣는다. 다른 언어면 해당 로케일(예: `"ja-JP"`)로 바꾸거나 `bundle.targets`를 `["nsis"]`로 줄인다.
- WiX/NSIS 다운로드 실패: 네트워크·프록시 문제. 재시도하거나 `bundle.targets`를 줄인다.
- `fetch`/로컬 파일 접근이 안 됨: 앱은 `tauri://` 출처에서 열린다. 상대 경로 리소스는 `web/` 안에 있어야 한다.
- macOS에서 "확인되지 않은 개발자": 서명 안 된 앱이라 정상. 우클릭 → 열기로 실행한다.
