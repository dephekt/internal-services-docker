### Share your self-hosted apps safely, with single sign‑on

This stack lets you share apps running at home without opening router ports or exposing your home IP. Your users just visit a URL in their browser. You get HTTPS and single sign‑on (SSO). Apps that already support SSO can plug into your identity provider; apps that don’t can still sit behind a login screen.


## What’s inside (at a glance)
- Pangolin (managed self‑hosted) edge nodes for global ingress and failover
- Newt (local agent) for tunnel + autodiscovery via Docker labels
- Keycloak (auth) and MariaDB (db)


## How it works (one minute)
- Requests hit the closest Pangolin edge node
- Pangolin authenticates users (per your policy) and routes to your site’s Newt
- Newt discovers containers via Docker labels (Blueprints) and forwards to them

No client software is required for your users. Everything is just HTTPS in a browser.


## Before you start
- Docker + Docker Compose v2 installed
- Pangolin managed self‑hosted nodes deployed (see Pangolin docs)
- 1Password CLI (`op`) for secret injection (or adapt templates to your secret manager)
- For remote deployment: SSH access to your Docker host


## Setup in 6 steps
1) Configure non-secret settings (optional)
- Edit `core/config.env` and `ai/config.env` if you need to change domain or other public settings
- Default domain is `dephekt.net` - change it to yours

2) Generate secrets from 1Password
```bash
make inject-secrets   # generates core/secrets.env and ai/secrets.env
```
This uses your 1Password vault to populate secret values. The generated files are git-ignored.

3) (Optional) Create LAN shim if you need host LAN access
```bash
make lan-net
make shim
```

4) Start the core stack
```bash
make core-up   # newt, keycloak, db
```

5) No dashboard config needed if using Blueprints labels (Newt autodiscovers)

You should now reach:
- Keycloak at `https://auth.${DOMAIN}`

**Remote deployment:** Use Docker contexts - `docker context create remote --docker "host=ssh://user@host"`, then deploy normally.


## Add your first app (Pangolin Blueprints)
Expose a container with Pangolin proxy resource labels; Newt autodiscovers:

```yaml
labels:
  - "pangolin.proxy-resources.app.name=My App"
  - "pangolin.proxy-resources.app.protocol=http"
  - "pangolin.proxy-resources.app.full-domain=app.${DOMAIN}"
  - "pangolin.proxy-resources.app.targets[0].enabled=true"
  - "pangolin.proxy-resources.app.targets[0].port=8080"
```


## Certificates and HTTPS
TLS termination and cert management are handled by Pangolin at the edge.


## Common issues (and quick checks)
- Resource not visible: confirm Newt is running with Docker socket and labels are correct
- Wrong target port: set `targets[0].port` label explicitly


## Where things live
- Core stack: `core/docker-compose.yml`
- Config files (public): `core/config.env`
- Secrets directory (git-ignored): `core/secrets/`
- Make commands: `Makefile`
- Keycloak realm exports: `keycloak-import/` (import with `make auth-import`)


## Want the deep dive?
See `AGENTS.md` for service inventory, env variables, labels, and command reference.


 
