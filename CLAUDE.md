# CLAUDE.md

Заметки для ИИ-ассистента и разработчиков по нюансам реализации этого скелета.
Здесь — то, что НЕ очевидно из кода. Базовое описание стека — в [README.md](README.md),
архитектурные решения — в [docs/architecture.md](docs/architecture.md).

## Сообщения коммитов

- Ассистент НЕ коммитит/тегает/пушит сам — только предлагает готовый текст commit message
  в конце куска работы; коммитит человек.
- Стиль: **Conventional Commits, на английском**. Допустимые типы:
  `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `build`.
- Заголовок ≤72 символов, повелительное наклонение; тело — пунктами «что/зачем».

## Назначение

`projects-skeleton` — стартовая точка новых проектов. Из него клонируются проекты,
которые затем подтягивают пакеты из `package-core` (отдельный репозиторий: composer/npm
модули, ставятся из GitHub-релизов, не из публичных реестров).

## Принципы

- **Docker-first.** На хосте нужен только Docker. Локальные PHP/Node не используются и
  не предполагаются. Любая команда идёт через контейнер (см. `Makefile`).
- **Один проект — один репозиторий.** `backend/` и `frontend/` живут вместе (моно).
- **Документ первичен коду.** Расхождение кода с `docs/architecture.md` — баг.

## Стек и версии (пин обязателен)

| Что     | Версия | Где пинуется                              |
| ------- | ------ | ----------------------------------------- |
| PHP     | 8.4    | `docker/php/Dockerfile` (`php:8.4-fpm-alpine`) |
| Laravel | 13     | `backend/composer.json` (create-project дал 13.x) |
| Filament| 4      | `backend/composer.json` (совместим с Laravel 13) |
| Node    | 26     | `docker/node/Dockerfile` (`node:26-alpine`) |
| Next.js | 16     | `frontend/package.json` (create-next-app дал 16.x) |
| Postgres| 17     | `compose.yaml`                            |
| Redis   | 7      | `compose.yaml`                            |
| Traefik | v3.6   | `docker/proxy/compose.yaml` (v3.3 несовместим с Docker 29) |

> Node 26 на 2026-05 — Current (LTS осенью 2026). Версию меняем только осознанно и в
> одном месте. Фолбэк при несовместимости экосистемы — Node 24 LTS.

## Docker: нюансы, на которых легко споткнуться

- **Много проектов параллельно через общий Traefik.** Проект НЕ публикует порт 80.
  Общий Traefik (`docker/proxy/`, один на машину, владеет `:80`) маршрутизирует по хосту:
  `<PROJECT_DOMAIN>.localhost` → Next, `api.<PROJECT_DOMAIN>.localhost` → nginx(Laravel).
  Контейнеры nginx/node подключены к внешней сети `proxy` и помечены лейблами `traefik.*`
  (имена роутеров префиксуются `${COMPOSE_PROJECT_NAME}`). `PROJECT_DOMAIN` и
  `COMPOSE_PROJECT_NAME` уникальны на машину (make init берёт имя каталога).
- **Внутренний хоп Next → API.** Server-side Next ходит в API по `http://api-internal/api`
  (env `INTERNAL_API_URL`). `api-internal` — это сетевой алиас nginx **только в сети `app`**
  (project-scoped). Имя `nginx` для этого НЕ используется: в общей сети `proxy` оно
  конфликтует между проектами (несколько контейнеров `nginx`). nginx — один default_server,
  принимает любой Host.
- **Порты БД/Redis — эфемерные.** В compose `ports: "127.0.0.1::5432"` → Docker сам выберет
  свободный порт на loopback, конфликтов между проектами нет. Узнать: `make ports`.
- **Traefik vs Docker 29.** `traefik:v3.3` падает с пустым `Error response from daemon` на
  Docker 29 (новый API). Лечится свежим образом — `traefik:v3.6`. Не откатывать ниже.
- **UID/GID маппинг.** Пользователь НЕ зашит в образ (иначе ловим `gid in use` на Alpine).
  php-сервисы запускаются через `user: "${UID}:${GID}"` в `compose.yaml` (якорь
  `x-php-common`) под хостовые UID/GID из `.env`. На macOS по умолчанию `501:20`. Без
  этого файлы из контейнера (миграции, кэш) были бы root на хосте. php-fpm стартует не от
  root, поэтому в `www.conf` нет директив `user`/`group`. Composer без home → `COMPOSER_HOME`
  и `HOME` заданы в окружении на writable-путь (`/tmp`).
- **node_modules / vendor не в образе (dev).** Код монтируется bind-mount'ом. Зависимости
  ставятся в смонтированные каталоги через `make install` (`composer install`, `npm ci`),
  а не пекутся в dev-образ. В prod-стейджах (`target: production`) — наоборот, всё внутри.
- **Node-контейнер: адаптивный entrypoint.** `docker/node/entrypoint.sh` создаёт юзера под
  `PUID/PGID` (нужна запись в `/etc/passwd`, иначе Node роняет `os.userInfo()` →
  падает create-next-app), затем: если каталог проекта писаем целевым юзером — `su-exec` под
  него (Linux), иначе остаётся root (macOS Docker Desktop сам мапит запись на хостового
  юзера). Поэтому у node НЕ ставим `user:` в compose, в отличие от php.
- **`/app` сделан writable в node-образе** (`chmod 0777 /app`): create-next-app проверяет
  права на родителя каталога проекта, а `/app` создан под root.
- **Две `.env`.** Корневой `.env` — для Docker Compose (имя проекта, домен, UID/GID, креды БД).
  `backend/.env` — для самого Laravel. Внутри сети: `DB_HOST=postgres`, `REDIS_HOST=redis`.
