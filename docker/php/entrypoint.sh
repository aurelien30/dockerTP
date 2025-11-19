#!/bin/bash
set -e

echo "=== PHP Entrypoint starting for $(hostname) ==="

cd /var/www/html

###############################################
# 1. Sélection et copie du fichier .env
###############################################

if [ -n "$ENV_FILE" ]; then
  if [ -f "/var/www/html/$ENV_FILE" ]; then
    cp "/var/www/html/$ENV_FILE" "/var/www/html/.env"
    echo "[OK] Copied $ENV_FILE → .env"
  else
    echo "[ERROR] $ENV_FILE not found in /var/www/html"
    exit 1
  fi
else
  echo "[WARN] ENV_FILE not set. Using existing .env or .env.example"
  [ -f ".env" ] || cp .env.example .env
fi

###############################################
# 2. Attendre la base de données
###############################################

if [[ -n "$DB_HOST" && -n "$DB_PORT" ]]; then
  echo "[INFO] Waiting for database $DB_HOST:$DB_PORT..."
  until nc -z "$DB_HOST" "$DB_PORT"; do
    sleep 2
  done
  echo "[OK] Database reachable"
fi

###############################################
# 3. Composer install
###############################################

if [ ! -d vendor ]; then
  echo "[INFO] Installing composer dependencies..."
  composer install --no-interaction --prefer-dist --optimize-autoloader
else
  echo "[INFO] vendor/ exists → skipping composer install"
fi

###############################################
# 4. Node build 
###############################################

if [ -f package.json ]; then
  echo "[INFO] Installing Node dependencies..."
  npm ci --no-audit --no-fund || npm install

  echo "[INFO] Building front..."
  npm run build || echo "[WARN] Front build failed but continuing"
else
  echo "[INFO] No package.json → skipping frontend"
fi

###############################################
# 5. Génération de clé + migrations 
###############################################

if [ "$MIGRATE" = "true" ]; then
  if [ ! -f /var/www/html/.initialized ]; then
    echo "[INFO] Generating app key..."
    php artisan key:generate --force

    echo "[INFO] Running migrations..."
    php artisan migrate:fresh --seed --force

    touch /var/www/html/.initialized
    echo "[OK] Initialization complete"
  else
    echo "[INFO] Already initialized → skipping migrations"
  fi
fi

###############################################
# 6. Lancer PHP-FPM
###############################################

echo "[OK] Starting PHP-FPM..."
exec php-fpm
