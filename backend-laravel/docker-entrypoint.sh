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

# Start Apache in foreground
exec apache2-foreground
