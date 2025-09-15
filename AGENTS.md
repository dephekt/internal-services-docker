### Start here (for AI agents and power users)

- If you have not read `README.md`, read it first for intent and onboarding. This file is a quick reference, not a tutorial.


## Components at a glance
- **Traefik (router)**: Reverse proxy on the `proxy` network. Static config at `core/config/traefik/traefik.yml`. Forward‑auth middleware at `core/config/traefik/dynamic/forward-auth.yml`.
- **Cloudflare Zero Trust Tunnel (`cloudflared`)**: Connects Docker host to Cloudflare’s edge using `CLOUDFLARE_TUNNEL_TOKEN`. Public Hostnames in Cloudflare must route to `https://router:443`.
- **Keycloak (`auth`)**: Identity provider at `https://auth.${DOMAIN}`. Realm exports in `keycloak-import/`. Clients include `open-webui` and `router-forward-auth`.
- **Forward-auth (`router-forward-auth`)**: Middleware target `traefik-forward-auth@file`. Env requires OIDC provider URL, client id/secret, encryption/signing keys, `AUTH_HOST`, and `COOKIE_DOMAIN`.
- **Open WebUI (`open-webui`)**: Example OIDC app at `AI_FQDN`. OAuth values in `ai/local.env`.


## Networks
- **`proxy` (external)**: Traefik, `cloudflared`, and any exposed app join this.
- **`core_lan` (external macvlan)**: Optional LAN IP for Traefik, name `core_lan` (default IP `192.168.8.241`).


## Project file structure
```
./
├─ README.md               # Human guide (read this first)
├─ AGENTS.md               # This quick reference
├─ Makefile                # Commands (uses 1Password op run by default)
├─ core/
│  ├─ docker-compose.yml   # Traefik, Keycloak, DB, cloudflared, forward-auth
│  ├─ local.env            # Core env (domain, ACME, CF tokens, Keycloak, forward-auth)
│  └─ config/
│     └─ traefik/
│        ├─ traefik.yml                # entrypoints, providers, ACME
│        └─ dynamic/
│           └─ forward-auth.yml        # traefik-forward-auth middleware
├─ ai/
│  ├─ docker-compose.yml   # Open WebUI (OIDC-enabled)
│  └─ local.env            # Open WebUI env (AI_FQDN, OIDC client, etc.)
├─ keycloak-import/        # Realm JSON (import with make)
├─ keycloak-export/        # Exports written here (via make)
└─ cf_zta_tunnel_1.png     # Diagram (optional)
```


## Environment variables (essentials)
- **Core**: `DOMAIN`, `ACME_EMAIL`, `CLOUDFLARE_DNS_API_TOKEN`, `CLOUDFLARE_TUNNEL_TOKEN`, `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `KC_DB`, `KC_DB_USERNAME`, `KC_DB_PASSWORD`, `KC_DB_URL`, `MARIADB_PASSWORD`, `MARIADB_ROOT_PASSWORD`, `TFA_PROVIDER_URI`, `ROUTER_FORWARD_AUTH_CLIENT_ID`, `ROUTER_FORWARD_AUTH_CLIENT_SECRET`, `ROUTER_FORWARD_AUTH_ENCRYPTION_KEY`, `ROUTER_FORWARD_AUTH_SECRET`.
- **AI**: `AI_FQDN`, `OPENID_PROVIDER_URL`, `OAUTH_CLIENT_ID`, `OAUTH_CLIENT_SECRET`, plus optional Open WebUI settings.
- Secrets are injected via 1Password CLI: `op run --env-file=...` (see Makefile). Replace with your secret manager if needed.


## Traefik quick refs
- **EntryPoints**: `web` (80 → redirect) and `websecure` (443)
- **Providers**: Docker (`exposedByDefault=false`, `network=proxy`), File (`/etc/traefik/dynamic`)
- **ACME**: resolver `cf` using Cloudflare DNS challenge; storage `/letsencrypt/acme.json`
- **Forward-auth**: `traefik-forward-auth@file` → `http://router-forward-auth:4181/`


## Cloudflare Zero Trust (ZTA) quick refs
- In your Tunnel, add Public Hostnames:
  - `router.${DOMAIN}` → `https://router:443`
  - `auth.${DOMAIN}` → `https://router:443`
  - `ai.${DOMAIN}` (or `AI_FQDN`) → `https://router:443`
- `cloudflared` resolves `router` via Docker DNS on `proxy`.


## Example labels
### App with native OIDC/SAML
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`app.${DOMAIN}`)"
  - "traefik.http.routers.app.entrypoints=websecure"
  - "traefik.http.routers.app.tls.certresolver=cf"
  - "traefik.http.services.app.loadbalancer.server.port=8080"
  - "traefik.docker.network=proxy"
```

### App protected via forward-auth
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.secured.rule=Host(`secure.${DOMAIN}`)"
  - "traefik.http.routers.secured.entrypoints=websecure"
  - "traefik.http.routers.secured.tls.certresolver=cf"
  - "traefik.http.routers.secured.middlewares=traefik-forward-auth@file"
  - "traefik.http.services.secured.loadbalancer.server.port=8096"
  - "traefik.docker.network=proxy"
# If you add path constraints, include /_oauth too
# - "traefik.http.routers.secured.rule=Host(`secure.${DOMAIN}`) && (PathPrefix(`/`) || PathPrefix(`/_oauth`))"
```


## Makefile commands
```bash
make network        # create external 'proxy' network
make lan-net        # create external 'core_lan' macvlan
make shim           # optional host shim iface for macvlan

make core-up        # start core stack with env injection via op run
make core-down
make ai-up          # start AI stack
make ai-down
make up             # start both
make down           # stop both
make restart

make logs-core | cat
make logs-ai   | cat

make auth-stop
make auth-start
make auth-export
make auth-import
make auth-migrate
```


## Operational checklist (fast)
- **DNS/Tunnel**: Domain on Cloudflare; create Tunnel; add Public Hostnames → `https://router:443`.
- **Networks**: Ensure `proxy` exists; services joined; `traefik.docker.network=proxy` label set.
- **TLS**: `ACME_EMAIL` and `CLOUDFLARE_DNS_API_TOKEN` present; certresolver `cf` on routers.
- **Auth**: For forward‑auth, set `AUTH_HOST=router.${DOMAIN}` and `COOKIE_DOMAIN=.${DOMAIN}`; include `/_oauth` in router rules when using path filters.


## Gotchas
- **Login loop**: Usually cookie domain mismatch; set `COOKIE_DOMAIN` to a parent domain and keep `AUTH_HOST` consistent.
- **Cloudflare 502/522**: Tunnel unhealthy or Public Hostnames not pointing to `https://router:443`.
- **ACME errors**: Check Cloudflare DNS API token scope and zone.


— If you need intent, rationale, or a gentle walkthrough, go to `README.md`. This file assumes context and focuses on exact paths, switches, and labels.
