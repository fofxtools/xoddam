#!/usr/bin/env python3
"""Build the site and put it on the live server (xoddam.com: a web host reached over ssh).

    python scripts/deploy.py [--dry-run] [--no-build] [--skip-game]

  1. build      npm run build (the site, with the exported game copied into dist/play; see copy-game.mjs)
  2. upload     dist/ -> ~/public_html over ssh (a tar stream; no rsync needed on Windows)
  3. prune      delete files on the server that are no longer in dist/ (never .htaccess, cgi-bin, .well-known, ...)
               (the game folder is kept when you build with --skip-game, and the download folder when no APK was built)
  4. .htaccess  replace only our marked block of the server's .htaccess with scripts/htaccess-block.txt
  5. check      the live pages answer as expected

--dry-run builds nothing and changes nothing on the server: it lists what would be uploaded, deleted and changed.
Needs the server details in the project's .env file (copy .env.example to .env; git ignores it) and the ssh key that
is installed for the account (default ~/.ssh/id_ed25519).
"""

import argparse
import http.client
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

SITE_DIR = Path(__file__).resolve().parent.parent
DIST = SITE_DIR / "dist"
BLOCK_FILE = Path(__file__).resolve().parent / "htaccess-block.txt"


def _load_settings() -> dict:
    """Server details come from the project's .env file (not in git) or the environment; see .env.example."""
    values = {}
    path = SITE_DIR.parent / ".env"
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("XODDAM_") and "=" in line:  # the file may hold other settings; take only ours
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip()
    values.update({k: v for k, v in os.environ.items() if k.startswith("XODDAM_")})
    missing = [k for k in ("XODDAM_HOST", "XODDAM_USER", "XODDAM_DOCROOT") if not values.get(k)]
    if missing:
        sys.exit(f"deploy: missing {', '.join(missing)}. Copy .env.example to .env (project root) and fill them in.")
    return values


_SETTINGS = _load_settings()
HOST = _SETTINGS["XODDAM_HOST"]
USER = _SETTINGS["XODDAM_USER"]
DOCROOT = _SETTINGS["XODDAM_DOCROOT"]
KEY = _SETTINGS.get("XODDAM_KEY") or str(Path.home() / ".ssh" / "id_ed25519")
URL = "https://xoddam.com"

# Things on the server that are not part of the site and must survive a deploy.
PROTECTED = [".htaccess", "cgi-bin", ".well-known", "php.ini", ".user.ini", "error_log"]
BLOCK_START = "# --- Xoddam:"
BLOCK_END = "# --- end Xoddam ---"

SSH = ["ssh", "-o", "BatchMode=yes", "-o", "IdentitiesOnly=yes", "-i", KEY, f"{USER}@{HOST}"]


def remote(command: str, stdin: bytes | None = None) -> str:
    result = subprocess.run(SSH + [command], input=stdin, capture_output=True, check=True)
    return result.stdout.decode("utf-8", "replace")


def build() -> None:
    npm = "npm.cmd" if os.name == "nt" else "npm"
    subprocess.run([npm, "run", "build"], cwd=SITE_DIR, check=True)


def local_files() -> set[str]:
    return {p.relative_to(DIST).as_posix() for p in DIST.rglob("*") if p.is_file() and p.suffix != ".import"}


def upload(dry_run: bool) -> None:
    top = sorted(p.name for p in DIST.iterdir())  # named one by one, so the server's public_html itself is untouched
    size = sum(p.stat().st_size for p in DIST.rglob("*") if p.is_file())
    print(f"upload: {len(local_files())} files, {size / 1e6:.1f} MB")
    if dry_run:
        return
    # (Godot writes .import files next to any picture it finds in the project; they must not go live)
    tar = subprocess.Popen(["tar", "-czf", "-", "--exclude=*.import", "-C", str(DIST), *top], stdout=subprocess.PIPE)
    untar = f"tar -xzf - --no-same-owner --no-same-permissions --no-overwrite-dir -C '{DOCROOT}'"
    result = subprocess.run(SSH + [untar], stdin=tar.stdout)
    tar.stdout.close()
    if tar.wait() != 0 or result.returncode != 0:
        sys.exit("upload failed")


