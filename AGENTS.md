### Quick reference for AI agents and power users

Read `README.md` first. This is a reference, not a tutorial.

## Components at a glance
- **Pangolin (managed self‑hosted)**: Edge ingress, TLS, HA
- **Newt**: Local agent, Docker autodiscovery via Blueprints labels
- **Keycloak (`auth`)**: Identity provider at `https://auth.${DOMAIN}`; realms in `keycloak-import/`

## Networks
- **`core_lan` (external macvlan)**: Optional LAN IP for host access (if needed)

## File structure
```
./
├─ README.md
├─ AGENTS.md                     # This file
├─ Makefile
├─ core/
│  ├─ docker-compose.yml         # Newt, Keycloak, DB
│  ├─ config.env                 # Non-secret config
│  ├─ secrets/                   # One-file-per-secret (git-ignored)
├─ keycloak-import/              # git-ignored
└─ keycloak-export/              # git-ignored
```

## Environment & secrets
- **Core config** (`core/config.env`): `COMPOSE_PROJECT_NAME`, `DOMAIN`, `KC_DB`, `KC_DB_USERNAME`, `KC_DB_URL`, `PANGOLIN_ENDPOINT`
- **Core secrets** (`core/secrets/`): `KEYCLOAK_ADMIN_PASSWORD.env`, `DB_PASSWORD.env`, `MARIADB_ROOT_PASSWORD`, `NEWT_ID.env`, `NEWT_SECRET.env`
- Generate secrets: `make inject-secrets` (uses 1Password CLI)

## Pangolin quick refs
- **Blueprints**: Use `pangolin.proxy-resources.<name>.*` labels for HTTP(S) apps
- **Targets**: `targets[0].port` defaults to first container port; set explicitly if needed

## Newt quick refs
- Env: `PANGOLIN_ENDPOINT`, `NEWT_ID`, `NEWT_SECRET`
- Mount: `/var/run/docker.sock:ro`

## Example labels
### App with Pangolin proxy

```yaml
labels:
  - "pangolin.proxy-resources.app.name=My App"
  - "pangolin.proxy-resources.app.protocol=http"
  - "pangolin.proxy-resources.app.full-domain=app.${DOMAIN}"
  - "pangolin.proxy-resources.app.targets[0].enabled=true"
  - "pangolin.proxy-resources.app.targets[0].port=8080"
```

### Client resource example (Olm)

```yaml
labels:
  - "pangolin.client-resources.ssh.name=SSH"
  - "pangolin.client-resources.ssh.protocol=tcp"
  - "pangolin.client-resources.ssh.targets[0].enabled=true"
  - "pangolin.client-resources.ssh.targets[0].port=22"
```

## Makefile commands

```bash
make inject-secrets # generate secrets.env from templates via 1Password CLI
make check-secrets  # verify secrets.env files exist

make lan-net        # create external 'core_lan' macvlan
make shim           # optional host shim iface for macvlan

make core-up        # start core stack (checks secrets first)
make core-down
make up             # start core
make down           # stop core
make restart

make logs-core | cat

make auth-stop
make auth-start
make auth-export
make auth-import
make auth-migrate
```
## Deployment
- **Local**: `make inject-secrets && make up`
- **Remote (SSH context)**: `docker context create remote --docker "host=ssh://user@host" && docker context use remote && make up`
  - Note: bind-mount host paths resolve on the remote host. Ensure required files/dirs exist there. Named volumes are managed by the remote engine.
