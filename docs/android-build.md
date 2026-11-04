# Android app (an APK you install yourself)

The game can be built as an Android app: one `.apk` file, signed with our own key, for tablets and phones. It is for
installing directly (no Google Play). It is the same game as the website's, but a real app: Godot's own audio, full
screen, its own icon, and the saved game kept on the device.

Quick version:

```bash
python tools/export_android.py     # builds build/android/xoddam.apk and checks it
cd site; python scripts/deploy.py  # puts it on the website at /download/xoddam.apk
```

`build/` is not in git, and neither is the APK or the signing key. Never commit them.

## One-time setup (already done on the main PC)

You need these on the machine that builds:

1. **Java 17** (a JDK), for example the Eclipse Temurin 17 zip from adoptium.net, unzipped anywhere.
2. **The Android SDK**, from the "command line tools only" download at developer.android.com/studio. Put it in
   `<sdk>/cmdline-tools/latest/`, then, with `JAVA_HOME` set to the JDK:

   ```
   sdkmanager --sdk_root=<sdk> --licenses
   sdkmanager --sdk_root=<sdk> "platform-tools" "build-tools;35.0.1" "platforms;android-35" "cmdline-tools;latest"
   ```

   (Godot's docs also list CMake and the NDK; they are only needed for Gradle builds, which we do not use.)
3. **Godot's Android export templates**: from the 4.7.2 templates package (`Godot_v4.7.2-stable_export_templates.tpz`,
   a zip) copy `android_debug.apk`, `android_release.apk` and `android_source.zip` into
   `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
4. **Godot's editor settings** (Editor Settings > Export > Android): set *Java SDK Path* and *Android SDK Path*. Godot
   keeps them in `editor_settings-4.7.tres`.
5. **In the project** (already set, in git): the Android preset in `export_presets.cfg`, landscape orientation
   (`display/window/handheld/orientation`), and ETC2/ASTC texture support
   (`rendering/textures/vram_compression/import_etc2_astc`, which Godot requires for Android).

## The signing key

Android uses a key as the app's identity. **A new version installs over an old one only if it is signed with the same
key.** Lose the key and every tablet has to uninstall the app first, which also erases its saved game. So:

- It lives in the project's git-ignored **`storage/keys/`** folder (`storage/keys/xoddam-release.keystore`), and
  both exports exclude `storage/`. **Back it up** somewhere else too, together with its password: `git clean -x`,
  deleting the folder or re-cloning the project would remove it. Never remove the `/storage` or `*.keystore` lines
  from `.gitignore`, and never `git add -f` anything in it (the repository is public).
- Its path, alias and password are in the project's `.env` (git ignores it), under the names Godot reads itself:
  `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER` and `..._PASSWORD`. Nothing secret is written in
  `export_presets.cfg`, which is committed.
- It was made once with Java's `keytool`:

  ```
  keytool -genkeypair -keystore xoddam-release.keystore -alias xoddam -keyalg RSA -keysize 2048 -validity 10000
  ```

  (Godot needs the key password to equal the keystore password, and letters and digits only are safest.)

## Build

```bash
python tools/export_android.py
```

It reads `.env` (see `.env.example`), runs Godot's release export for the `Android` preset, and then uses the SDK's
own tools to check the file: the signature, and the app's name, version, processors and permissions. The first run
also imports every picture for Android and takes several minutes.

Result: `build/android/xoddam.apk` (about 100 MB). It has no permissions (not even the internet), and runs on
Android 7.0 and newer, on 64-bit and 32-bit ARM tablets (cheap tablets are often 32-bit).

### Versions

For each new APK, raise **`version/code` by 1** in the Android preset (`export_presets.cfg`) and update
**`version/name`**. Android refuses to install an APK whose code is not higher than the installed one. The website's
download link does not mention a version, so there is nothing to update there. The app's package name,
`com.xoddam.mighty`, must never change.

## Put it on the website

`site/scripts/copy-apk.mjs` copies the APK to `/download/xoddam.apk` whenever you build the site, and the landing page
then shows a **Download for Android** button (only when an APK exists at build time). So:

```bash
python tools/export_android.py
cd site; python scripts/deploy.py
```

If you deploy without an APK built, the website's existing download is left alone. `SKIP_APK=1` leaves the APK out
of a build on purpose. Do not put an `.htaccess` file in `/download/`: on this server any `.htaccess` in that folder made
the download answer with an error (500), and the server already sends `.apk` files with the right type.

## Install it on a tablet

1. On the tablet, open https://xoddam.com and tap **Download for Android**.
2. Tap the downloaded file. Android asks to allow installs from the browser (Settings > Install unknown apps), and
   Play Protect may warn about an app it does not know. Both are normal for an app outside the Play Store.
3. To **update**, download and tap the new file the same way. It installs over the old one and keeps the saved game.

With a USB cable and "USB debugging" on: `adb install -r build/android/xoddam.apk` (`adb` is in the SDK's
`platform-tools`).

## Status and gotchas

- **Not tried on a real tablet yet.** It builds, it is signed with our key, and its package details check out, but
  nobody has installed it.
- Godot keeps the SDK paths in its editor settings file. If the editor is open when you change that file by hand it
  may write its old values back; use Editor Settings instead, or close the editor first.
- The easiest way to the same result without any download is the website's "Add to Home screen" install (see
  [web-build.md](web-build.md)).