def prune(dry_run: bool) -> None:
    listing = remote(f"cd '{DOCROOT}' && find . -type f | sed 's#^\\./##'")
    keep = local_files()
    extra = []
    for path in listing.split("\n"):
        path = path.strip()
        if not path or path in keep:
            continue
        if any(path == p or path.startswith(p + "/") for p in PROTECTED):
            continue
        extra.append(path)
    print(f"prune: {len(extra)} stale file(s) on the server")
    for path in extra:
        print("  -", path)
    if extra and not dry_run:
        quoted = " ".join("'" + p.replace("'", "'\\''") + "'" for p in extra)
        remote(f"cd '{DOCROOT}' && rm -f -- {quoted}")
    if not dry_run:
        skip = " ".join(f"-not -path './{p}' -not -path './{p}/*'" for p in PROTECTED)
        remote(f"cd '{DOCROOT}' && find . -mindepth 1 -type d -empty {skip} -delete")


def sync_htaccess(dry_run: bool) -> None:
    block = BLOCK_FILE.read_text(encoding="utf-8").strip("\n") + "\n"
    current = remote(f"cat '{DOCROOT}/.htaccess' 2>/dev/null || true")
    pattern = re.compile(re.escape(BLOCK_START) + r".*?" + re.escape(BLOCK_END) + r"\n?", re.S)
    if pattern.search(current):
        new = pattern.sub(lambda m: block, current, count=1)
    else:
        new = block + "\n" + current
    if new == current:
        print(".htaccess: already up to date")
        return
    print(".htaccess: our block " + ("would be updated" if dry_run else "updated"))
    if not dry_run:
        remote(
            f"cp -p '{DOCROOT}/.htaccess' ~/htaccess.before-deploy 2>/dev/null; cat > '{DOCROOT}/.htaccess' && chmod 644 '{DOCROOT}/.htaccess'",
            stdin=new.encode("utf-8"),
        )


def check() -> None:
    def status(url: str) -> int:
        """The status of a HEAD request, without following redirects (so a 301 shows as 301)."""
        parts = urlsplit(url)
        conn = (http.client.HTTPSConnection if parts.scheme == "https" else http.client.HTTPConnection)(parts.netloc, timeout=30)
        conn.request("HEAD", parts.path or "/", headers={"User-Agent": "xoddam-deploy-check"})
        return conn.getresponse().status

    checks = [
        (f"{URL}/", 200),
        (f"{URL}/privacy/", 200),
        (f"{URL}/play/", 200),
        (f"{URL}/play/index.wasm", 200),
        (f"{URL}/play/index.manifest.json", 200),
        (f"{URL}/sitemap-index.xml", 200),
        (f"{URL}/robots.txt", 200),
        (f"{URL}/no-such-page/", 404),
        ("http://xoddam.com/", 301),
        ("https://www.xoddam.com/", 301),
    ]
    if (DIST / "download" / "xoddam.apk").exists():
        checks.append((f"{URL}/download/xoddam.apk", 200))
    bad = 0
    for url, want in checks:
        got = status(url)
        flag = "ok " if got == want else "BAD"
        bad += got != want
        print(f"  {flag} {got} (want {want}) {url}")
    if bad:
        sys.exit(f"check: {bad} unexpected answer(s)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="change nothing; list what would happen")
    parser.add_argument("--no-build", action="store_true", help="upload the existing dist/ as it is")
    parser.add_argument("--skip-game", action="store_true", help="build the site without copying the game in")
    args = parser.parse_args()

    if not args.no_build and not args.dry_run:
        if args.skip_game:
            os.environ["SKIP_GAME"] = "1"
            PROTECTED.append("play")  # the build has no game in it, so leave the one on the server alone
        build()
    if not DIST.exists():
        sys.exit("no dist/ folder: build first (or drop --no-build / --dry-run)")
    if not (DIST / "download").exists():
        PROTECTED.append("download")  # no Android app in this build: leave the one on the server alone
    upload(args.dry_run)
    prune(args.dry_run)
    sync_htaccess(args.dry_run)
    if not args.dry_run:
        print("check:")
        check()
    print("done" + (" (dry run)" if args.dry_run else ""))


if __name__ == "__main__":
    main()
