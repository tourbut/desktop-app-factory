# desktop-app-factory

간단한 HTML 페이지를 [Tauri v2](https://v2.tauri.app) 데스크톱 앱으로 만드는 Claude Code 플러그인.
빌드 환경이 없는 PC에서는 Rust, C++ 빌드 도구, WebView2, Node.js를 (동의를 받고) 먼저 설치한다.

## 설치

```
/plugin marketplace add tourbut/desktop-app-factory
/plugin install desktop-app-factory@desktop-app-factory
```

## 사용

```
/desktop-app-factory:html-to-desktop ./my-page
```
또는 그냥 "my-page 폴더 HTML을 데스크톱 앱으로 만들어줘"라고 요청한다.

## 함께 설치되는 것

`desktop-app-factory`를 설치하면 아래 디자인 플러그인이 의존성으로 함께 설치된다. 모두 이 마켓플레이스에 원본 GitHub 저장소를 가리키는 항목으로 등록돼 있다.

| 플러그인 | 원본 | 용도 |
|---|---|---|
| `frontend-design` | [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/frontend-design) | 미적 방향·타이포그래피 |
| `ui-ux-pro-max` | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 스타일·팔레트·폰트 조합 DB |
| `impeccable` | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | critique / audit / polish |

MCP 서버 `tauri`([hypothesi/mcp-server-tauri](https://github.com/hypothesi/mcp-server-tauri), `@hypothesi/tauri-mcp-server@0.13.2`)도 함께 켜진다. `scaffold.mjs --mcp-bridge`로 만든 앱을 `npm run dev`로 띄우면 Claude가 실제 앱 창을 스크린샷으로 보고 디자인을 고칠 수 있다.

## 구성

| 파일 | 역할 |
|---|---|
| `skills/html-to-desktop/SKILL.md` | 작업 순서 (입력 확인 → 환경 점검/설치 → 프로젝트 생성 → 빌드) |
| `scripts/setup-windows.ps1` | Windows 환경 점검, `-Install`로 winget 설치 |
| `scripts/setup-unix.sh` | macOS/Linux 환경 점검, `--install`로 설치 |
| `scripts/scaffold.mjs` | HTML 폴더를 Tauri 프로젝트로 감싸기 (`--mcp-bridge`: 디버그 빌드에 화면 검수용 브리지) |
| `.mcp.json`, `scripts/tauri-mcp.mjs` | Tauri MCP 서버 실행 (Windows `npx.cmd` 대응) |

## 제한

- 빌드는 해당 OS에서만 가능 (Windows 앱은 Windows에서).
- 코드 서명·자동 업데이트는 하지 않는다.
