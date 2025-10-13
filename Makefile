export COMPOSE_PROJECT_NAME ?= media
CORE_COMPOSE=core/docker-compose.yml

.PHONY: inject-secrets check-secrets core-up core-down up down restart logs-core auth-stop auth-start auth-export auth-import auth-migrate

inject-secrets:
	@echo "Injecting secrets from 1Password..."
	@mkdir -p core/secrets
	@op read "op://Develop/Keycloak Admin/password" > core/secrets/KEYCLOAK_ADMIN_PASSWORD.env
	@op read "op://Develop/Keycloak DB/password" > core/secrets/DB_PASSWORD.env
	@op read "op://Develop/Keycloak Admin/password" > core/secrets/MARIADB_ROOT_PASSWORD
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

core-up: check-secrets
	docker compose -f $(CORE_COMPOSE) up -d

core-down:
	docker compose -f $(CORE_COMPOSE) down

up: core-up
	echo "Stacks started"

down: core-down
	echo "Stacks stopped"

restart: down up

logs-core:
	docker compose -f $(CORE_COMPOSE) logs -f | cat

auth-stop:
	docker compose -f $(CORE_COMPOSE) stop auth

auth-start:
	docker compose -f $(CORE_COMPOSE) start auth

auth-export: auth-stop check-secrets
	mkdir -p ./keycloak-export
	docker compose -f $(CORE_COMPOSE) run --rm --no-deps \
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
	docker compose -f $(CORE_COMPOSE) run --rm --no-deps \
		-v ./keycloak-import:/opt/keycloak/data/import \
		auth import \
		--dir /opt/keycloak/data/import

auth-migrate: auth-export auth-transfer-export auth-import
