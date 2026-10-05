import { defineConfig } from '@playwright/test';
import { existsSync } from 'node:fs';
const windowsChrome = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH || (process.platform === 'win32' && existsSync(windowsChrome) ? windowsChrome : undefined);
export default defineConfig({
  testDir: './tests/e2e', fullyParallel: false, workers: 1, timeout: 30000,
  reporter: [['list']], use: { baseURL: 'http://127.0.0.1:3000', headless: true, launchOptions: { executablePath }, screenshot: 'only-on-failure', trace: 'retain-on-failure' },
  webServer: { command: 'npm run start -- --hostname 127.0.0.1 --port 3000', url: 'http://127.0.0.1:3000', reuseExistingServer: true, timeout: 120000 },
});
