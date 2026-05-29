#!/bin/sh
# Подгоняет рантайм-пользователя под окружение и сбрасывает привилегии так, чтобы
# файлы в bind-mount были «своими» на хосте — и на Linux, и на macOS.
#
# Зачем сложно:
#   - у целевого UID должна быть запись в /etc/passwd, иначе Node роняет
#     os.userInfo() (ошибка uv_os_get_passwd) — на этом падает create-next-app;
#   - на Linux нужно писать от хостового UID (иначе node_modules станут root);
#   - на macOS Docker Desktop bind-mount виден как root:root, под обычным UID в
#     него не записать, зато запись от root корректно мапится на хостового юзера.
set -e

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# Группа с нужным GID (переиспользуем, если GID занят системной группой).
if ! getent group "$PGID" >/dev/null 2>&1; then
    addgroup -g "$PGID" app
fi
GROUP_NAME="$(getent group "$PGID" | cut -d: -f1)"

# Пользователь с нужным UID (нужен и для прав, и для записи в /etc/passwd).
if ! getent passwd "$PUID" >/dev/null 2>&1; then
    adduser -u "$PUID" -G "$GROUP_NAME" -D -h /home/app app
fi
USER_NAME="$(getent passwd "$PUID" | cut -d: -f1)"

# Best-effort: на Linux выставит владельца каталога проекта; на macOS — no-op.
chown "$PUID:$PGID" /app/frontend 2>/dev/null || true

# Если целевой пользователь может писать в каталог проекта — работаем под ним.
# Иначе (macOS: каталог принадлежит root) остаёмся root: запись всё равно
# мапится на хостового пользователя файловым слоем Docker Desktop.
if su-exec "$PUID:$PGID" test -w /app/frontend 2>/dev/null; then
    export HOME="$(getent passwd "$PUID" | cut -d: -f6)"
    exec su-exec "$PUID:$PGID" "$@"
else
    export HOME=/root
    exec "$@"
fi
