# Project names
CORE_PROJECT=core
IPTV_PROJECT=iptv
IMMICH_PROJECT=immich
MEDIA_PROJECT=media

# Compose files
CORE_COMPOSE=core/docker-compose.yml
IPTV_COMPOSE=iptv/docker-compose.yml
IMMICH_COMPOSE=immich/docker-compose.yml
MEDIA_COMPOSE=media/docker-compose.yml

# Paths
DOCKER_CONTEXT=$(shell docker context show)
CORE_PROJECT_DIR=$(shell pwd)/core

# Export all variables from config.env for docker compose interpolation
include core/config.env
export

.PHONY: inject-secrets check-secrets sync-secrets core-up core-down up down restart logs-core auth-up auth-stop auth-start auth-restart auth-export auth-import auth-migrate ldap-stop ldap-start ldap-restart logs-ldap logs-newt newt-stop newt-start newt-restart ldap-test homepage-up homepage-stop homepage-start homepage-restart logs-homepage iptv-up iptv-down iptv-restart logs-iptv immich-up immich-down immich-restart logs-immich media-up media-down media-restart logs-media jellyfin-stop jellyfin-start jellyfin-restart radarr-stop radarr-start radarr-restart sonarr-stop sonarr-start sonarr-restart nzbget-stop nzbget-start nzbget-restart seerr-stop seerr-start seerr-restart

inject-secrets:
	@echo "Injecting secrets from 1Password..."
	@mkdir -p core/secrets
	@op read "op://Develop/Keycloak Admin/password" > core/secrets/KEYCLOAK_ADMIN_PASSWORD.env
	@op read "op://Develop/Keycloak DB/password" > core/secrets/DB_PASSWORD.env
	@op read "op://Develop/Keycloak Admin/password" > core/secrets/MARIADB_ROOT_PASSWORD
	@op read "op://Develop/LDAP/admin password" > core/secrets/LDAP_ADMIN_PASSWORD
	@op read "op://Develop/Pangolin/newt id" > core/secrets/NEWT_ID.env
	@op read "op://Develop/Pangolin/newt secret" > core/secrets/NEWT_SECRET.env
	@echo "Secrets injected successfully!"
	@echo "Note: core/secrets/* files are git-ignored and should not be committed"

check-secrets:
	@if [ ! -f core/secrets/KEYCLOAK_ADMIN_PASSWORD.env ]; then \
		echo "ERROR: core/secrets/KEYCLOAK_ADMIN_PASSWORD not found!"; \
		echo "Run 'make inject-secrets' first to generate secrets"; \
		exit 1; \
	fi
	@if [ ! -f core/secrets/DB_PASSWORD.env ]; then \
		echo "ERROR: core/secrets/DB_PASSWORD not found!"; \
		echo "Run 'make inject-secrets' first to generate secrets"; \
		exit 1; \
	fi
	@if [ ! -f core/secrets/MARIADB_ROOT_PASSWORD ]; then \
		echo "ERROR: core/secrets/MARIADB_ROOT_PASSWORD not found!"; \
		echo "Run 'make inject-secrets' first to generate secrets"; \
		exit 1; \
	fi
	@if [ ! -f core/secrets/LDAP_ADMIN_PASSWORD ]; then \
		echo "ERROR: core/secrets/LDAP_ADMIN_PASSWORD not found!"; \
		echo "Run 'make inject-secrets' first to generate secrets"; \
		exit 1; \
	fi
	@if [ ! -f core/secrets/NEWT_ID.env ]; then \
		echo "ERROR: core/secrets/NEWT_ID not found!"; \
		echo "Run 'make inject-secrets' first to generate secrets"; \
		exit 1; \
	fi
	@if [ ! -f core/secrets/NEWT_SECRET.env ]; then \
		echo "ERROR: core/secrets/NEWT_SECRET not found!"; \
		echo "Run 'make inject-secrets' first to generate secrets"; \
		exit 1; \
	fi
	@echo "All secrets files present"

sync-secrets: check-secrets
	@if [ "$(DOCKER_CONTEXT)" != "default" ]; then \
		echo "Syncing secrets to remote context: $(DOCKER_CONTEXT)"; \
		DOCKER_HOST=$$(docker context inspect $(DOCKER_CONTEXT) -f '{{.Endpoints.docker.Host}}' | sed 's|^ssh://||'); \
		rsync -avz --relative core/secrets core/config.env core/keycloak-providers core/secrets2env.sh keycloak-import/ $${DOCKER_HOST}:~/docker/; \
		echo "Secrets synced to remote host"; \
	else \
		echo "Using local context, no sync needed"; \
	fi

