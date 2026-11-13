const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('api', {
  fetchText: (url) => ipcRenderer.invoke('fetch-text', url),
  setHeaders: (h) => ipcRenderer.send('set-headers', h),
  cacheRead: () => ipcRenderer.invoke('cache-read'),
  cacheWrite: (t) => ipcRenderer.invoke('cache-write', t),
  openVlc: (url) => ipcRenderer.invoke('open-vlc', url)
});
