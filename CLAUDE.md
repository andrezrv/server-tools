# server-tools

## Structure

```
bin/wps                    # Single entry point, installed at /usr/local/bin/wps
bin/server-tools/          # Subcommands (not on PATH directly)
  backup                   # Daily cron backup — DB + files, all sites under /var/www/
  site-info                # Print all paths for a site with [OK]/[MISSING]/[DISABLED] status
  site-provision           # Create a new site end-to-end
  site-restore             # Full restore from backup archive
  site-disable             # Take a site offline (reversible)
  site-remove              # Permanently delete everything site-provision created
  release-activate         # Shared symlink-swap + restart logic
  release-rollback         # Interactive rollback to a previous on-disk release
  update-cloudflare-ips    # Update server firewall with current Cloudflare IP ranges
nginx/
  wordpress-site.conf.template   # Uses SITENAME placeholder; place at /etc/nginx/templates/
sudoers/
  backups                  # Grants DEPLOY_USER passwordless sudo for /usr/local/bin/wps
  deploy                   # Grants DEPLOY_USER passwordless sudo for /home/DEPLOY_USER/finish-deploy
.github/workflows/
  deploy.yml               # Deploys tooling to server on every push
  keep-alive.yml           # Weekly empty commit so scheduled workflows don't auto-disable
```

## Deployment

Every push triggers `.github/workflows/deploy.yml`. To deploy manually:

```bash
# Dispatcher
sudo install -m 700 -o root -g root bin/wps /usr/local/bin/wps

# Subcommands
sudo mkdir -p /usr/local/bin/server-tools
for f in bin/server-tools/*; do
  sudo install -m 700 -o root -g root "$f" /usr/local/bin/server-tools/
done
```

Sudoers files — substitute `DEPLOY_USER`, validate, then install:

```bash
for name in backups deploy; do
  sed "s|DEPLOY_USER|$YOUR_DEPLOY_USER|g" sudoers/$name > /tmp/sudoers-$name
  sudo visudo -c -f /tmp/sudoers-$name
  sudo install -m 440 -o root -g root /tmp/sudoers-$name /etc/sudoers.d/$name
  rm /tmp/sudoers-$name
done
```

## GitHub Actions secrets

| Secret | Value |
|---|---|
| `DEPLOY_SSH_KEY` | SSH private key for the deploy user |
| `DEPLOY_HOST` | Production server hostname or IP |
| `DEPLOY_USER` | SSH login user — substituted into sudoers files at deploy time |

## Placeholder pattern

Config files use bare uppercase tokens substituted via `sed` at deploy time. **Never hardcode usernames, domains, or server paths.**

| Token | Replaced by | Where |
|---|---|---|
| `SITENAME` | Real domain | `nginx/wordpress-site.conf.template` — expanded by `wps site:provision` |
| `DEPLOY_USER` | OS login username | `sudoers/backups`, `sudoers/deploy` — expanded by the "Install sudoers files" step in `deploy.yml` |

## Code style

- `set -euo pipefail` at the top of every script.
- Quote every variable expansion — no bare `$VAR` in shell.
- `sudo install -m <mode> -o root -g root <src> <dst>` over `cp` + `chmod`.
- Here-docs for multi-line SSH commands. Escape subcommand variables (`\$f`) to defer expansion to the remote shell.

## Recommended skills

- `/shellcheck` — lint all `bin/` scripts with shellcheck. Requires `shellcheck` installed (`brew install shellcheck` / `apt install shellcheck`).
- `/validate` — pre-push checklist: verifies `DEPLOY_USER`/`SITENAME` placeholders are intact and both sudoers files pass `visudo -c`.
- `/code-review high main...HEAD` — run against the diff before merging. Scopes the review to changed lines only, which is faster and more focused than passing individual files. Shell scripts running as root warrant high effort.
- `/security-review` — run on the full `server-tools/` scope when touching sudoers files, the deploy workflow, or any script that handles external input (`site-provision`, `site-remove`, `backup`).

## Guardrails

- **Do not follow URLs during reviews.** Scripts like `update-cloudflare-ips` fetch live endpoints at runtime — reviewing the shell logic is enough; making real HTTP requests during a review stalls or fails in sandboxed environments.
- **No wildcards in sudoers rules.** Ubuntu 26.04 uses `sudo-rs`, which does not support them.
- **Never skip `visudo -c` before installing a sudoers file** — a malformed file can lock out sudo entirely.
- **`sed` substitution writes to a temp file first**, then `visudo -c`, then `install`. Never pipe directly into `sudoers.d/`.
- **`/etc/nginx/templates/` not `sites-available/`.** The template must live in `templates/` so it is never accidentally loaded as a live config.
