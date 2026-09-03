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

All tools are invoked as `wps <command> [args]`:

- **wps backup** — daily cron backup (DB + files) across every site under /var/www with a valid `current` symlink. Auto-discovers sites, no per-site configuration needed. Supports `--db-only`/`--files-only` and an optional site-name argument for one-off runs.
- **wps site:info** — prints every path the provision process creates for a site, with `[OK]`, `[MISSING]`, or `[DISABLED]` status for each. Also shows the active release, system user, slug, and DB credentials read from `.env.production`.
- **wps site:restore** — full restore from a backup archive. Builds into a new release directory and only swaps `current` after verifying it, never touches the live release in place.
- **wps site:provision** — creates a brand-new site end to end (DB, system user, directory skeleton, FPM pool, cron, Nginx config, optionally SSL), stopping right before an actual deploy. Interactive prompts for domain and system-user slug.
- **wps site:disable** — takes a site offline (removes it from sites-enabled, clears its crontab) without deleting anything. Fully reversible — prints the exact commands to undo it.
- **wps site:remove** — permanently deletes everything `wps site:provision` created for a site: Nginx config, FPM pool, cron, SSL cert, database, files, system user. Requires typing the domain to confirm. Won't remove a system user if it's still shared by another site.
- **wps release:activate** — shared "make this release live" logic (symlink swap, service restarts, cache clear, release-timestamp recording). Used by both `finish-deploy` (in the site's own repo) and `wps release:rollback`.
- **wps release:rollback** — interactive. Lists releases still on disk for a site and lets you switch back to one without a full backup restore.

## nginx/

- **wordpress-site.conf.template** — boilerplate for a new site's Nginx config. `SITENAME` is a placeholder to find-and-replace with the real domain. Deliberately excludes all SSL config — certbot adds that automatically. Place at `/etc/nginx/templates/` (not sites-available/sites-enabled, so it's never accidentally loaded as a real site) — `wps site:provision` reads it from exactly that path.

## sudoers/

All three files go in `/etc/sudoers.d/`. They are installed automatically by `bin/server-tools-install` on every deploy. Each contains a `DEPLOY_USER` placeholder substituted at install time; each is validated with `visudo -c` before being written.

- **backups** — lets `DEPLOY_USER` run `wps` as root without a password, needed for non-interactive SSH invocations by `db-sync`, `wps site:restore`, and `finish-deploy`.
- **deploy** — lets `DEPLOY_USER` run `finish-deploy` (from the site repo) as root without a password, invoked by GitHub Actions.
- **server-tools-install** — lets `DEPLOY_USER` run the install script from their home directory as root without a password. This is the one rule that must be bootstrapped manually the first time (see above). All subsequent deploys keep it current.
