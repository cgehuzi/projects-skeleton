# Разработка

Повседневные сценарии. Все команды идут через `make` (то есть внутри контейнеров).

## Backend (Laravel + Filament)

```bash
make sh-php                      # зайти в php-контейнер
make artisan cmd="make:model X"  # любая artisan-команда
make migrate                     # миграции
make fresh                       # пересоздать БД + сидеры
make test                        # тесты
```

- Код — в `backend/`. Меняется на хосте, контейнер видит сразу (bind-mount).
- Админка Filament — `http://api.<project>.localhost/admin`.
- БД внутри сети: хост `postgres`, Redis: хост `redis` (см. `backend/.env`).

## Frontend (Next.js)

```bash
make sh-node              # зайти в node-контейнер
make npm cmd="run lint"   # любая npm-команда
make npm cmd="run build"  # прод-сборка
```

- Код — в `frontend/`. Dev-сервер с HMR проксируется Traefik на `http://<project>.localhost`.
- Публичный роутинг — один catch-all, страницы резолвит backend (см.
  [architecture.md](architecture.md)).
- Server-side запросы к API идут на `INTERNAL_API_URL` (`http://nginx/api`),
  браузерные — на `NEXT_PUBLIC_API_URL`.

## Зависимости

```bash
make install            # backend + frontend разом
make install-backend    # только composer install
make install-frontend   # только npm ci
```

Новый пакет:

```bash
make sh-php   && composer require vendor/package
make sh-node  && npm install package
```

## Отладка

- **Логи**: `make logs` (все) или `docker compose logs -f php`.
- **Xdebug**: выключен по умолчанию. Включить — `XDEBUG_MODE=debug` в окружении
  php-контейнера, порт `9003`, host `host.docker.internal`.
- **psql**: `make sh-db`.

## Перед коммитом

- Линтеры/тесты фронта и бэка должны быть зелёными.
- Не коммитим `.env`, `vendor/`, `node_modules/`, `.next/` (уже в `.gitignore`).
