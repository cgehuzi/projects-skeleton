# Changelog

История значимых изменений skeleton. Проекты ориентируются на неё при обновлении из
upstream (см. [docs/UPGRADING.md](docs/UPGRADING.md)). Формат — по релизным тегам.

## [Unreleased]

### Removed

- `release.yml`: удалён. Релизы skeleton создаются вручную на GitHub (тег + заметки).
  Workflow собирал прод-образы и падал — в шаблоне приложения нет (Model B). Сборку/
  публикацию прод-образов выполняет проект (шаблон workflow — в `docs/deployment.md`).

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
- Установка ядра `package-core`: `make core-install VERSION=X.Y.Z` (из GitHub-релиза;
  composer-манифест берётся из самого пакета по тегу, без дублирования), `make core-link`
  (живой линк локального `CORE_PATH`: backend — symlink, frontend — bind-mount в
  node_modules), `make core-unlink`.
- `Makefile` (init/up/down/proxy/ports/core-*/prod-*/…), `.env.example`,
  `compose.override.example.yaml`.
- Боевой деплой: `compose.prod.yaml` (production-стейджи: php no-dev+OPcache,
  Next standalone, nginx-edge с вшитым `public/`), `.env.prod.example`, `.dockerignore`.
- CI: `.github/workflows/ci.yml` (scaffold-или-install → тест/линт/сборка).
- Документация: README, `docs/{architecture,getting-started,development,UPGRADING,deployment}`;
  `CLAUDE.md` по слоям; механизм обновления из upstream + граница skeleton/package-core.
