// HTML 폴더를 Tauri v2 프로젝트로 감싼다.
// 사용: node scaffold.mjs --src <html폴더> --out <프로젝트폴더> --name <앱이름> [--title <창제목>] [--id <com.example.app>]
import { cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execSync } from 'node:child_process';
import { parseArgs } from 'node:util';

const { values: a } = parseArgs({
  options: {
    src: { type: 'string' }, out: { type: 'string' }, name: { type: 'string' }, title: { type: 'string' }, id: { type: 'string' },
    'mcp-bridge': { type: 'boolean' }, // 디버그 빌드에 tauri-plugin-mcp-bridge 를 넣어 Tauri MCP 로 화면 검수
  },
});
if (!a.src || !a.out || !a.name) throw new Error('--src, --out, --name 은 필수');

const src = resolve(a.src), out = resolve(a.out);
if (!existsSync(join(src, 'index.html'))) throw new Error(`${src}/index.html 이 없다. 첫 화면 파일을 index.html 로 두어라.`);
// charset 선언이 없으면 WebView2 가 UTF-8 한글을 깨뜨려 보여준다.
if (!/<meta[^>]+charset/i.test(readFileSync(join(src, 'index.html'), 'utf8'))) console.warn('WARN: index.html 에 <meta charset="utf-8"> 이 없다. 한글이 깨질 수 있으니 <head> 에 추가하라.');
if (existsSync(join(out, 'src-tauri'))) throw new Error(`${out}/src-tauri 가 이미 있다. 덮어쓰지 않는다.`);

// 한글 등 비ASCII 이름은 slug가 비므로 앱마다 identifier가 겹치지 않게 시각 기반 접미사를 붙인다.
const slug = a.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || `app-${Date.now().toString(36)}`;
const id = a.id ?? `com.desktopappfactory.${slug.replace(/-/g, '')}`;
if (!/^[a-zA-Z][\w-]*(\.[a-zA-Z][\w-]*)+$/.test(id)) throw new Error(`잘못된 identifier: ${id}`);

mkdirSync(out, { recursive: true });
if (src !== join(out, 'web')) cpSync(src, join(out, 'web'), { recursive: true });

writeFileSync(join(out, 'package.json'), JSON.stringify({
  name: slug, private: true, version: '0.1.0',
  scripts: { dev: 'tauri dev', build: 'tauri build' },
}, null, 2));
writeFileSync(join(out, '.gitignore'), 'node_modules/\nsrc-tauri/target/\n');

const run = (cmd) => execSync(cmd, { cwd: out, stdio: 'inherit' });
run('npm install -D @tauri-apps/cli@^2');
run(`npx tauri init --ci -A ${JSON.stringify(slug)} -W ${JSON.stringify(a.title ?? a.name)} -D ../web`);

// --ci 는 beforeDev/BuildCommand 에 "npm run dev/build" 를 넣는다. 정적 HTML이라 비우고, 기본 identifier(com.tauri.dev)는 빌드가 거부하므로 바꾼다.
const confPath = join(out, 'src-tauri', 'tauri.conf.json');
const conf = JSON.parse(readFileSync(confPath, 'utf8'));
conf.productName = a.name;
conf.identifier = id;
conf.build = { frontendDist: '../web' };
// WiX 기본 코드페이지(1252)는 한글 productName 에서 LGHT0311 로 실패한다. ko-KR 로케일(949)로 바꾼다.
if (/[^\x00-\x7f]/.test(a.name)) conf.bundle.windows = { ...conf.bundle.windows, wix: { language: 'ko-KR' } };
if (a['mcp-bridge']) {
  conf.app.withGlobalTauri = true; // 없으면 MCP 서버가 webview 에 닿지 못한다
  run('cargo add tauri-plugin-mcp-bridge@0.13 --manifest-path src-tauri/Cargo.toml');

  const libPath = join(out, 'src-tauri', 'src', 'lib.rs');
  const lib = readFileSync(libPath, 'utf8');
  const anchor = 'if cfg!(debug_assertions) {';
  if (!lib.includes(anchor)) throw new Error(`lib.rs 에 '${anchor}' 가 없다. 브리지를 수동 등록하라.`);
  // 기본 바인딩은 0.0.0.0(모든 인터페이스)이라 같은 네트워크에서 접근 가능하다. 로컬로 제한한다.
  writeFileSync(libPath, lib.replace(anchor, `${anchor}\n        app.handle().plugin(tauri_plugin_mcp_bridge::Builder::new().bind_address("127.0.0.1").build())?;`));

  const capPath = join(out, 'src-tauri', 'capabilities', 'default.json');
  const cap = JSON.parse(readFileSync(capPath, 'utf8'));
  cap.permissions.push('mcp-bridge:default');
  writeFileSync(capPath, JSON.stringify(cap, null, 2));
}
writeFileSync(confPath, JSON.stringify(conf, null, 2));
console.log(`OK: ${out} (identifier=${id})`);
