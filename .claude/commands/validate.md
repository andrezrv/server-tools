Pre-push validation: verify that config files are deploy-ready before the GitHub Actions workflow runs.

## Checks

Run all of the following. Report each as PASS or FAIL with a reason. Stop and report all failures together — do not abort on the first one.

### 1. Placeholder integrity — sudoers files

Both sudoers files must still contain the `DEPLOY_USER` token (i.e. it hasn't been accidentally replaced with a real username):

```bash
grep -q "DEPLOY_USER" sudoers/backups
grep -q "DEPLOY_USER" sudoers/deploy
```

FAIL if either file contains a literal username where `DEPLOY_USER` should be, or if the token is missing entirely.

### 2. Placeholder integrity — nginx template

The nginx template must still contain the `SITENAME` token:

```bash
grep -q "SITENAME" nginx/wordpress-site.conf.template
```

### 3. Sudoers syntax

Validate both sudoers files with visudo. Note: this requires sudo.

```bash
sudo visudo -c -f sudoers/backups
sudo visudo -c -f sudoers/deploy
```

FAIL if either file fails validation.

## After all checks

- All PASS → confirm the package is ready to push.
- Any FAIL → list every failure and stop. Do not suggest pushing until they are resolved.
