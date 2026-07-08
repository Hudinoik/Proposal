const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('tcoNative', {
  check: () => ipcRenderer.invoke('claude-check'),
  draft: (prompt) => ipcRenderer.invoke('claude-draft', prompt),
  savePdf: (filename) => ipcRenderer.invoke('save-pdf', filename)
});
