# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────────────────────────────────────
# base — общий nginx + базовый http-конфиг.
# ──────────────────────────────────────────────────────────────────────────────
FROM nginx:1.27-alpine AS base
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf

# ──────────────────────────────────────────────────────────────────────────────
# development — обслуживает только Laravel (public/ монтируется bind-mount'ом из
# compose). Публичный сайт в dev проксирует Traefik напрямую на node.
# ──────────────────────────────────────────────────────────────────────────────
FROM base AS development
COPY docker/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf

# ──────────────────────────────────────────────────────────────────────────────
# production — единый edge: статика/`/api`/`/admin` → php-fpm, остальное → Next.
# public/ Laravel'а берётся из прод-образа php (compose: additional_contexts php).
# ──────────────────────────────────────────────────────────────────────────────
FROM base AS production
COPY docker/nginx/prod.conf /etc/nginx/conf.d/default.conf
COPY --from=php /var/www/backend/public /var/www/backend/public
