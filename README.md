### Share your self-hosted apps safely, with single sign‑on

This stack lets you share apps running at home without opening router ports or exposing your home IP. Your users just visit a URL in their browser. You get HTTPS and single sign‑on (SSO). Apps that already support SSO can plug into your identity provider; apps that don’t can still sit behind a login screen.

You can also layer in a VPN (Tailscale or NetBird) later if you need direct network access.


## What’s inside (at a glance)
- A reverse proxy (Traefik) that routes requests to your containers
- A secure front door on the internet (Cloudflare Tunnel) so you don’t need port forwarding
- An identity provider (Keycloak) for SSO
- A helper (forward‑auth) to protect apps that don’t support SSO
- An example app (Open WebUI) already wired for SSO


## How it works (one minute)
- Your DNS is on Cloudflare. Public requests for your app go to Cloudflare.
- Cloudflare sends those requests through a private tunnel to your Docker host.
- Traefik (the router) looks at the host name and forwards the request to the right container.
- If the app needs a login, Traefik asks Keycloak to handle it. Apps with built‑in SSO talk to Keycloak directly; apps without it are protected by forward‑auth.

No client software is required for your users. Everything is just HTTPS in a browser.


## Before you start
- Docker + Docker Compose v2 installed
- A domain on Cloudflare and access to Cloudflare Zero Trust (to create the tunnel)
- Willingness to set a few environment variables (secrets are injected with 1Password CLI in the provided Makefile, but you can use yours)


## Setup in 5 steps
1) Set your domain and secrets
- Open `core/local.env` and `ai/local.env`.
- Fill in the essentials: `DOMAIN`, `ACME_EMAIL`, `CLOUDFLARE_DNS_API_TOKEN`, `CLOUDFLARE_TUNNEL_TOKEN`.
- Add Keycloak admin and database values, plus the forward‑auth client and cookie keys.
- For Open WebUI, set `AI_FQDN`, `OPENID_PROVIDER_URL`, `OAUTH_CLIENT_ID`, `OAUTH_CLIENT_SECRET`.

2) Create the networks
```bash
make network   # creates the external 'proxy' network
make lan-net   # creates the external 'core_lan' macvlan (optional LAN IP for Traefik)
make shim      # optional: host shim interface for macvlan
```

3) Start the core stack
```bash
make core-up   # traefik, keycloak, db, cloudflared, forward-auth
```

4) Tell Cloudflare which hostnames to send to the tunnel
- In Cloudflare Zero Trust → your Tunnel → Public Hostnames, add:
  - `router.${DOMAIN}` → `https://router:443`
  - `auth.${DOMAIN}` → `https://router:443`
  - `ai.${DOMAIN}` (or your `AI_FQDN`) → `https://router:443`

5) (Optional) Start the AI stack
```bash
make ai-up
```

You should now reach:
- Traefik dashboard at `https://router.${DOMAIN}` (protected by login)
- Keycloak at `https://auth.${DOMAIN}`
- Open WebUI at `https://AI_FQDN`


## Add your first app
Attach your container to the `proxy` network and add Traefik labels. This example exposes an app on `app.${DOMAIN}` and forwards to its internal port 8080.

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`app.${DOMAIN}`)"
  - "traefik.http.routers.app.entrypoints=websecure"
  - "traefik.http.routers.app.tls.certresolver=cf"
  - "traefik.http.services.app.loadbalancer.server.port=8080"
  - "traefik.docker.network=proxy"
```

- If your app supports OIDC/SAML, configure it to use Keycloak at `https://auth.${DOMAIN}`.
- If it doesn’t, add the forward‑auth middleware:
```yaml
- "traefik.http.routers.app.middlewares=traefik-forward-auth@file"
```
If you also restrict by path, make sure your rule still includes `/_oauth` so the login callback can reach the middleware.


## Certificates and HTTPS
Traefik uses Cloudflare’s DNS challenge to get certificates automatically. You only need `ACME_EMAIL` and a `CLOUDFLARE_DNS_API_TOKEN` with DNS edit rights.


## Common issues (and quick checks)
- Can’t get a certificate: check DNS token and that your domain is on Cloudflare.
- Stuck in a login loop: set `COOKIE_DOMAIN` to `.yourdomain.tld` and keep `AUTH_HOST=router.${DOMAIN}`; ensure the router rule includes `/_oauth` if you restrict paths.
- Tunnel errors (502/522): confirm your Tunnel is healthy and Public Hostnames point to `https://router:443`.


## Where things live
- Core stack: `core/docker-compose.yml`
- AI stack: `ai/docker-compose.yml`
- Traefik config: `core/config/traefik/traefik.yml` and `core/config/traefik/dynamic/forward-auth.yml`
- Env files: `core/local.env`, `ai/local.env`
- Make commands: `Makefile`
- Keycloak realm exports: `keycloak-import/` (import with `make auth-import`)


## Want the deep dive?
See `AGENTS.md` for a compact, structured reference (service inventory, env variables, labels, command cheat sheet). It’s useful for power users and AI tools.


## VPN option (optional)
If you need direct network access (SMB, RDP, databases), add Tailscale or NetBird alongside this stack. You can keep using this reverse‑proxy + SSO flow for browser apps, and the VPN for the rest.
