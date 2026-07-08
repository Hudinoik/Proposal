const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const { spawn, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

/* GUI apps don't inherit the shell PATH (especially on macOS),
   so look for Claude Code in the usual install locations too. */
function claudePath() {
  const candidates = [];
  if (process.platform === 'win32') {
    candidates.push(path.join(os.homedir(), '.local', 'bin', 'claude.exe'));
    candidates.push('claude.exe', 'claude');
  } else {
    candidates.push(path.join(os.homedir(), '.local', 'bin', 'claude'));
    candidates.push('/opt/homebrew/bin/claude', '/usr/local/bin/claude', 'claude');
  }
  for (const c of candidates) {
    try {
      const r = spawnSync(c, ['--version'], { timeout: 15000, windowsHide: true });
      if (r.status === 0) return c;
    } catch (e) { /* keep looking */ }
  }
  return null;
}

ipcMain.handle('claude-check', () => !!claudePath());

ipcMain.handle('claude-draft', (event, prompt) => new Promise((resolve) => {
  const exe = claudePath();
  if (!exe) {
    resolve({ ok: false, error: "Claude Code is not installed. Install it from claude.ai/download and sign in once with your Claude account — drafting then runs on your subscription." });
    return;
  }
  let out = '', err = '', settled = false;
  const finish = (v) => { if (!settled) { settled = true; resolve(v); } };
  const child = spawn(exe, ['-p', '--output-format', 'text'], { windowsHide: true });
  const timer = setTimeout(() => { try { child.kill(); } catch (e) {} finish({ ok: false, error: 'Claude took too long to answer. Try again.' }); }, 300000);
  child.stdout.on('data', (d) => { out += d; });
  child.stderr.on('data', (d) => { err += d; });
  child.on('close', (code) => {
    clearTimeout(timer);
    if (code === 0) finish({ ok: true, text: out });
    else finish({ ok: false, error: (err || 'Claude Code returned an error.').toString().slice(0, 400) });
  });
  child.on('error', (e) => { clearTimeout(timer); finish({ ok: false, error: String(e.message || e) }); });
  child.stdin.write(prompt);
  child.stdin.end();
}));

ipcMain.handle('save-pdf', async (event, filename) => {
  try {
    const win = BrowserWindow.fromWebContents(event.sender);
    const safe = String(filename || 'Agreement.pdf').replace(/[\\/:*?"<>|]/g, '');
    const { canceled, filePath } = await dialog.showSaveDialog(win, {
      title: 'Save agreement as PDF',
      defaultPath: path.join(app.getPath('documents'), safe),
      filters: [{ name: 'PDF document', extensions: ['pdf'] }]
    });
    if (canceled || !filePath) return { ok: false, canceled: true };
    const data = await event.sender.printToPDF({ printBackground: true, preferCSSPageSize: true });
    fs.writeFileSync(filePath, data);
    return { ok: true, path: filePath };
  } catch (e) {
    return { ok: false, error: String(e.message || e) };
  }
});

function createWindow() {
  const win = new BrowserWindow({
    width: 1500,
    height: 980,
    minWidth: 900,
    minHeight: 620,
    title: 'TCO Agreement Generator',
    icon: path.join(__dirname, process.platform === 'win32' ? 'tco.ico' : 'tco.png'),
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });
  win.setMenuBarVisibility(false);
  win.loadFile(path.join(__dirname, 'index.html'));
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});
app.on('window-all-closed', () => app.quit());
