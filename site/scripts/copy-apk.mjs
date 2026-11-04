// Copies the built Android app (../build/android/xoddam.apk, made by tools/export_android.py) into dist/download/,
// after the site is built. If there is no APK yet it does nothing (deploy.py then leaves the download folder on the
// server alone). Skip with SKIP_APK=1.
//
// No .htaccess goes in this folder on purpose: the server already sends .apk files with the right type
// (application/vnd.android.package-archive), and any .htaccess in a folder with this file made it answer 500 there.
import { copyFileSync, existsSync, mkdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = resolve(root, '..', 'build', 'android', 'xoddam.apk');
const target = join(root, 'dist', 'download');

if (process.env.SKIP_APK) {
  console.log('copy-apk: SKIP_APK is set, not copying the Android app');
  process.exit(0);
}
if (!existsSync(source)) {
  console.log('copy-apk: no Android app built yet (tools/export_android.py), skipping');
  process.exit(0);
}

mkdirSync(target, { recursive: true });
copyFileSync(source, join(target, 'xoddam.apk'));
console.log(`copy-apk: copied xoddam.apk (${(statSync(source).size / 1e6).toFixed(1)} MB) to dist/download`);
