// Rendu des visuels de la fiche Play Store.
//
//   node tool/store/render.mjs          → store/play/feature-graphic.png, store/play/screenshots/…
//
// Chrome (sans fenêtre) affiche tool/store/index.html ; la page expose
// show(id), qui monte un visuel. Chaque capture passe par ffmpeg pour
// retirer la couche alpha : Google Play n'accepte que du PNG 24 bits.

import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { copyFileSync, mkdtempSync, readFile, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, extname, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const OUT_DIR = join(ROOT, 'store/play');
mkdirSync(join(OUT_DIR, 'screenshots'), { recursive: true });

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
const pageUrl = `http://127.0.0.1:${server.address().port}/tool/store/index.html`;

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
const evaluate = async expression => {
  const { result, exceptionDetails } = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
  return result.value;
};

// PNG sans couche alpha.
function savePng(png, output) {
  return new Promise((ok, ko) => {
    const ffmpeg = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-i', '-', '-pix_fmt', 'rgb24', output],
      { stdio: ['pipe', 'inherit', 'inherit'] });
    ffmpeg.once('exit', code => code === 0 ? ok() : ko(new Error(`ffmpeg a échoué (${code})`)));
    ffmpeg.stdin.end(png);
  });
}

try {
  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1080, height: 1920, deviceScaleFactor: 1, mobile: false });
  const loaded = once('Page.loadEventFired');
  await send('Page.navigate', { url: pageUrl });
  await loaded;

  for (const id of await evaluate('window.VISUALS')) {
    const { width, height } = await evaluate(`show(${JSON.stringify(id)})`);
    await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
    const shot = await send('Page.captureScreenshot', {
      format: 'png', fromSurface: true, captureBeyondViewport: false,
      clip: { x: 0, y: 0, width, height, scale: 1 },
    });
    await savePng(Buffer.from(shot.data, 'base64'), join(OUT_DIR, `${id}.png`));
    console.log(`${id}.png  ${width} × ${height}`);
  }
  copyFileSync(join(ROOT, 'branding/play_store_icon_512.png'), join(OUT_DIR, 'icon-512.png'));
  console.log(`Visuels dans ${OUT_DIR}`);
} finally {
  ws.close();
  const exited = new Promise(r => chrome.once('exit', r));
  chrome.kill();
  await exited;
  server.close();
  rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
}
