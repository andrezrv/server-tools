# Server administration tools

Server administration tooling for WordPress sites on Ubuntu 26.04.

## bin/ — installed at /usr/local/bin/ on the server

`bin/wps` is the single entry point; `bin/server-tools/` holds the individual subcommands (not installed on PATH directly). `bin/server-tools-install` is the install script — it runs as root and handles installing the dispatcher, subcommands, nginx template, and all sudoers files in one shot. The GitHub Actions workflow in `.github/workflows/deploy.yml` copies it to the server and calls it via `sudo` on every deploy. To deploy manually, copy it to the server and run it:

```bash
scp bin/server-tools-install your-deploy-user@your-server:~/server-tools-install
ssh your-deploy-user@your-server "sudo ~/server-tools-install ~/path/to/staging"
```

**First-time bootstrap only** — before the install script can run via `sudo`, its sudoers rule must exist. Install it once manually on the server (replace `your-deploy-user`):

```bash
sed "s|DEPLOY_USER|your-deploy-user|g" sudoers/server-tools-install > /tmp/s
sudo visudo -c -f /tmp/s && sudo install -m 440 -o root -g root /tmp/s /etc/sudoers.d/server-tools-install
rm /tmp/s
```

After that, every deploy re-installs all sudoers files automatically — including this one — so the bootstrap step is a one-time operation.

All tools are invoked as `wps <command> [args]`. Every subcommand accepts a `--json` flag that emits a single JSON object to stdout instead of human-readable output — useful for scripting, monitoring, and CI:

```bash
wps site:list --json | jq '.sites[] | select(.status != "ok")'
wps site:info example.com --json | jq '.paths.ssl_cert.status'
wps backup --json > /tmp/backup-result.json
```

Interactive commands (those that prompt for input) continue to show prompts on the terminal even in JSON mode — the JSON result is written to stdout at the end, so `wps site:provision --json > result.json` still works interactively while sending structured output to the file.

**Non-interactive mode** — every prompt can be skipped by passing `--key=value` flags, which is useful for scripting and CI. Any flag that is omitted falls through to its interactive prompt as normal.

| Command | Flag | Skips |
|---|---|---|
| `site:provision` | `--domain=example.com` | domain prompt |
| `site:provision` | `--slug=mysite` | slug prompt (still defaults to domain prefix if omitted) |
| `site:provision` | `--site-user=mysite-site` | system user prompt |
| `site:provision` | `--yes=y` | "Proceed?" confirmation |
| `site:provision` | `--certbot=y` or `--certbot=n` | certbot prompt |
| `site:provision` | `--certbot-www=y` or `--certbot-www=n` | "include www?" prompt |
| `site:install` | `--admin-user=admin` | admin username prompt |
| `site:install` | `--admin-pass=secret` | password + confirm prompts |
| `site:install` | `--admin-email=a@b.com` | admin email prompt |
| `site:install` | `--theme=mytheme` | theme selection prompt |
| `site:restore` | `--yes=y` | site-name confirmation |
| `site:restore` | `--db-backup=1234567890.sql.gz` | DB backup selection menu |
| `site:restore` | `--release-backup=1234567890-release-files.tar.gz` | release backup menu |
| `site:restore` | `--shared-backup=1234567890-shared-files.tar.gz` | shared backup menu |
| `release:rollback` | `--release=1234567890` | release selection menu |
| `release:rollback` | `--yes=y` | site-name confirmation |

