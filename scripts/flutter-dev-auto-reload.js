const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const rootDir = path.resolve(__dirname, '..');
const flutterDir = path.join(rootDir, 'apps', 'flutter_app');
const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:3000';
const flutterDevice = process.env.FLUTTER_DEVICE || 'edge';
const flutterBin = 'flutter';
const debounceMs = 250;

const watchEntries = [
  { target: path.join(flutterDir, 'lib'), restart: false },
  { target: path.join(flutterDir, 'web'), restart: false },
  { target: path.join(flutterDir, 'pubspec.yaml'), restart: true },
];

let stopped = false;
let pendingAction = null;
let reloadTimer = null;

function log(message) {
  // Keep logs terse so they remain readable when running with concurrently.
  process.stdout.write(`[flutter-auto] ${message}\n`);
}

function logError(message) {
  process.stderr.write(`[flutter-auto] ${message}\n`);
}

function outputWithPrefix(stream, chunk) {
  const text = chunk.toString();
  const lines = text.split(/\r?\n/);
  for (const line of lines) {
    if (!line) {
      continue;
    }
    stream.write(`[flutter] ${line}\n`);
  }
}

function queueHotAction(action, source) {
  if (stopped) {
    return;
  }

  if (action === 'R') {
    pendingAction = 'R';
  } else if (!pendingAction) {
    pendingAction = 'r';
  }

  if (reloadTimer) {
    clearTimeout(reloadTimer);
  }

  reloadTimer = setTimeout(() => {
    if (!flutterProcess.stdin.writable || !pendingAction) {
      pendingAction = null;
      return;
    }

    const actionToSend = pendingAction;
    pendingAction = null;
    flutterProcess.stdin.write(actionToSend);
    log(
      actionToSend === 'R'
        ? `Sent hot restart (R), reason: ${source}`
        : `Sent hot reload (r), reason: ${source}`,
    );
  }, debounceMs);
}

function createWatchers() {
  const watchers = [];

  for (const entry of watchEntries) {
    if (!fs.existsSync(entry.target)) {
      continue;
    }

    const isDirectory = fs.statSync(entry.target).isDirectory();
    const watchOptions = isDirectory ? { recursive: true } : undefined;

    const watcher = fs.watch(entry.target, watchOptions, (_eventType, filename) => {
      if (stopped) {
        return;
      }
      if (!filename) {
        return;
      }

      if (filename.includes('.dart_tool') || filename.includes('build')) {
        return;
      }

      const reason = `${path.relative(flutterDir, entry.target)} -> ${filename}`;
      queueHotAction(entry.restart ? 'R' : 'r', reason);
    });

    watchers.push(watcher);
    log(`Watching ${path.relative(rootDir, entry.target)}`);
  }

  return watchers;
}

function closeWatchers(watchers) {
  for (const watcher of watchers) {
    try {
      watcher.close();
    } catch (_error) {
      // Ignore watcher close errors during shutdown.
    }
  }
}

const flutterProcess = spawn(
  flutterBin,
  ['run', '-d', flutterDevice, `--dart-define=API_BASE_URL=${apiBaseUrl}`],
  {
    cwd: flutterDir,
    stdio: ['pipe', 'pipe', 'pipe'],
    shell: process.platform === 'win32',
  },
);

flutterProcess.stdout.on('data', (chunk) => {
  outputWithPrefix(process.stdout, chunk);
});

flutterProcess.stderr.on('data', (chunk) => {
  outputWithPrefix(process.stderr, chunk);
});

const watchers = createWatchers();

function shutdown(signal) {
  if (stopped) {
    return;
  }
  stopped = true;

  if (reloadTimer) {
    clearTimeout(reloadTimer);
  }
  closeWatchers(watchers);

  log(`Received ${signal}, stopping flutter process...`);
  flutterProcess.kill('SIGINT');
}

process.on('SIGINT', () => {
  shutdown('SIGINT');
});

process.on('SIGTERM', () => {
  shutdown('SIGTERM');
});

flutterProcess.on('close', (code) => {
  closeWatchers(watchers);
  if (stopped) {
    process.exit(code ?? 0);
    return;
  }

  const exitCode = code ?? 1;
  logError(`flutter process exited unexpectedly with code ${exitCode}`);
  process.exit(exitCode);
});
