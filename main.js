const { app, BrowserWindow, ipcMain, session } = require('electron');
const path = require('path');

let extra = {};

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
  // Bazi yayinlar Referer / User-Agent ister (M3U icindeki EXTVLCOPT satirlari)
  session.defaultSession.webRequest.onBeforeSendHeaders((details, cb) => {
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

  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});

app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
