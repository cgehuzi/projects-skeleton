# Projects Skeleton

Стартовая точка новых проектов: единая инфраструктура, инструментарий и практики,
заложенные корпоративными требованиями.

## Стек

| Слой        | Технологии                                  |
| ----------- | ------------------------------------------- |
| Backend     | Laravel 13 · Filament 4 · PHP 8.4           |
| Frontend    | Next.js 16 (App Router, RSC) · Node 26      |
| База данных | PostgreSQL 17                               |
| Кэш/очереди | Redis 7                                     |
| Прокси      | Traefik (общий, один на машину)             |
| Окружение   | Docker · Docker Compose                     |

## Архитектура

```
Браузер ──▶ Next.js (SSR) ──▶ Laravel API ──▶ PostgreSQL
                  ▲                  │
                  └── revalidate ────┘  (Filament публикует контент)
```

- **Laravel** — единый бэкенд: REST API + Filament-админка + источник истины
  по маршрутам. Один render-эндпоинт резолвит URL → блоки + SEO.
- **Next.js** — headless SSR-слой: единственный catch-all `[[...slug]]`
  + служебные route handlers (revalidate, preview, sitemap, robots, health).
- **Роутинг** — backend-driven: маршруты живут в БД и правятся через Filament.
- **Контент** — блочная модель + component resolver на фронте.
- **Языки** — мультиязычность, язык по умолчанию `ru`.

Подробнее — в [docs/architecture.md](docs/architecture.md).

## Требования

- Docker + Docker Compose (других зависимостей на хосте не нужно).

## Быстрый старт

```bash
make init      # .env, proxy, образы, КАРКАСЫ приложений, миграции, запуск
```

`make init` подставит в `.env` имя проекта (по имени каталога) и UID/GID хоста,
**создаст каркасы в пустых `backend/`/`frontend/`** (Laravel+Filament, Next.js),
поднимет общий Traefik и весь стек. URL зависят от имени каталога (`<project>`):

- Публичный сайт — `http://<project>.localhost`
- Filament admin — `http://api.<project>.localhost/admin`
- API — `http://api.<project>.localhost/api`

> `*.localhost` резолвится в loopback современными браузерами — править
> `/etc/hosts` не нужно. Несколько проектов работают параллельно: каждый на
> своём хосте, без конфликтов портов (см. [docker/proxy](docker/proxy/README.md)).
> Порты БД/Redis публикуются эфемерно — узнать их: `make ports`.

## Полезные команды

```bash
make help              # список всех команд
make up / make down    # поднять / остановить стек
make logs              # логи
make sh-php            # шелл в php-контейнере
make sh-node           # шелл в node-контейнере
make migrate           # миграции
make fresh             # пересоздать БД с сидерами
make artisan cmd="..." # произвольная artisan-команда
make npm cmd="..."     # произвольная npm-команда
```

## Структура

```
.
├── backend/                     # Laravel + Filament (пусто до `make init`)
├── frontend/                    # Next.js (пусто до `make init`)
├── stubs/                       # шаблоны, накладываемые при init (next.config.ts)
├── docker/                      # Dockerfile и конфиги сервисов
│   ├── nginx/                   # web-сервер перед php-fpm (Laravel)
│   ├── php/                     # php-fpm 8.4 (dev/prod)
│   ├── node/                    # Node 26 (dev/prod) + entrypoint
│   └── proxy/                   # общий Traefik (один на машину)
├── .github/workflows/          # CI/CD (ci.yml — backend + frontend)
├── docs/                        # корпоративная документация
├── compose.yaml                 # dev-стек (skeleton-managed, не править)
├── compose.prod.yaml            # боевой стек (production-образы)
├── compose.override.example.yaml# точка расширения стека под проект
├── .env.prod.example            # шаблон боевого окружения
├── Makefile                     # команды управления окружением
├── CLAUDE.md                    # нюансы реализации для ассистента/разработчиков
├── CHANGELOG.md                 # изменения skeleton (для обновлений из upstream)
└── .env.example                 # переменные окружения Docker
```

## Кастомизация и обновление

- Этот репозиторий — **оболочка**. Общая архитектурная начинка (модули, компоненты,
  дизайн-система) подключается зависимостью `package-core`, а не копируется сюда.
- Настройки проекта — через `.env`, `backend/.env` и `compose.override.yaml`
  (см. `compose.override.example.yaml`); `compose.yaml` и `docker/` не редактируем.
- Доставка изменений skeleton в уже разошедшийся проект — см.
  [docs/UPGRADING.md](docs/UPGRADING.md) (git `upstream` + дисциплина границ).
- Боевой деплой (образы, CI-публикация, процедура) — см.
  [docs/deployment.md](docs/deployment.md).
