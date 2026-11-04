# Hosting xoddam.com

How the website and the web game are hosted. Server addresses and account names are **not** written here (this repo is
public): they live in the project's `.env` file, which git ignores. Copy `.env.example` to start one.

| Piece | Where | Notes |
|---|---|---|
| Domain | Porkbun | Registered by hand. API access is switched on for the domain, so a script can change nameservers. |
| DNS | DigitalOcean | One zone for `xoddam.com`: an A record for the bare domain pointing at the web server, a CNAME for `www`, and a Google Search Console TXT record. **Never remove the TXT record** (that un-verifies the site). |
| Web server | A shared Linux server with cPanel/WHM and Apache | One cPanel account for this site; its web folder is the site root. |
| https | cPanel AutoSSL (Let's Encrypt) | Covers `xoddam.com` and `www`. Renews by itself. |
| Uploads | ssh, as the site's account, with a key | `python site/scripts/deploy.py` (see `site/README.md`). |
| Analytics | Google Analytics 4 and Search Console | Set up by hand in a Google account. The tag is on every page, including the game page. |

## Things learned while setting it up

- cPanel's data for a new account (`/var/cpanel/userdata/<user>/`) must be readable by the account. If AutoSSL says
  "no document root for the domain", check those file permissions (644, like other accounts on the server).
- A new account's domains can start on AutoSSL's exclusion list. Remove the real ones with
  `uapi --user=<user> SSL remove_autossl_excluded_domains domains=<a>,<b>`.
- A folder holding the 100 MB APK must not contain an `.htaccess` file (it made the server answer 500 for the download).
- New cPanel accounts go to whichever matching home folder has the most free space. To move one:
  WHM > List Accounts > Change Disk Partition.

## What is on the site

`/` the landing page, `/privacy/`, `/play/` (the web game, also installable from the browser) and, when an Android app
has been built, `/download/xoddam.apk` (see [android-build.md](android-build.md)).

## Server rules we manage

`site/scripts/htaccess-block.txt` is the only part of the server's `.htaccess` that the deploy script touches (the
block between the `# --- Xoddam` markers): http to https and www to the bare domain in one redirect, the 404 page,
gzip and caching. The game folder `/play/` also has its own `.htaccess` (written by `scripts/copy-game.mjs`):
compression and `no-cache`, so a phone always checks for a newer game.
