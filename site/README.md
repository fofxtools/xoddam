# xoddam.com (the website)

A small Astro site: a landing page, a privacy page, a 404 page, and the game itself at `/play/`.

```
site/
  src/config.ts            name, tagline, Google Analytics ID (gaId)
  src/layouts/Base.astro   head (title, social preview, GA tag), shared styles
  src/pages/               index (landing), privacy, 404
  public/                  pictures, icons, robots.txt (copied as they are)
  scripts/copy-game.mjs    copies ../build/web into dist/play and writes the game's server rules
  scripts/copy-apk.mjs     copies the built Android app into dist/download (when there is one)
  scripts/htaccess-block.txt  the server rules we manage (redirects, caching, 404 page)
  scripts/deploy.py        build + upload + clean up + check
```

## Work on it

```
cd site
npm install            # once
npm run dev            # live preview of the site (the game is not copied in)
npm run build          # site + game into dist/
```

## Put a new version live

Run these from the `site` folder (`cd site`). In Windows PowerShell 5 use `;`, not `&&`, to join commands.

1. If the game changed, export it as a release build first (see `../docs/web-build.md`).
2. `python scripts/deploy.py --dry-run` shows what would be uploaded, deleted and changed. Nothing is touched.
3. `python scripts/deploy.py` builds, uploads, removes stale files, updates our block of the server's `.htaccess`
   and checks the live pages. `--skip-game` builds the site without the game and leaves the game on the server
   alone; `--no-build` uploads `dist/` as it is.

## Where it lives

On a shared cPanel web server, reached over ssh. DNS is at DigitalOcean, the domain is registered at Porkbun, and the
https certificate comes from cPanel's AutoSSL and renews by itself. Details: [../docs/hosting.md](../docs/hosting.md).
The server address, account and web folder are kept in the project's `.env` file (not in git). Copy `.env.example`
to `.env` (in the project root) and fill in the `XODDAM_` lines before the first deploy.

## Google Analytics

The tag is on every page, including the game page. It is set in two places: `src/config.ts` (the site) and the
`html/head_include` option of the Web preset in `../export_presets.cfg` (the game page). Change both together.
