// hypothesi/mcp-server-tauri 실행기. Windows에서 npx 는 npx.cmd 라 셸 없이 spawn 하면 실패하므로 node 로 감싼다.
// 버전은 scaffold.mjs 의 tauri-plugin-mcp-bridge 0.13 과 맞춘다.
import { spawn } from 'node:child_process';

const child = spawn('npx', ['-y', '@hypothesi/tauri-mcp-server@0.13.2'], { stdio: 'inherit', shell: process.platform === 'win32' });
child.on('exit', (code) => process.exit(code ?? 1));
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => child.kill(sig));
