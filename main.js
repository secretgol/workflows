const { app, BrowserWindow, ipcMain, session } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

let extra = {};
const cacheFile = () => path.join(app.getPath('userData'), 'playlist.m3u');

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 780,
    minWidth: 900,
    minHeight: 560,
    backgroundColor: '#0b0d14',
    title: 'TeleBox',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      webSecurity: false,            // yayin sunuculari CORS vermese de oynatabilmek icin
      autoplayPolicy: 'no-user-gesture-required'
    }
  });
  win.setMenuBarVisibility(false);
  win.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

app.whenReady().then(() => {
  // "Electron/..." ibaresini User-Agent'tan cikar (bazi sunucular reddediyor)
  const ses = session.defaultSession;
  ses.setUserAgent(ses.getUserAgent().replace(/\s?Electron\/\S+/i, '').replace(/\s?telebox\/\S+/i, ''));

  // Bazi yayinlar Referer / User-Agent ister (M3U icindeki EXTVLCOPT satirlari)
  ses.webRequest.onBeforeSendHeaders((details, cb) => {
    const h = details.requestHeaders;
    if (extra.referrer) h['Referer'] = extra.referrer;
    if (extra.ua) h['User-Agent'] = extra.ua;
    cb({ requestHeaders: h });
  });

  ipcMain.on('set-headers', (_e, v) => { extra = v || {}; });

  ipcMain.handle('fetch-text', async (_e, url) => {
    const r = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return await r.text();
  });

  // Liste diske kaydedilir (localStorage sinirina takilmaz)
  ipcMain.handle('cache-read', () => { try { return fs.readFileSync(cacheFile(), 'utf8'); } catch { return ''; } });
  ipcMain.handle('cache-write', (_e, t) => { try { fs.writeFileSync(cacheFile(), String(t)); return true; } catch { return false; } });

  // Yedek: kurulu VLC varsa kanali orada ac
  ipcMain.handle('open-vlc', (_e, url) => {
    if (!/^https?:\/\//i.test(String(url))) return false;
    const dirs = [process.env['ProgramFiles'], process.env['ProgramFiles(x86)'], process.env['LOCALAPPDATA'] && path.join(process.env['LOCALAPPDATA'], 'Programs')].filter(Boolean);
    const exe = dirs.map((d) => path.join(d, 'VideoLAN', 'VLC', 'vlc.exe')).find((p) => fs.existsSync(p));
    if (!exe) return false;
    spawn(exe, [String(url)], { detached: true, stdio: 'ignore' }).unref();
    return true;
  });

  createWindow();
});

app.on('window-all-closed', () => app.quit());
