#!/bin/sh
set -e

# Ensure storage directories exist
mkdir -p /var/www/html/storage/framework/{sessions,views,cache}
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/bootstrap/cache
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Cache configuration (only if env is set)
php artisan config:cache --no-ansi 2>/dev/null || true
php artisan route:cache --no-ansi 2>/dev/null || true

# Run migrations (safe on startup, will fail only if DB is unreachable)
php artisan migrate --force --no-ansi 2>/dev/null || true

# Some platforms (Back4App Containers, etc.) inject a PORT env var that the
# app must listen on. Render also sets PORT — binding to it works there too.
# Fall back to 80 when it isn't set (plain `docker run`, local testing).
PORT="${PORT:-80}"
if [ "$PORT" != "80" ]; then
    sed -i "s/^Listen 80$/Listen $PORT/" /etc/apache2/ports.conf
    sed -i "s/<VirtualHost \*:80>/<VirtualHost *:$PORT>/" /etc/apache2/sites-available/000-default.conf
fi

# Start Apache in foreground
exec apache2-foreground
