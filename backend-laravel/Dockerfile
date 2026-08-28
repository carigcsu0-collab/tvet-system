FROM php:8.2-apache

# System dependencies + LibreOffice (headless, used to convert the
# communication-editor's HTML content into a properly formatted PDF).
# libreoffice-writer is enough (avoids pulling the full libreoffice meta
# package which also installs Impress/Calc/etc. and bloats the image).
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libzip-dev \
        libpng-dev \
        libonig-dev \
        libxml2-dev \
        default-mysql-client \
        libreoffice-writer \
        fonts-liberation \
    && docker-php-ext-install pdo_mysql zip gd \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

COPY . .

RUN composer dump-autoload --optimize \
    && mkdir -p storage/framework/{sessions,views,cache} storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache

COPY apache.conf /etc/apache2/sites-available/000-default.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# The communication editor sends a self-contained HTML document with
# base64-embedded fonts/images (a few MB), and LibreOffice conversion can
# take a few seconds — raise the relevant PHP limits accordingly.
RUN { \
        echo 'upload_max_filesize=32M'; \
        echo 'post_max_size=32M'; \
        echo 'max_execution_time=90'; \
        echo 'memory_limit=256M'; \
    } > /usr/local/etc/php/conf.d/zz-tvet.ini

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
