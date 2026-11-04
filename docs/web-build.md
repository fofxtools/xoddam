# Web build (to try the game, and the touch buttons, in a browser)

The export preset is `Web` in `export_presets.cfg`. It writes to `build/web/` (git ignores `build/`). It leaves out
`art/concepts`, `tmp`, `tools`, `docs` and `tests`, and adds the level maps (`levels/*.txt`), which Godot does not
export by itself because they are plain text files. Threads are off, so any plain web server works (no special headers).

## Export

Needs the 4.7.2 web export templates (installed once in `%APPDATA%\Godot\export_templates\4.7.2.stable\`).
From the project folder. Windows PowerShell (`$godot` is the path of Godot's console exe, as in
[tests/README.md](../tests/README.md)):

```powershell
$godot = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --export-release "Web" build/web/index.html
```

Linux or Mac: the same with `godot` instead of `& $godot`.

Use `--export-debug` instead for a build with "Debug Level Select" on the title screen (handy on a phone). The live
site always gets `--export-release`. The result is about 56 MB of game data plus about 38 MB of engine. The Web preset also puts the
Google Analytics tag into the game page (its `html/head_include` option).

## Installing it from the browser (PWA)

The Web preset has Godot's "progressive web app" options on, so the game can be put on a phone's or tablet's home
screen from the browser (Chrome: menu > Install app or Add to Home screen; iPhone and iPad: Safari's Share button >
Add to Home Screen). It then opens full screen, in landscape, with the game's icon, and works offline once loaded.

- The export adds `index.manifest.json`, the icons (`art/icons/pwa-*.png`, listed in the preset), an offline page and
  a service worker. `site/scripts/copy-game.mjs` completes the manifest (a 192 px icon, short name, scope, colours)
  when it copies the game into `dist/play`.
- `ensure_cross_origin_isolation_headers` must stay **off**: with it on, the service worker adds headers that block
  the Google Analytics script.
- **Updates take one extra visit.** The service worker keeps the game in the browser's cache (about 90 MB) and serves
  it from there. After a deploy the new version is fetched in the background, and it is used the next time the app is
  opened after the old one is closed. Plan for that when testing a new deploy.
- The built-in browser pane in Claude's desktop app cannot register service workers, so this was checked by reading
  the manifest and icons, not by installing. Try the install on a real phone.

## Sound in the browser

Godot web exports play sound as "samples" by default (low latency, and it does not depend on the frame rate, so it
does not crackle in single-threaded builds). Rules we follow so that works:

- **Define audio buses in `default_bus_layout.tres`; never call `AudioServer.add_bus()` while the game runs.** In
  Godot 4.3 to 4.7 a bus added at runtime scrambles the browser-side bus list and cuts Master off from the speakers:
  total silence (Godot issue 119026, fixed in 4.8 by PR 123996, not backported to 4.7). `Audio._ensure_bus` only
  creates a bus, by growing `bus_count`, if the layout file is missing.
- Do not set `audio/general/default_playback_type.web` to Stream. It worked around the silence, but Stream mixes sound
  in the game loop, so it can sound scratchy (as it did for us on the live site).
- Check sound without ears: a small probe that wraps `AudioContext` in a test copy of `index.html` and reads an
  `AnalyserNode` on the output. Silent is peak 0; our title music reads about 0.1 to 0.5.
- Not bugs: a browser only starts sound after the first tap, click or key press, and iPhone Safari is silent while
  the ringer/silent switch is on. Reaching the game through the website's "Play now" link counts as a click that
  carries over, so the music can start at once; after a page reload there is no click yet, so the title screen is silent
  until the first one. We tested this by making a copy of the game whose `AudioContext` stays blocked until a real
  click or key press (imitating the browser rule): after the first click or key press the music started within 0.1 s,
  including on the intro screen.

## Put it on xoddam.com

Export a release build as above, then see `../site/README.md`: `python site/scripts/deploy.py` builds the website,
copies the game into `/play/` and uploads everything. Hosting details are in `hosting.md`.

## Try it on this PC

```
cd build/web
python -m http.server 8060 --bind 127.0.0.1
```

Then open http://127.0.0.1:8060/index.html. The first load takes a few seconds.

## Try it on a phone or tablet

- Same Wi-Fi: serve with `--bind 0.0.0.0` instead, find this PC's address (`ipconfig`), allow Python through the
  Windows firewall, and open `http://<that address>:8060/index.html` on the phone. (From inside a VM this needs the
  VM's network set to "bridged".)
- Anywhere: put the `build/web` folder on any static host, for example a password-protected itch.io page.
- iPhone: Safari keeps its address bar (no real fullscreen). "Add to Home Screen" gives a fullscreen look, but only
  over https.

## Touch buttons

`scripts/touch_controls.gd` has `always_show` on, so the buttons show everywhere. Turn it off for a release: they
then show only where the device has a touch screen (in a browser, the browser is asked directly).
