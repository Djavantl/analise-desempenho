#!/bin/sh
set -e

cd /var/www/html

if [ ! -f .env ]; then
cat > .env <<'EOF'
APP_NAME=Laravel
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost
LOG_CHANNEL=stderr
LOG_LEVEL=error
DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
DB_DATABASE=perf_db
DB_USERNAME=user
DB_PASSWORD=password
SESSION_DRIVER=array
CACHE_STORE=array
QUEUE_CONNECTION=sync
EOF
fi

php artisan key:generate --force
php artisan config:cache
php artisan route:cache
php artisan migrate --force

exec /usr/bin/supervisord -c /etc/supervisord.conf
