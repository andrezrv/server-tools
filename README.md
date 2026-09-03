# Server administration tools

Server administration tooling for WordPress sites on Ubuntu 26.04.

## bin/ — installed at /usr/local/bin/ on the server

`bin/wps` is the single entry point; `bin/server-tools/` holds the individual subcommands (not installed on PATH directly). The GitHub
Actions workflow in `.github/workflows/deploy.yml` handles deployment on every push to `main`. To deploy manually:

```
# Dispatcher
sudo install -m 700 -o root -g root bin/wps /usr/local/bin/wps

# Subcommands
sudo mkdir -p /usr/local/bin/server-tools
for f in bin/server-tools/*; do
  sudo install -m 700 -o root -g root "$f" /usr/local/bin/server-tools/
done
```

All tools are invoked as `wps <command> [args]`:

- **wps backup** — daily cron backup (DB + files) across every
  site under /var/www with a valid `current` symlink. Auto-discovers
  sites, no per-site configuration needed. Supports
  `--db-only`/`--files-only` and an optional site-name argument for
  one-off runs.
- **wps site:info** — prints every path the provision process creates for a site, with `[OK]`, `[MISSING]`, or `[DISABLED]` status for each. Also shows the active release, system user, slug, and DB credentials read from `.env.production`.
- **wps site:restore** — full restore from a backup archive. Builds
  into a new release directory and only swaps `current` after verifying
  it, never touches the live release in place.
- **wps site:provision** — creates a brand-new site end to end (DB,
  system user, directory skeleton, FPM pool, cron, Nginx config,
  optionally SSL), stopping right before an actual deploy. Interactive
  prompts for domain and system-user slug.
- **wps site:disable** — takes a site offline (removes it from
  sites-enabled, clears its crontab) without deleting anything. Fully
  reversible — prints the exact commands to undo it.
- **wps site:remove** — permanently deletes everything
  `wps site:provision` created for a site: Nginx config, FPM pool,
  cron, SSL cert, database, files, system user. Requires typing the
  domain to confirm. Won't remove a system user if it's still shared by
  another site.
- **wps release:activate** — shared "make this release live" logic
  (symlink swap, service restarts, cache clear, release-timestamp
  recording). Used by both `finish-deploy` (in the site's own repo) and
  `wps release:rollback`.
- **wps release:rollback** — interactive. Lists releases still on disk
  for a site and lets you switch back to one without a full backup
  restore.

## nginx/

- **wordpress-site.conf.template** — boilerplate for a new site's
  Nginx config. `SITENAME` is a placeholder to find-and-replace with
  the real domain. Deliberately excludes all SSL config — certbot adds
  that automatically. Place at `/etc/nginx/templates/` (not
  sites-available/sites-enabled, so it's never accidentally loaded as
  a real site) — `wps site:provision` reads it from exactly that path.

## sudoers/

Both go in `/etc/sudoers.d/`, installed via `visudo -f` (never edit
directly), each validated with `visudo -c` after. The deploy workflow
handles this automatically; to install manually (replace `your-deploy-user` with the actual OS login username):

```bash
for name in backups deploy; do
  sed "s/DEPLOY_USER/your-deploy-user/g" sudoers/$name > /tmp/sudoers-$name
  sudo visudo -c -f /tmp/sudoers-$name
  sudo install -m 440 -o root -g root /tmp/sudoers-$name /etc/sudoers.d/$name
  rm /tmp/sudoers-$name
done
```

- **backups** — lets the `DEPLOY_USER` login user run `wps` as root
  without a password, needed since it's invoked over non-interactive
  SSH (no TTY for a password prompt) by `db-sync`, `wps site:restore`,
  and `finish-deploy`.
- **deploy** — same, for `finish-deploy` specifically, invoked by
  GitHub Actions. Deliberately has no wildcard in it — Ubuntu 26.04's
  `sudo-rs` doesn't support wildcards in sudoers rules at all.

## cloudflare/

- **deploy-trigger-worker.js** — a Cloudflare Worker with two Cron
  Triggers (daily deploy, weekly keep-alive commit), calling GitHub's
  `workflow_dispatch` API. Exists because GitHub's own native
  `schedule:` trigger proved unreliable for this repo. Needs a
  `GITHUB_TOKEN` secret (a fine-grained PAT scoped to just the repo,
  Actions read/write) set in the Worker's settings.
