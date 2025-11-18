FROM php:8.1-fpm

# Install system deps, netcat, node and build tools
RUN apt-get update && apt-get install -y \
    git unzip zip curl libzip-dev build-essential \
    netcat-openbsd \
    nodejs npm \
  && docker-php-ext-install pdo_mysql mbstring zip \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy entrypoint and grant execution
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000
CMD ["entrypoint.sh"]
