const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('api', {
  fetchText: (url) => ipcRenderer.invoke('fetch-text', url),
  setHeaders: (h) => ipcRenderer.send('set-headers', h)
});
