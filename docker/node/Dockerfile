# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────────────────────────────────────
# base — фиксированная версия Node. Тег пинуем жёстко (Node 26 — Current на 2026,
# уходит в LTS осенью 2026). Менять версию — осознанно, в одном месте.
# ──────────────────────────────────────────────────────────────────────────────
FROM node:26-alpine AS base

WORKDIR /app/frontend

# ──────────────────────────────────────────────────────────────────────────────
# development — код и node_modules монтируются с хоста (см. make install-frontend),
# образ остаётся тонким. Команду запуска задаёт compose (npm run dev).
# ──────────────────────────────────────────────────────────────────────────────
FROM base AS development

# su-exec нужен entrypoint'у для сброса привилегий на хостовые UID/GID.
RUN apk add --no-cache su-exec

# /app создаётся под root (WORKDIR), а рантайм-пользователь динамический. Делаем
# родительский каталог записываемым — иначе инструменты (create-next-app) падают
# на проверке прав родителя проекта. /app/frontend — это bind-mount с хоста.
RUN mkdir -p /app && chmod 0777 /app

# NODE_ENV не задаём: `next dev` сам выставляет development, `next build` — production.
# Жёстко прошитый development ломает сборку в CI (build-worker падает с useContext null).
ENV NEXT_TELEMETRY_DISABLED=1

COPY docker/node/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["npm", "run", "dev"]

# ──────────────────────────────────────────────────────────────────────────────
# deps — отдельный слой зависимостей для кэширования.
# ──────────────────────────────────────────────────────────────────────────────
FROM base AS deps

COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci

# ──────────────────────────────────────────────────────────────────────────────
# builder — сборка Next в standalone-режим (output: 'standalone' в next.config).
# ──────────────────────────────────────────────────────────────────────────────
FROM base AS builder

ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=deps /app/frontend/node_modules ./node_modules
COPY frontend ./
RUN npm run build

# ──────────────────────────────────────────────────────────────────────────────
# production — минимальный рантайм: только standalone-вывод и статика.
# ──────────────────────────────────────────────────────────────────────────────
FROM base AS production

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000

COPY --from=builder /app/frontend/.next/standalone ./
COPY --from=builder /app/frontend/.next/static ./.next/static
COPY --from=builder /app/frontend/public ./public

USER node

EXPOSE 3000

CMD ["node", "server.js"]
