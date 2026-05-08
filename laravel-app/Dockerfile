FROM php:8.2-fpm-alpine

RUN apk add --no-cache git zip unzip libpq-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_pgsql opcache

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

RUN composer create-project --prefer-dist --no-interaction laravel/laravel:^11 .

COPY src/bootstrap/app.php bootstrap/app.php
COPY src/app/Models/Item.php app/Models/Item.php
COPY src/app/Http/Controllers/ItemController.php app/Http/Controllers/ItemController.php
COPY src/routes/api.php routes/api.php
COPY src/.env .env

RUN composer install --no-dev --optimize-autoloader --no-interaction \
    && mkdir -p storage/logs storage/framework/cache storage/framework/sessions storage/framework/views bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

COPY nginx.conf /etc/nginx/http.d/default.conf
COPY supervisord.conf /etc/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

CMD ["/entrypoint.sh"]
