#!/usr/bin/env python3
"""Build the Android app: a release APK signed with our key, in build/android/xoddam.apk.

    python tools/export_android.py

Reads the project's .env file (see .env.example) for:
  GODOT_BIN                               the Godot console exe
  GODOT_ANDROID_KEYSTORE_RELEASE_PATH     the signing key file (storage/keys/, git-ignored)
  GODOT_ANDROID_KEYSTORE_RELEASE_USER     the key's alias
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD its password (Godot reads these three itself)
  JAVA_HOME, ANDROID_SDK_ROOT             only for the checks at the end (optional)

After exporting it checks the file with the Android SDK's own tools: the signature and the app's package name,
version, supported processors and permissions. Run it from anywhere. The one-time setup is in docs/android-build.md.
"""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "android" / "xoddam.apk"


def load_env() -> dict:
    values = {}
    path = ROOT / ".env"
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()
    return values


def main() -> None:
    env = load_env()
    godot = env.get("GODOT_BIN") or os.environ.get("GODOT_BIN")
    keystore = env.get("GODOT_ANDROID_KEYSTORE_RELEASE_PATH")
    if not godot or not Path(godot).exists():
        sys.exit("GODOT_BIN is missing or wrong in .env (see .env.example)")
    if not keystore or not Path(keystore).exists():
        sys.exit("GODOT_ANDROID_KEYSTORE_RELEASE_PATH is missing or wrong in .env: the signing key file is not there")

    child_env = dict(os.environ)
    for key in ("GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"):
        if not env.get(key):
            sys.exit(f"{key} is missing in .env")
        child_env[key] = env[key]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        OUT.unlink()
    print("exporting (the first run also imports every picture for Android; that takes a few minutes) ...")
    result = subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-release", "Android", str(OUT)], env=child_env)
    if result.returncode != 0 or not OUT.exists():
        sys.exit(
            f"export failed (exit code {result.returncode}); read the messages above.\n"
            "If they mention the Android SDK or Java SDK path: set both in Godot under Editor Settings > Export > Android "
            "(see docs/android-build.md)."
        )
    print(f"\nbuilt {OUT} ({OUT.stat().st_size / 1e6:.1f} MB)")

    sdk = Path(env.get("ANDROID_SDK_ROOT") or Path.home() / "Android" / "Sdk")
    tools = sorted((sdk / "build-tools").glob("*"))
    if not tools:
        print("(skipping the checks: no Android SDK build-tools found; set ANDROID_SDK_ROOT in .env)")
        return
    build_tools = tools[-1]
    check_env = dict(os.environ)
    if env.get("JAVA_HOME"):
        check_env["JAVA_HOME"] = env["JAVA_HOME"]
    suffix = ".bat" if os.name == "nt" else ""
    print("\nsignature:")
    subprocess.run([str(build_tools / f"apksigner{suffix}"), "verify", "--print-certs", "-v", str(OUT)], env=check_env)
    print("\napp details:")
    badging = subprocess.run([str(build_tools / ("aapt.exe" if os.name == "nt" else "aapt")), "dump", "badging", str(OUT)], capture_output=True, text=True)
    for line in badging.stdout.splitlines():
        if line.startswith(("package:", "sdkVersion", "targetSdkVersion", "uses-permission", "native-code", "application-label:", "launchable-activity")):
            print("  " + line.strip())


if __name__ == "__main__":
    main()
