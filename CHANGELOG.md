# Changelog

История значимых изменений skeleton. Проекты ориентируются на неё при обновлении из
upstream (см. [docs/UPGRADING.md](docs/UPGRADING.md)). Формат — по релизным тегам.

## [0.0.2] — 2026-05-29

### Fixed

- `make init-backend`: `composer create-project` и `composer require filament/filament`
  обёрнуты в ретрай (до 3 попыток) — лечит транзиентный флак параллельной распаковки
  composer на macOS bind-mount (`Failed to open directory …`), из-за которого ранее
  не доезжал `filament:install`.

## [0.0.1] — 2026-05-29

Первичная оболочка (Model B): инфраструктура, мультипроектность, инициализация
приложений по команде, CI/CD и документация.

### Added

- Docker-окружение: nginx, php-fpm 8.4, Node 26, PostgreSQL 17, Redis 7, queue, scheduler.
- Мультипроектность: общий reverse-proxy Traefik, маршрутизация по `*.localhost`,
  эфемерные порты БД/Redis (параллельный запуск нескольких проектов).
- **Model B — каркасы по требованию**: `backend/`/`frontend/` пустые; `make init`
  (`init-backend`/`init-frontend`) создаёт Laravel 13 + Filament 4 и Next.js 16,
  подключает окружение (postgres/redis, локаль `ru`, `output: 'standalone'`).
  Повторный запуск ставит зависимости. Шаблоны — в `stubs/`.
- `Makefile` (init/up/down/proxy/ports/prod-*/…), `.env.example`,
  `compose.override.example.yaml`.
- Боевой деплой: `compose.prod.yaml` (production-стейджи: php no-dev+OPcache,
  Next standalone, nginx-edge с вшитым `public/`), `.env.prod.example`, `.dockerignore`.
- CI/CD: `.github/workflows/ci.yml` (scaffold-или-install → тест/линт/сборка),
  `release.yml` (публикация образов в GHCR по тегу `v*`).
- Документация: README, `docs/{architecture,getting-started,development,UPGRADING,deployment}`;
  `CLAUDE.md` по слоям; механизм обновления из upstream + граница skeleton/package-core.
