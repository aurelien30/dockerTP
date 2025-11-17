#!/bin/bash
set -e

# copie .env spécifique
if [ -n "$ENV_FILE" ]; then
  if [ -f "/var/www/html/$ENV_FILE" ]; then
    cp /var/www/html/$ENV_FILE /var/www/html/.env
    echo "Copied $ENV_FILE to .env"
  else
    echo "$ENV_FILE not found in project root"
  fi
fi

# Wait for DB
until nc -z $DB_HOST $DB_PORT; do
  echo "Waiting for database at $DB_HOST:$DB_PORT..."
  sleep 2
done

# install composer deps
composer install --no-interaction --prefer-dist --optimize-autoloader

# install node deps + build
if [ -f package.json ]; then
  npm ci --no-audit --no-fund || npm install
  npm run build || true
fi

# generate key + migrate only if MIGRATE=true and not initialized
if [ "$MIGRATE" = "true" ]; then
  if [ ! -f /var/www/html/.initialized ]; then
    php artisan key:generate --force
    php artisan migrate:fresh --seed --force
    touch /var/www/html/.initialized
  else
    echo "Already initialized."
  fi
fi

# start php-fpm (default)
php-fpm
