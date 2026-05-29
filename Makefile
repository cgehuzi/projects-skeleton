# ──────────────────────────────────────────────────────────────────────────────
# Makefile — единая точка управления окружением проекта.
# Требуется только Docker. `make` без аргументов покажет справку.
#
# Skeleton поставляется с ПУСТЫМИ backend/ и frontend/. `make init` создаёт в них
# каркасы (Laravel+Filament, Next.js) при первом запуске; на повторных — ставит
# зависимости. Архитектурная начинка подключается отдельно (зависимость package-core).
# ──────────────────────────────────────────────────────────────────────────────

DC := docker compose
PHP := $(DC) exec php
NODE := $(DC) exec node
# Одноразовый запуск контейнера до поднятого стека (scaffold/install).
PHP_RUN := $(DC) run --rm --no-deps php
NODE_RUN := $(DC) run --rm --no-deps node

# Репозиторий релизов package-core (редко меняется; при нужде: make ... CORE_REPO=org/repo).
CORE_REPO ?= cgehuzi/package-core

.DEFAULT_GOAL := help

# ── Справка ─────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Показать список команд
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ── Жизненный цикл окружения ──────────────────────────────────────────────────
.PHONY: init
init: ## Полная инициализация: .env, proxy, образы, каркасы приложений, запуск
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		name=$$(basename "$$PWD" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | sed -e 's/^-*//' -e 's/-*$$//'); \
		sed -i.bak "s/^COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=$$name/" .env; \
		sed -i.bak "s/^PROJECT_DOMAIN=.*/PROJECT_DOMAIN=$$name/" .env; \
		sed -i.bak "s/^UID=.*/UID=$$(id -u)/" .env; \
		sed -i.bak "s/^GID=.*/GID=$$(id -g)/" .env; \
		rm -f .env.bak; \
		echo "✓ .env создан (проект: $$name)"; \
	fi
	$(MAKE) proxy-up
	$(MAKE) build
	$(MAKE) init-backend
	$(MAKE) init-frontend
	$(MAKE) up
	$(MAKE) migrate
	@domain=$$(grep '^PROJECT_DOMAIN=' .env | cut -d= -f2); \
		printf "\n✓ Готово.\n  Сайт:  http://%s.localhost\n  Admin: http://api.%s.localhost/admin\n" "$$domain" "$$domain"

.PHONY: build
build: ## Собрать Docker-образы
	$(DC) build

.PHONY: up
up: proxy-network ## Поднять стек в фоне
	$(DC) up -d

.PHONY: down
down: ## Остановить и удалить контейнеры
	$(DC) down

.PHONY: restart
restart: ## Перезапустить стек
	$(MAKE) down
	$(MAKE) up

.PHONY: ps
ps: ## Статус контейнеров
	$(DC) ps

.PHONY: logs
logs: ## Логи всех сервисов (follow)
	$(DC) logs -f