core-up: check-secrets sync-secrets
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) up -d

core-down:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) down

up: core-up
	echo "Stacks started"

down: core-down
	echo "Stacks stopped"

restart: down up

logs-core:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) logs -f | cat

auth-up:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) up -d auth

auth-stop:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) stop auth

auth-start:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) start auth

auth-restart: auth-stop auth-up

auth-export: auth-stop check-secrets
	mkdir -p ./keycloak-export
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) run --rm --no-deps \
		-v ./keycloak-export:/opt/keycloak/data/export \
		auth export \
		--dir /opt/keycloak/data/export \
		--users realm_file

auth-transfer-export:
	mkdir -p ./keycloak-export
	mkdir -p ./keycloak-import
	cp -r ./keycloak-export/* ./keycloak-import/

auth-import: auth-stop check-secrets
	mkdir -p ./keycloak-import
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) run --rm --no-deps \
		-v ./keycloak-import:/opt/keycloak/data/import \
		auth import \
		--dir /opt/keycloak/data/import

auth-migrate: auth-export auth-transfer-export auth-import

ldap-stop:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) stop ldap

ldap-start:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) start ldap

ldap-restart: ldap-stop ldap-start

logs-ldap:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) logs -f ldap | cat

logs-newt:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) logs --tail 20 newt | cat

newt-stop:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) stop newt

newt-start:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) start newt

newt-restart: newt-stop newt-start

ldap-test:
	@echo "=== Testing LDAP connection ==="
	@LDAP_PASSWORD=$$(cat core/secrets/LDAP_ADMIN_PASSWORD); \
	BASE_DN="dc=$${DOMAIN//./,dc=}"; \
	docker exec ldap ldapsearch -x -H ldap://localhost:389 \
		-b "$$BASE_DN" \
		-D "cn=admin,$$BASE_DN" \
		-w "$$LDAP_PASSWORD" 2>&1 | grep -E "(^dn:|^result:|Success)" || \
		(echo "✗ LDAP test failed" && exit 1)
	@echo "✓ LDAP connection successful"

homepage-up:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) up -d --build homepage

homepage-stop:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) stop homepage

homepage-start:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) start homepage

homepage-restart: homepage-stop homepage-up

logs-homepage:
	docker compose -p $(CORE_PROJECT) --project-directory $(CORE_PROJECT_DIR) -f $(CORE_COMPOSE) logs -f homepage | cat

iptv-up:
	docker compose -p $(IPTV_PROJECT) -f $(IPTV_COMPOSE) up -d

iptv-down:
	docker compose -p $(IPTV_PROJECT) -f $(IPTV_COMPOSE) down

iptv-restart: iptv-down iptv-up

logs-iptv:
	docker compose -p $(IPTV_PROJECT) -f $(IPTV_COMPOSE) logs -f | cat

immich-up:
	docker compose -p $(IMMICH_PROJECT) -f $(IMMICH_COMPOSE) up -d

immich-down:
	docker compose -p $(IMMICH_PROJECT) -f $(IMMICH_COMPOSE) down

immich-restart: immich-down immich-up

logs-immich:
	docker compose -p $(IMMICH_PROJECT) -f $(IMMICH_COMPOSE) logs -f | cat

media-up:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) up -d

media-down:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) down

media-restart: media-down media-up

logs-media:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) logs -f | cat

jellyfin-stop:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) stop jellyfin

jellyfin-start:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) start jellyfin

jellyfin-restart: jellyfin-stop jellyfin-start

radarr-stop:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) stop radarr

radarr-start:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) start radarr

radarr-restart: radarr-stop radarr-start

sonarr-stop:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) stop sonarr

sonarr-start:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) start sonarr

sonarr-restart: sonarr-stop sonarr-start

nzbget-stop:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) stop nzbget

nzbget-start:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) start nzbget

nzbget-restart: nzbget-stop nzbget-start

seerr-stop:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) stop seerr

seerr-start:
	docker compose -p $(MEDIA_PROJECT) -f $(MEDIA_COMPOSE) start seerr

seerr-restart: seerr-stop seerr-start
