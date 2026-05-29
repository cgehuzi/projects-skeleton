# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────────────────────────────────────
# base — общий слой с расширениями PHP, актуальный и для dev, и для prod.
# ──────────────────────────────────────────────────────────────────────────────
FROM php:8.4-fpm-alpine AS base

# Системные зависимости, нужные для сборки расширений PHP.
RUN apk add --no-cache \
        bash \
        git \
        curl \
        icu-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        postgresql-dev \
        oniguruma-dev \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        linux-headers

# Расширения, необходимые Laravel 12 + Filament 4 + PostgreSQL/Redis.
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_pgsql \
        pgsql \
        gd \
        intl \
        zip \
        bcmath \
        exif \
        pcntl \
        opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# Composer берём из официального образа — единый источник версии.
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/backend

COPY docker/php/php.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/zz-www.conf

# ──────────────────────────────────────────────────────────────────────────────
# development — код монтируется bind-mount'ом, добавляем Xdebug. Рантайм-пользователь
# НЕ зашивается в образ: его задаёт compose (`user: "UID:GID"`) под хостовые UID/GID,
# чтобы файлы, созданные в контейнере, не были root'овыми на хосте. Это портируемо
# (macOS/Linux) и не конфликтует с уже занятыми в Alpine GID.
# ──────────────────────────────────────────────────────────────────────────────
FROM base AS development

RUN apk add --no-cache --virtual .xdebug-deps $PHPIZE_DEPS linux-headers \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del .xdebug-deps

COPY docker/php/xdebug.ini /usr/local/etc/php/conf.d/zz-xdebug.ini

# ──────────────────────────────────────────────────────────────────────────────
# production — код копируется внутрь образа, зависимости ставятся без dev,
# autoloader оптимизируется, OPcache в боевом режиме.
# ──────────────────────────────────────────────────────────────────────────────
FROM base AS production

ENV APP_ENV=production \
    APP_DEBUG=false

COPY docker/php/opcache.prod.ini /usr/local/etc/php/conf.d/zz-opcache.ini

COPY backend /var/www/backend

RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader \
    && chown -R www-data:www-data /var/www/backend/storage /var/www/backend/bootstrap/cache

USER www-data

CMD ["php-fpm"]