# ── Инициализация приложений (Model B: создаём каркасы по требованию) ──────────
.PHONY: init-backend
init-backend: ## Создать Laravel+Filament в backend/ (или поставить зависимости)
	@if [ -f backend/composer.json ]; then \
		echo "→ backend уже создан, ставлю зависимости"; \
		$(PHP_RUN) composer install --no-interaction; \
		if [ ! -f backend/.env ] && [ -f backend/.env.example ]; then \
			cp backend/.env.example backend/.env; \
			$(PHP_RUN) php artisan key:generate; \
		fi; \
	else \
		echo "→ создаю Laravel + Filament в backend/"; \
		rm -f backend/.gitkeep; \
		ok=0; for i in 1 2 3; do \
			$(PHP_RUN) composer create-project laravel/laravel . --prefer-dist --no-interaction && { ok=1; break; }; \
			echo "⚠ create-project упал (попытка $$i) — чищу backend/ и повторяю…"; \
			find backend -mindepth 1 -exec rm -rf {} + 2>/dev/null || true; sleep 3; \
		done; [ "$$ok" = 1 ] || { echo "✗ create-project не удался"; exit 1; }; \
		ok=0; for i in 1 2 3; do \
			$(PHP_RUN) composer require filament/filament:^4.0 -W --no-interaction && { ok=1; break; }; \
			echo "⚠ composer require filament упал (попытка $$i) — повтор (флак параллельной распаковки на bind-mount)…"; sleep 3; \
		done; [ "$$ok" = 1 ] || { echo "✗ Filament не установился"; exit 1; }; \
		$(PHP_RUN) php artisan filament:install --panels --no-interaction; \
		domain=$$(grep '^PROJECT_DOMAIN=' .env | cut -d= -f2); \
		db=$$(grep '^DB_DATABASE=' .env | cut -d= -f2); \
		dbu=$$(grep '^DB_USERNAME=' .env | cut -d= -f2); \
		dbp=$$(grep '^DB_PASSWORD=' .env | cut -d= -f2); \
		sed -i.bak \
			-e "s#^APP_URL=.*#APP_URL=http://api.$$domain.localhost#" \
			-e 's/^APP_LOCALE=.*/APP_LOCALE=ru/' \
			-e 's/^APP_FALLBACK_LOCALE=.*/APP_FALLBACK_LOCALE=ru/' \
			-e 's/^DB_CONNECTION=.*/DB_CONNECTION=pgsql/' \
			-e 's/^SESSION_DRIVER=.*/SESSION_DRIVER=redis/' \
			-e 's/^CACHE_STORE=.*/CACHE_STORE=redis/' \
			-e 's/^QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/' \
			-e 's/^REDIS_HOST=.*/REDIS_HOST=redis/' \
			backend/.env; \
		rm -f backend/.env.bak; \
		printf 'DB_HOST=postgres\nDB_PORT=5432\nDB_DATABASE=%s\nDB_USERNAME=%s\nDB_PASSWORD=%s\n' "$$db" "$$dbu" "$$dbp" >> backend/.env; \
		$(PHP_RUN) php artisan key:generate; \
		echo "✓ backend создан (Laravel + Filament, окружение подключено к postgres/redis)"; \
	fi

.PHONY: init-frontend
init-frontend: ## Создать Next.js в frontend/ (или поставить зависимости)
	@if [ -f frontend/package.json ]; then \
		echo "→ frontend уже создан, ставлю зависимости"; \
		$(NODE_RUN) npm ci; \
	else \
		echo "→ создаю Next.js в frontend/"; \
		rm -f frontend/.gitkeep; \
		$(NODE_RUN) npx --yes create-next-app@latest . --ts --app --eslint --tailwind --no-src-dir --import-alias "@/*" --use-npm --yes; \
		cp stubs/next.config.ts frontend/next.config.ts; \
		echo "✓ frontend создан (Next.js, output: standalone)"; \
	fi

# ── Ядро (package-core): установка из релиза или живой линк ───────────────────
# Проводку (CorePlugin в AdminPanelProvider + catch-all) делаем вручную по README пакетов.
.PHONY: core-install
core-install: ## Установить package-core из GitHub-релиза: make core-install VERSION=0.0.1
	@[ -n "$(VERSION)" ] || { echo "✗ укажите версию: make core-install VERSION=X.Y.Z"; exit 1; }
	@repo="$(CORE_REPO)"; v="$(VERSION)"; tag="v$$v"; \
	disturl="https://github.com/$$repo/releases/download/$$tag/core-backend-$$tag.tar.gz"; \
	echo "→ core-backend $$tag: беру манифест пакета из репозитория, ставлю из релиза"; \
	curl -fsSL "https://raw.githubusercontent.com/$$repo/$$tag/backend/composer.json" -o backend/.core-src.json \
		|| { echo "✗ не удалось получить composer.json пакета ($$repo@$$tag)"; exit 1; }; \
	$(PHP_RUN) php -r '$$p=json_decode(file_get_contents(".core-src.json"),true); unset($$p["require-dev"],$$p["autoload-dev"],$$p["config"],$$p["scripts"],$$p["minimum-stability"],$$p["prefer-stable"]); $$p["version"]=$$argv[1]; $$p["dist"]=["url"=>$$argv[2],"type"=>"tar"]; file_put_contents(".core-repo.json", json_encode(["type"=>"package","package"=>$$p], JSON_UNESCAPED_SLASHES));' "$$v" "$$disturl"; \
	$(PHP_RUN) sh -c 'composer config repositories.cgehuzi-core-backend --json "$$(cat .core-repo.json)"'; \
	rm -f backend/.core-src.json backend/.core-repo.json; \
	$(PHP_RUN) composer require "cgehuzi/core-backend:$$v" --no-interaction; \
	echo "→ core-frontend $$tag (npm, релиз)"; \
	$(NODE_RUN) npm install "https://github.com/$$repo/releases/download/$$tag/core-frontend-$$tag.tgz"; \
	echo "✓ package-core $$tag установлен."; \
	echo "  Доделать вручную: CorePlugin в AdminPanelProvider + тонкий catch-all (см. README пакетов)."