- **wps site:list** — lists every site under `/var/www/` with its resolved document root and a `[OK]`/`[BROKEN]`/`[NO CURRENT]` status. JSON: `{"sites":[{"domain":"...","doc_root":"...","status":"ok|broken|no_current"}]}`.
- **wps backup** — daily cron backup (DB + files) across every site under /var/www with a valid `current` symlink. Auto-discovers sites, no per-site configuration needed. Supports `--db-only`/`--files-only` and an optional site-name argument for one-off runs. JSON: `{"sites":[{"domain":"...","db":{"status":"ok|skipped|failed","file":"..."},"release_files":{...},"shared_files":{...}}],"events":[...]}`.
- **wps site:info** — prints every path the provision process creates for a site, with `[OK]`, `[MISSING]`, or `[DISABLED]` status for each. Also shows the active release, system user, slug, and DB credentials read from `.env.production`. JSON: `{"domain":"...","site_user":"...","slug":"...","db_name":"...","db_user":"...","paths":{"site_root":{"path":"...","status":"ok|missing"},...}}`.
- **wps site:install** — installs WordPress on a provisioned site using the WP Boilerplate. Downloads the latest `main` branch, runs `composer update --no-dev`, deploys through the same `finish-deploy` + `release:activate` pipeline as managed sites, runs the initial WordPress database setup interactively, and schedules a daily `wps site:update` cron. Creates an `unmanaged` marker at the site root to distinguish from GitHub-deployed sites.
- **wps site:update** — pulls and deploys the latest WP Boilerplate code on an unmanaged site. Only runs on sites with the `unmanaged` marker; exits silently on managed sites. Automatically rolls back to the previous release if `finish-deploy` fails at any stage, including after the symlink has been swapped. Called daily by the cron set up by `wps site:install`. JSON: `{"domain":"...","status":"ok|error","rollback_status":"ok|failed","events":[...]}`.
- **wps site:restore** — full restore from a backup archive. Builds into a new release directory and only swaps `current` after verifying it, never touches the live release in place. Supports `--db-only`/`--files-only`/`--clean`.
- **wps site:provision** — creates a brand-new site end to end (DB, system user, directory skeleton, FPM pool, cron, Nginx config, optionally SSL), stopping right before an actual deploy. Interactive prompts for domain and system-user slug. JSON output includes the generated `db_password`.
- **wps site:disable** — takes a site offline (removes it from sites-enabled, clears its crontab) without deleting anything. Fully reversible — prints the exact commands to undo it. JSON: `{"domain":"...","status":"disabled","reenable_cmd":"...","restore_cron_cmd":"...","events":[...]}`.
- **wps site:remove** — permanently deletes everything `wps site:provision` created for a site: Nginx config, FPM pool, cron, SSL cert, database, files, system user. Requires typing the domain to confirm. Won't remove a system user if it's still shared by another site.
- **wps release:activate** — shared "make this release live" logic (symlink swap, service restarts, cache clear, release-timestamp recording). Used by both `finish-deploy` (in the site's own repo) and `wps release:rollback`. JSON: `{"site":"...","release":"...","status":"activated","events":[...]}`.
- **wps release:rollback** — interactive. Lists releases still on disk for a site and lets you switch back to one without a full backup restore. JSON: `{"site":"...","previous_release":"...","activated_release":"...","status":"rolled_back|already_live"}`.

## bin/update-cloudflare-ips — standalone cron script

Installed at `/usr/local/bin/update-cloudflare-ips` (not a `wps` subcommand). Fetches the current Cloudflare IP ranges and updates the server firewall accordingly. Meant to be wired up as a cron job rather than called interactively.

## nginx/

- **wordpress-site.conf.template** — boilerplate for a new site's Nginx config. `SITENAME` is a placeholder to find-and-replace with the real domain. Deliberately excludes all SSL config — certbot adds that automatically. Place at `/etc/nginx/templates/` (not sites-available/sites-enabled, so it's never accidentally loaded as a real site) — `wps site:provision` reads it from exactly that path.

## sudoers/

All three files go in `/etc/sudoers.d/`. They are installed automatically by `bin/server-tools-install` on every deploy. Each contains a `DEPLOY_USER` placeholder substituted at install time; each is validated with `visudo -c` before being written.

- **backups** — lets `DEPLOY_USER` run `wps` as root without a password, needed for non-interactive SSH invocations by `db-sync`, `wps site:restore`, and `finish-deploy`.
- **deploy** — lets `DEPLOY_USER` run `finish-deploy` (from the site repo) as root without a password, invoked by GitHub Actions.
- **server-tools-install** — lets `DEPLOY_USER` run the install script from their home directory as root without a password. This is the one rule that must be bootstrapped manually the first time (see above). All subsequent deploys keep it current.
