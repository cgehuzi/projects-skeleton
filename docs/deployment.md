# Деплой (production)

Боевой стек собирается из тех же Dockerfile, что и dev, но на стейджах
`target: production`: код вшит в образы, без bind-mount и dev-тулинга.

> Прод-образы собираются из кода приложения. На «пустом» skeleton его нет —
> сначала каркасы создаются через `make init` и коммитятся в проект, затем
> собираются прод-образы (локально или в CI).

## Топология

Единый edge **nginx**: статика и `/api`, `/admin`, `/livewire`, `/up` → php-fpm,
всё остальное (публичный сайт) → Next SSR (`node`, standalone). TLS терминирует
внешний балансировщик/прокси (или добавляется на nginx отдельно).

```
Браузер ─▶ nginx ─┬─ /api,/admin,/livewire,static ─▶ php-fpm (Laravel/Filament)
                  └─ всё остальное ────────────────▶ node (Next SSR)
```

Сервисы: `php`, `queue`, `scheduler`, `node`, `nginx`, `postgres`, `redis`.
Postgres/Redis включены для самодостаточности — в реальном проде обычно выносятся
в managed-сервисы (убрать сервисы из `compose.prod.yaml`, задать внешние
`DB_HOST`/`REDIS_HOST` в `.env.prod`).

## Образы

| Образ   | Стейдж | Что внутри |
| ------- | ------ | ---------- |
| `php`   | `production` | Код + `composer install --no-dev` + OPcache (`validate_timestamps=0`) |
| `node`  | `production` | Next standalone (`output: 'standalone'`) → `node server.js` |
| `nginx` | `production` | Конфиг edge + `public/` Laravel'а (копируется из образа `php`) |

## Окружение

```bash
cp .env.prod.example .env.prod   # заполнить секреты; файл в .gitignore
# сгенерировать ключ:
docker compose -f compose.prod.yaml --env-file .env.prod run --rm php php artisan key:generate --show
# вписать результат в APP_KEY
```

Обязательны: `APP_KEY`, `APP_URL`, `DB_PASSWORD`. В прод значения приходят через
`environment`/секреты, не из файла в образе.

## Локальная проверка боевого стека

```bash
docker compose -f compose.prod.yaml --env-file .env.prod build
docker compose -f compose.prod.yaml --env-file .env.prod up -d
docker compose -f compose.prod.yaml --env-file .env.prod run --rm php php artisan migrate --force
# сайт: http://localhost:${HTTP_PORT}  •  админка: .../admin
```

## CI: публикация образов (на стороне ПРОЕКТА)

Прод-образы собираются из кода приложения, поэтому их публикует **проект** (у него
закоммичен каркас), а не skeleton (в шаблоне приложения нет; релизы skeleton создаются
вручную на GitHub). Добавьте в проект workflow по тегу, например
`.github/workflows/images.yml`:

```yaml
name: Images
on:
  push:
    tags: ["v*"]
permissions: { contents: read, packages: write }
jobs:
  images:
    runs-on: ubuntu-latest
    env:
      REGISTRY: ghcr.io/${{ github.repository }}
      TAG: ${{ github.ref_name }}
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - run: docker compose -f compose.prod.yaml build
      - run: docker compose -f compose.prod.yaml push
```

Образы: `ghcr.io/<owner>/<repo>/{php,node,nginx}:vX.Y.Z`. Тег `vX.Y.Z` запустит сборку:

```bash
git tag v1.2.0 && git push origin v1.2.0
```

## Деплой на сервер

На сервере (с доступом к GHCR и заполненным `.env.prod`, где `REGISTRY`/`TAG`
указывают на нужную версию):

```bash
docker compose -f compose.prod.yaml --env-file .env.prod pull
docker compose -f compose.prod.yaml --env-file .env.prod up -d
docker compose -f compose.prod.yaml --env-file .env.prod run --rm php php artisan migrate --force
# опционально, ускорение:
docker compose -f compose.prod.yaml --env-file .env.prod run --rm php php artisan config:cache route:cache
```

> Автоматизацию (SSH-деплой по тегу) добавить отдельным workflow под конкретную
> инфраструктуру (секреты хоста/ключи) — намеренно не зашито в skeleton.

## Замечания

- **Миграции** — отдельный шаг деплоя (`migrate --force`), не на старте контейнера.
- **Очередь/планировщик** — отдельные сервисы (`queue`, `scheduler`); после деплоя
  воркеры перезапускаются вместе с образом.
- **Логи** — в stdout/stderr (`LOG_CHANNEL=stderr`), собираются Docker'ом.
- **Storage** — том `app-storage` (загрузки пользователей). В кластере — заменить на
  объектное хранилище (S3-совместимое).