.PHONY: core-link
core-link: ## Живой линк локального package-core (CORE_PATH в .env) для дебага пакетов
	@if [ -f compose.override.yaml ] && ! grep -q 'managed-by: make core-link' compose.override.yaml; then \
		echo "✗ compose.override.yaml уже есть и не управляется core-link — слейте/уберите вручную"; exit 1; \
	fi
	cp stubs/compose.core-link.yaml compose.override.yaml
	$(MAKE) up
	@echo "→ core-backend: composer path-repo (живой symlink)"; \
	$(PHP_RUN) composer config repositories.cgehuzi-core-backend '{"type":"path","url":"/packages/core/backend","options":{"symlink":true}}'; \
	$(PHP_RUN) composer require "cgehuzi/core-backend:*" --no-interaction; \
	echo "✓ package-core залинкован вживую: backend — symlink, frontend — bind-mount в node_modules."; \
	echo "  Правки в CORE_PATH видны сразу. Проводка (CorePlugin + catch-all) — вручную."

.PHONY: core-unlink
core-unlink: ## Снять живой линк package-core (вернуть к чистому стеку)
	@if [ -f backend/composer.json ]; then \
		$(PHP_RUN) composer remove cgehuzi/core-backend --no-interaction || true; \
		$(PHP_RUN) composer config --unset repositories.cgehuzi-core-backend || true; \
	fi
	@rm -f compose.override.yaml
	$(MAKE) up
	@echo "✓ линк снят (mount и composer-зависимость удалены)."

# ── Общий reverse-proxy (Traefik), один на машину ─────────────────────────────
.PHONY: proxy-network
proxy-network:
	@docker network inspect proxy >/dev/null 2>&1 || docker network create proxy

.PHONY: proxy-up
proxy-up: proxy-network ## Поднять общий reverse-proxy (Traefik)
	docker compose -f docker/proxy/compose.yaml up -d

.PHONY: proxy-down
proxy-down: ## Остановить общий reverse-proxy
	docker compose -f docker/proxy/compose.yaml down

.PHONY: ports
ports: ## Показать опубликованные на хост порты БД/Redis
	@echo "postgres: $$($(DC) port postgres 5432 2>/dev/null || echo '—')"
	@echo "redis:    $$($(DC) port redis 6379 2>/dev/null || echo '—')"

# ── Шеллы ─────────────────────────────────────────────────────────────────────
.PHONY: sh-php
sh-php: ## Bash внутри php-контейнера
	$(PHP) bash

.PHONY: sh-node
sh-node: ## Sh внутри node-контейнера
	$(NODE) sh

.PHONY: sh-db
sh-db: ## psql внутри postgres
	$(DC) exec postgres psql -U $${DB_USERNAME:-app} -d $${DB_DATABASE:-app}

# ── Laravel ───────────────────────────────────────────────────────────────────
.PHONY: artisan
artisan: ## Произвольная artisan-команда: make artisan cmd="migrate --seed"
	$(PHP) php artisan $(cmd)

.PHONY: migrate
migrate: ## Прогнать миграции
	$(PHP) php artisan migrate

.PHONY: fresh
fresh: ## Пересоздать БД с сидерами
	$(PHP) php artisan migrate:fresh --seed

.PHONY: test
test: ## Тесты backend (PHPUnit)
	$(PHP) php artisan test

# ── Frontend ──────────────────────────────────────────────────────────────────
.PHONY: npm
npm: ## Произвольная npm-команда: make npm cmd="run lint"
	$(NODE) npm $(cmd)

# ── Production (локальная проверка боевого стека; нужен .env.prod) ─────────────
DC_PROD := docker compose -f compose.prod.yaml --env-file .env.prod

.PHONY: prod-build
prod-build: ## Собрать боевые образы
	$(DC_PROD) build

.PHONY: prod-up
prod-up: ## Поднять боевой стек
	$(DC_PROD) up -d

.PHONY: prod-down
prod-down: ## Остановить боевой стек
	$(DC_PROD) down

.PHONY: prod-migrate
prod-migrate: ## Миграции на боевом стеке
	$(DC_PROD) run --rm php php artisan migrate --force
