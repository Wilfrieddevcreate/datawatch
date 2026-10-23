// Rendu de la vidéo de présentation, image par image, sans dépendance.
//
//   node tool/promo/render.mjs                    → tool/promo/out/DataWatch-presentation.mp4
//   node tool/promo/render.mjs --stills 3,14.8    → tool/promo/out/still-3.png, …
//
// Chrome (sans fenêtre) affiche tool/promo/video/index.html ; la page expose
// render(t), qui place chaque élément à l'instant t. Chaque image est
// capturée puis envoyée à ffmpeg : le résultat ne dépend pas de la vitesse
// de la machine.

import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, readFile, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, extname, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const OUT_DIR = join(ROOT, 'tool/promo/out');
const FPS = 30;
const WIDTH = 1920;
const HEIGHT = 1080;

const args = process.argv.slice(2);
const stillsArg = args.includes('--stills') ? args[args.indexOf('--stills') + 1] : null;
mkdirSync(OUT_DIR, { recursive: true });

// Petit serveur de fichiers : Chrome refuse les polices chargées en file://.
const TYPES = { '.html': 'text/html', '.png': 'image/png', '.ttf': 'font/ttf', '.js': 'text/javascript' };
const server = createServer((req, res) => {
  const path = resolve(ROOT, '.' + decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!path.startsWith(ROOT)) { res.writeHead(403).end(); return; }
  readFile(path, (err, data) => {
    if (err) { res.writeHead(404).end(); return; }
    res.writeHead(200, { 'Content-Type': TYPES[extname(path)] ?? 'application/octet-stream' }).end(data);
  });
}).listen(0, '127.0.0.1');
await new Promise(r => server.once('listening', r));
const pageUrl = `http://127.0.0.1:${server.address().port}/tool/promo/video/index.html`;

// Chrome sans fenêtre, profil jetable.
const profile = mkdtempSync(join(process.env.DW_TMP ?? tmpdir(), 'dw-chrome-'));
const chrome = spawn('google-chrome', [
  '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
  '--hide-scrollbars', '--mute-audio', '--no-first-run', '--no-default-browser-check',
  '--force-color-profile=srgb', '--disable-gpu', '--font-render-hinting=none', 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });
const wsBrowser = await new Promise((res, rej) => {
  let buf = '';
  chrome.stderr.on('data', d => {
    buf += d;
    const m = buf.match(/DevTools listening on (ws:\/\/\S+)/);
    if (m) res(m[1]);
  });
  chrome.once('exit', code => rej(new Error(`Chrome s'est arrêté (${code})`)));
});
const port = new URL(wsBrowser).port;
const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const pageTarget = targets.find(t => t.type === 'page');

// Client minimal du protocole DevTools.
const ws = new WebSocket(pageTarget.webSocketDebuggerUrl);
await new Promise(r => ws.addEventListener('open', r, { once: true }));
let nextId = 1;
const pending = new Map();
const listeners = new Map();
ws.addEventListener('message', ev => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve: ok, reject: ko } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? ko(new Error(msg.error.message)) : ok(msg.result);
  } else if (msg.method && listeners.has(msg.method)) {
    listeners.get(msg.method)(msg.params);
    listeners.delete(msg.method);
  }
});
const send = (method, params = {}) => new Promise((ok, ko) => {
  const id = nextId++;
  pending.set(id, { resolve: ok, reject: ko });
  ws.send(JSON.stringify({ id, method, params }));
});
const once = method => new Promise(r => listeners.set(method, r));

await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: WIDTH, height: HEIGHT, deviceScaleFactor: 1, mobile: false });
const loaded = once('Page.loadEventFired');
await send('Page.navigate', { url: pageUrl });
await loaded;
await send('Runtime.evaluate', { expression: 'window.ready()', awaitPromise: true });
const duration = (await send('Runtime.evaluate', { expression: 'window.DURATION', returnByValue: true })).result.value;

async function frameAt(t) {
  await send('Runtime.evaluate', { expression: `render(${t.toFixed(4)})` });
  const shot = await send('Page.captureScreenshot', {
    format: 'png', fromSurface: true, captureBeyondViewport: false,
    clip: { x: 0, y: 0, width: WIDTH, height: HEIGHT, scale: 1 },
  });
  return Buffer.from(shot.data, 'base64');
}

try {
  if (stillsArg) {
    for (const t of stillsArg.split(',').map(Number)) {
      writeFileSync(join(OUT_DIR, `still-${t}.png`), await frameAt(t));
    }
    console.log(`Images fixes dans ${OUT_DIR}`);
  } else {
    const output = join(OUT_DIR, 'DataWatch-presentation.mp4');
    const ffmpeg = spawn('ffmpeg', [
      '-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'png', '-i', '-',
      '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p',
      '-movflags', '+faststart', output,
    ], { stdio: ['pipe', 'inherit', 'inherit'] });
    const total = Math.round(duration * FPS);
    for (let i = 0; i < total; i++) {
      const png = await frameAt(i / FPS);
      if (!ffmpeg.stdin.write(png)) await new Promise(r => ffmpeg.stdin.once('drain', r));
      if (i % 150 === 0) console.log(`image ${i}/${total}`);
    }
    ffmpeg.stdin.end();
    const code = await new Promise(r => ffmpeg.once('exit', r));
    if (code !== 0) throw new Error(`ffmpeg a échoué (${code})`);
    console.log(`Vidéo : ${output}`);
  }
} finally {
  ws.close();
  const exited = new Promise(r => chrome.once('exit', r));
  chrome.kill();
  await exited;
  server.close();
  rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
}
