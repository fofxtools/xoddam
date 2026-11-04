// Copies the exported web game (../build/web) into dist/play, after the site is built, and writes the server
// rules for it (compression, and "check for a new version every time" so a phone never keeps an old game).
// Skip with SKIP_GAME=1 when only the site changed. Export the game first (see ../docs/web-build.md).
import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = resolve(root, '..', 'build', 'web');
const target = join(root, 'dist', 'play');

if (process.env.SKIP_GAME) {
  console.log('copy-game: SKIP_GAME is set, not copying the game');
  process.exit(0);
}
if (!existsSync(join(source, 'index.html'))) {
  console.error(`copy-game: no web build at ${source}. Export it first (docs/web-build.md), or set SKIP_GAME=1.`);
  process.exit(1);
}

mkdirSync(target, { recursive: true });
// Leave out leftovers of the export (temporary files, and .import files Godot writes next to the exported icons).
cpSync(source, target, { recursive: true, filter: (file) => !/\.(tmp|import)$/.test(file) });

// Godot's PWA manifest is bare. Add what Chrome wants for an installable app: a 192 px icon (Godot has no option for
// that size), a short name, a scope and colours. (Only when the export is a PWA export.)
const manifestPath = join(target, 'index.manifest.json');
if (existsSync(manifestPath)) {
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const icon192 = resolve(root, '..', 'art', 'icons', 'android-192.png');
  if (existsSync(icon192)) {
    copyFileSync(icon192, join(target, 'index.192x192.png'));
    manifest.icons.push({ sizes: '192x192', src: 'index.192x192.png', type: 'image/png' });
  }
  Object.assign(manifest, {
    short_name: 'Xoddam',
    description: 'Become a T-Rex. Save the puppies.',
    id: '/play/',
    scope: './',
    theme_color: manifest.background_color,
    lang: 'en',
    categories: ['games'],
  });
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
}

writeFileSync(
  join(target, '.htaccess'),
  `# Written by scripts/copy-game.mjs
<IfModule mod_deflate.c>
  <FilesMatch "\\.(html|js|wasm|pck|json|webmanifest|svg)$">
    SetOutputFilter DEFLATE
  </FilesMatch>
</IfModule>
<IfModule mod_mime.c>
  AddType application/wasm .wasm
</IfModule>
<IfModule mod_headers.c>
  # The game files keep the same names between versions: always check for a newer one (cheap when unchanged).
  Header set Cache-Control "no-cache"
</IfModule>
`,
);
console.log(`copy-game: copied ${readdirSync(target).length} files to dist/play`);
