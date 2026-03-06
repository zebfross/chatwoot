# Chatwoot Deployment Guide

## Server

- **Host**: `chat.inceptify.com` (DigitalOcean droplet)
- **SSH**: `ssh root@chat.inceptify.com`
- **OS**: Ubuntu, 2 vCPUs, ~8GB RAM, 48GB disk
- **Ruby**: 3.4.4 via RVM (system-wide at `/usr/local/rvm`)
- **Node**: system-installed, with `pnpm` at `/usr/bin/pnpm`
- **App path**: `/home/chatwoot/chatwoot`
- **Branch**: `develop`

## Automatic Deployment (GitHub Actions)

Every push to `develop` triggers the **Deploy to DigitalOcean** workflow (`.github/workflows/deploy.yml`).

### What it does

1. Checks out the code on a GitHub runner
2. Builds frontend assets (`pnpm install`, `pnpm run build:sdk`, `npx vite build`)
3. SSHs into the server and runs `git pull --ff-only origin develop` + `rails db:migrate`
4. Rsyncs built assets (`public/packs/` and `public/vite/`) to the server
5. Fixes file ownership and restarts `chatwoot.target`

### Secrets required

- `DEPLOY_SSH_KEY` — SSH private key for root access to the server
- `DEPLOY_HOST` — Server hostname (`chat.inceptify.com`)

### Checking deploy status

The deploy workflow doesn't appear in `gh run list` because upstream Chatwoot's ~20 workflows push it off the default list. Use this instead:

```bash
gh api "repos/zebfross/chatwoot/actions/workflows/240720692/runs?per_page=5" \
  --jq '.workflow_runs[] | "\(.conclusion) | \(.created_at) | \(.display_title)"'
```

Or check in the GitHub UI: **Actions** tab > filter by **Deploy to DigitalOcean** workflow.

## Manual Deployment

If auto-deploy fails or you need to deploy immediately:

```bash
# 1. SSH into the server
ssh root@chat.inceptify.com

# 2. Pull latest code
cd /home/chatwoot/chatwoot
git pull origin develop

# 3. Run migrations (if any)
su - chatwoot -c 'cd /home/chatwoot/chatwoot && RAILS_ENV=production bundle exec rails db:migrate'

# 4. Rebuild frontend assets (needs extra memory for Vite)
su - chatwoot -c 'cd /home/chatwoot/chatwoot && NODE_OPTIONS="--max-old-space-size=4096" RAILS_ENV=production rake assets:precompile'

# 5. Restart services
systemctl restart chatwoot.target

# 6. Verify services are running
systemctl is-active chatwoot-web.1.service chatwoot-worker.1.service
```

### Ruby-only changes (no frontend)

If you only changed Ruby files (models, controllers, listeners, etc.), skip the asset build:

```bash
ssh root@chat.inceptify.com
cd /home/chatwoot/chatwoot
git pull origin develop
su - chatwoot -c 'cd /home/chatwoot/chatwoot && RAILS_ENV=production bundle exec rails db:migrate'
systemctl restart chatwoot.target
```

## Services

Managed via systemd:

| Service | Unit | Description |
|---------|------|-------------|
| Web (Puma) | `chatwoot-web.1.service` | Rails server on port 3000 |
| Worker (Sidekiq) | `chatwoot-worker.1.service` | Background jobs |
| Target | `chatwoot.target` | Groups both services |

```bash
# Restart everything
systemctl restart chatwoot.target

# Restart just web
systemctl restart chatwoot-web.1.service

# Check status
systemctl status chatwoot-web.1.service
systemctl status chatwoot-worker.1.service
```

## Viewing Logs

```bash
# Web server logs (live)
journalctl -u chatwoot-web.1.service -f

# Worker logs (live)
journalctl -u chatwoot-worker.1.service -f

# Recent errors
journalctl -u chatwoot-web.1.service --since '30 minutes ago' --no-pager | grep -i error

# Error details with full stack traces (most useful for debugging 500s)
journalctl -u chatwoot-web.1.service --since '10 minutes ago' --no-pager | grep -B2 -A15 '500\|FATAL\|Error'
```

## Pushing to develop

Upstream Chatwoot has a pre-push hook (`bin/validate_push`) that blocks direct pushes to `develop`. Bypass with:

```bash
git push --no-verify origin develop
```

## Troubleshooting

### Deploy workflow not triggering
- Verify the workflow file exists on the `develop` branch
- Check GitHub Actions is enabled for the repo
- Verify secrets are set: `gh api repos/zebfross/chatwoot/actions/secrets --jq '.secrets[].name'`

### Asset build OOM on server
The server has limited RAM. The auto-deploy avoids this by building on GitHub's runner and rsyncing assets. For manual builds, increase Node's heap:
```bash
NODE_OPTIONS="--max-old-space-size=4096" RAILS_ENV=production rake assets:precompile
```

### Service crash loop
Check what's causing the crash:
```bash
journalctl -u chatwoot-web.1.service --since '5 minutes ago' --no-pager | head -50
```
Common causes: migration not run, Ruby syntax error, enum conflict with ActiveRecord.

### Sidekiq memory limit
The worker has `MemoryMax=1.2G` set in its service file. If Sidekiq exceeds this, systemd kills it and it auto-restarts. Check with:
```bash
systemctl status chatwoot-worker.1.service
```
