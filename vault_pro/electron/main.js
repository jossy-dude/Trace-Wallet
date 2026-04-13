const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const { spawn } = require('child_process');

// Python sidecar process
let pythonProcess = null;

// Create the browser window
function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1200,
    minHeight: 700,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    titleBarStyle: 'hiddenInset',
    show: false
  });

  // Load the app
  const isDev = process.env.NODE_ENV === 'development';
  
  if (isDev) {
    mainWindow.loadURL('http://localhost:5173');
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'));
  }

  // Show window when ready
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  return mainWindow;
}

// Start Python sidecar
function startPythonSidecar() {
  const pythonPath = process.platform === 'win32' ? 'python' : 'python3';
  const sidecarPath = path.join(__dirname, '../python/sidecar.py');
  
  pythonProcess = spawn(pythonPath, [sidecarPath], {
    stdio: ['pipe', 'pipe', 'pipe']
  });

  pythonProcess.stdout.on('data', (data) => {
    console.log('Python:', data.toString());
  });

  pythonProcess.stderr.on('data', (data) => {
    console.error('Python Error:', data.toString());
  });

  pythonProcess.on('close', (code) => {
    console.log(`Python sidecar exited with code ${code}`);
  });
}

// IPC handlers for Python communication
ipcMain.handle('python-command', async (event, command, data) => {
  return new Promise((resolve, reject) => {
    if (!pythonProcess) {
      reject(new Error('Python sidecar not running'));
      return;
    }

    const message = JSON.stringify({ command, data }) + '\n';
    let response = '';

    const onData = (data) => {
      response += data.toString();
      const lines = response.split('\n');
      
      for (let i = 0; i < lines.length - 1; i++) {
        try {
          const result = JSON.parse(lines[i]);
          pythonProcess.stdout.off('data', onData);
          resolve(result);
          return;
        } catch (e) {
          // Not valid JSON, continue
        }
      }
      
      response = lines[lines.length - 1];
    };

    pythonProcess.stdout.on('data', onData);
    pythonProcess.stdin.write(message);

    // Timeout after 10 seconds
    setTimeout(() => {
      pythonProcess.stdout.off('data', onData);
      reject(new Error('Command timeout'));
    }, 10000);
  });
});

// App event handlers
app.whenReady().then(() => {
  createWindow();
  startPythonSidecar();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (pythonProcess) {
    pythonProcess.kill();
  }
  
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('quit', () => {
  if (pythonProcess) {
    pythonProcess.kill();
  }
});