- **Makefile требует табы** в рецептах (не пробелы). `.editorconfig` это фиксирует.

### Грабли, на которые уже наступили (не повторять)

- **Bind-mount тома легко потерять при рефакторинге compose.** Симптом: инсталлятор пишет
  «Success», но на хосте каталог пуст — значит писал во внутренний слой образа, а не в
  `./frontend`. Проверять наличие `volumes:` у сервиса.
- **`addgroup -g 20` падает** (`gid in use`) — GID 20 занят в Alpine. Не создавать группу
  с фиксированным GID без проверки `getent`.
- **Пайп в `| tail` маскирует exit code** docker-команды (возвращается код `tail`).
  Для проверок запускать без пайпа.
- **Кэш Next (`.next/cache`) переживает рестарт.** При смене формата данных в dev можно
  получить устаревший рендер. Если залип: `rm -rf frontend/.next` + рестарт node.
- **Тесты бэкенда — PHPUnit, не Pest** (Laravel 13 create-project). Классы
  `extends Tests\TestCase`, никаких `uses()`/`test()`. `phpunit.xml` форсит sqlite `:memory:`.

## Каркасы приложений: Model B (создаются по требованию)

Skeleton поставляется с **пустыми** `backend/`/`frontend/` (только `.gitkeep`). Каркасы
создаёт `make init` (цели `init-backend` / `init-frontend`) — это не закоммичено в skeleton,
а генерируется в проекте при старте. Логика идемпотентна:

- если каталог пуст → **scaffold**; если уже есть `composer.json`/`package.json` →
  просто `composer install` / `npm ci` (для проекта, который уже закоммитил свой каркас).

Что делает scaffold:
- Backend: `composer create-project laravel/laravel .` → `composer require filament/filament`
  → `php artisan filament:install --panels` → правка `backend/.env` под docker-сервисы
  (`pgsql`/`postgres`, `redis`, локаль `ru`, `APP_URL`) → `key:generate`. Даёт Laravel 13.x +
  Filament 4 (пустая панель `/admin`).
- Frontend: `create-next-app . --ts --app --eslint --tailwind --no-src-dir
  --import-alias "@/*" --use-npm --yes` → копирование `stubs/next.config.ts`
  (`output: 'standalone'` для прод-образа). Даёт Next 16.x.

Нюансы:
- `make init` порядок: `.env` → `proxy-up` → `build` (образы) → `init-backend`/`init-frontend`
  (scaffold ДО `up`, т.к. сервисам нужен код) → `up` → `migrate`.
- create-next-app кладёт свой `frontend/CLAUDE.md`/`AGENTS.md` — это нормально.
- `FilamentUser` на модели `User` skeleton НЕ добавляет (доступ в админку в `local` есть и так;
  для prod/test — добавляет package-core). См. `_reference-phase3-slice/`.

## Production (`compose.prod.yaml`)

- Образы — те же Dockerfile, стейдж `target: production`: код вшит, без bind-mount.
- **nginx-prod копирует `public/` из образа php** через compose
  `build.additional_contexts: { php: service:php }` + `COPY --from=php` в Dockerfile.
  Поэтому prod-сборку nginx нельзя делать без php-контекста.
- **Единый edge** (один домен): `prod.conf` шлёт статику/`/api`/`/admin`/`/livewire`
  на php-fpm, остальное — на Next. (В dev иначе: хосты разводит Traefik, nginx — только Laravel.)
- **`.dockerignore` обязателен**: иначе `COPY backend`/`frontend` затащат `vendor/`,
  `node_modules/`, `.next/` и (опасно) dev-`.env` в образ.
- **Next standalone**: в `frontend/next.config.ts` нужен `output: 'standalone'`,
  иначе нет `.next/standalone` и прод-образ node не соберётся.
- Env в прод — через `environment`/secrets (`.env.prod`), не из файла в образе.
  `APP_KEY` обязателен. Миграции — отдельный шаг деплоя, не на старте контейнера.
- Локальная проверка: `make prod-build && make prod-up && make prod-migrate` (нужен `.env.prod`).

## Граница skeleton ↔ package-core (важно не путать)

- **skeleton** — оболочка: инфраструктура, инструменты, CI/CD, конвенции, документация и
  *пустые* приложения. Тут НЕ должно быть контента/модулей, общих для всех проектов.
- **package-core** — устанавливаемая начинка: модели, контроллеры, миграции, сидеры,
  компоненты, дизайн-система, render-эндпоинт, catch-all, блоки. Обновляется централизованно.
- Критерий: «если поправлю — должно прилететь во все проекты?» Да → package-core. Нет → skeleton.
- Срез CMS→API→SSR был написан для валидации инфраструктуры и **вынесен** из skeleton в
  `../_reference-phase3-slice/` (там же — карта переноса в package-core). В skeleton не возвращать.

## Связь API ↔ Next (целевая архитектура; код — в package-core)

Описание того, КАК будут устроены проекты (подробнее — `docs/architecture.md`). Сами реализации
приедут из package-core; skeleton лишь обеспечивает транспорт и конвенции.

- Server-side fetch — на `INTERNAL_API_URL` (`http://api-internal/api`), не на публичный хост.
- Один catch-all делегирует роутинг бэкенду: `GET /api/render?path=...&locale=...` →
  `{ status, redirect, locale, route, seo, blocks }`.
- Блоки в формате Filament Builder `[{type, data}]`; на фронте — реестр `type → компонент`.
- Инвалидация: обсерверы Filament → `POST /api/revalidate` (Next route handler) по cache-тегам.

## i18n

- Языки: мультиязычность, дефолт `ru`. Локаль — префикс пути. Slug уникален в рамках локали.
