# Docker Laravel Infrastructure

Infrastructure Docker complète pour une application Laravel avec haute disponibilité : MySQL + 2 serveurs PHP-FPM + 2 instances Nginx.

## 📋 Architecture

```
┌─────────────┐         ┌─────────────┐
│   Nginx 1   │         │   Nginx 2   │
│  :8081      │         │  :8082      │
└──────┬──────┘         └──────┬──────┘
       │                       │
       │ FastCGI               │ FastCGI
       ▼                       ▼
┌─────────────┐         ┌─────────────┐
│   PHP-FPM 1 │         │   PHP-FPM 2 │
│   :9000     │         │   :9000     │
└──────┬──────┘         └──────┬──────┘
       │                       │
       └───────────┬───────────┘
                   ▼
           ┌──────────────┐
           │    MySQL 8   │
           │    :3306     │
           └──────────────┘
```

### Services

- **MySQL** : Base de données Laravel (port 3306)
- **php1** / **php2** : Deux containers PHP-FPM identiques avec configurations différentes
- **nginx1** / **nginx2** : Deux reverse-proxy Nginx (ports 8081 et 8082)

Cette architecture permet :
- Tolérance aux pannes (un serveur peut tomber sans affecter l'autre)
- Distribution de charge
- Déploiements blue/green

## 🚀 Démarrage rapide

### Prérequis

- Docker Desktop (macOS/Windows) ou Docker Engine + Docker Compose (Linux)
- Au moins 4 GB de RAM disponible
- Ports 3306, 8081, 8082 libres

### Installation

1. **Cloner le dépôt**
   ```bash
   git clone <repo-url>
   cd dockerTP
   ```

2. **Préparer les fichiers d'environnement**
   ```bash
   cp .env.example .env.server1
   cp .env.example .env.server2
   # Éditer .env.server1 et .env.server2 selon vos besoins
   ```

3. **Build et démarrage**
   ```bash
   docker compose -f docker/docker-compose.yml up --build -d
   ```

4. **Vérifier le statut**
   ```bash
   docker compose -f docker/docker-compose.yml ps
   ```

5. **Accéder à l'application**
   - Serveur 1 : http://localhost:8081
   - Serveur 2 : http://localhost:8082

## 📁 Structure du projet

```
dockerTP/
├── docker/
│   ├── docker-compose.yml      # Orchestration des services
│   ├── Config NGINX.conf       # Template de configuration Nginx
│   ├── php/
│   │   ├── Dockerfile          # Image PHP-FPM customisée
│   │   └── entrypoint.sh       # Script de démarrage Laravel
│   ├── nginx/
│   │   ├── nginx1.conf         # Config Nginx pour serveur 1
│   │   └── nginx2.conf         # Config Nginx pour serveur 2
│   └── scripts/
│       ├── reset-db.sh         # Réinitialiser la base de données
│       └── smoke-test.sh       # Tests de validation
├── .env.server1                # Variables d'environnement serveur 1
├── .env.server2                # Variables d'environnement serveur 2
└── README.md                   # Ce fichier
```

## 🔧 Commandes utiles

### Gestion des containers

```bash
# Voir les logs en temps réel
docker compose -f docker/docker-compose.yml logs -f

# Logs d'un service spécifique
docker compose -f docker/docker-compose.yml logs -f php1

# Arrêter tous les services
docker compose -f docker/docker-compose.yml down

# Arrêter et supprimer les volumes (⚠️ perte de données)
docker compose -f docker/docker-compose.yml down -v

# Redémarrer un service
docker compose -f docker/docker-compose.yml restart php1
```

### Laravel

```bash
# Exécuter une commande Artisan
docker compose -f docker/docker-compose.yml exec php1 php artisan migrate

# Accéder au shell du container PHP
docker compose -f docker/docker-compose.yml exec php1 bash

# Lancer les tests
docker compose -f docker/docker-compose.yml exec php1 php artisan test

# Générer une nouvelle clé d'application
docker compose -f docker/docker-compose.yml exec php1 php artisan key:generate
```

### Base de données

```bash
# Se connecter à MySQL
docker compose -f docker/docker-compose.yml exec mysql mysql -u laravel -p

# Exporter la base de données
docker compose -f docker/docker-compose.yml exec mysql mysqldump -u laravel -p laravel > backup.sql

# Réinitialiser et reseed (via script)
./docker/scripts/reset-db.sh
```

## 🔍 Variables d'environnement

### Fichiers `.env.server1` et `.env.server2`

Ces fichiers contiennent la configuration spécifique à chaque serveur PHP-FPM :

```env
APP_NAME="Laravel Server 1"
APP_ENV=production
APP_KEY=                        # Généré automatiquement au premier démarrage
APP_DEBUG=false
APP_URL=http://localhost:8081

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=laravelpass

# Autres variables selon les besoins (cache, queue, mail, etc.)
```

**Différences principales** :
- `APP_NAME` : permet d'identifier quel serveur traite la requête
- `APP_URL` : 8081 vs 8082
- `SESSION_DOMAIN` : si besoin de sticky sessions

## 🐛 Dépannage

### Les containers ne démarrent pas

```bash
# Voir les erreurs détaillées
docker compose -f docker/docker-compose.yml logs

# Vérifier que les ports ne sont pas occupés
lsof -i :3306
lsof -i :8081
lsof -i :8082
```

### Erreur "Waiting for database"

Le container PHP attend que MySQL soit prêt. C'est normal au premier démarrage (peut prendre 30-60 secondes). Si ça bloque :

```bash
# Vérifier que MySQL est bien démarré
docker compose -f docker/docker-compose.yml exec mysql mysql -u root -prootpass -e "SELECT 1"
```

### Erreur 502 Bad Gateway (Nginx)

PHP-FPM n'est pas accessible. Vérifier :

```bash
# PHP-FPM tourne-t-il ?
docker compose -f docker/docker-compose.yml ps php1

# Logs PHP-FPM
docker compose -f docker/docker-compose.yml logs php1

# Tester la connexion FastCGI
docker compose -f docker/docker-compose.yml exec nginx1 nc -zv php1 9000
```

### Erreur "Class not found" ou "composer dependencies"

Les dépendances ne sont pas installées :

```bash
# Réinstaller les dépendances
docker compose -f docker/docker-compose.yml exec php1 composer install
```

### Permissions denied sur les logs Laravel

```bash
# Réparer les permissions
docker compose -f docker/docker-compose.yml exec php1 chown -R www-data:www-data /var/www/html/storage
docker compose -f docker/docker-compose.yml exec php1 chmod -R 775 /var/www/html/storage
```

## 📊 Tests et validation

### Script de smoke test

```bash
./docker/scripts/smoke-test.sh
```

Ce script vérifie :
- ✅ Les containers tournent
- ✅ HTTP 200 sur les deux Nginx
- ✅ MySQL répond
- ✅ PHP-FPM traite les requêtes

### Tests manuels

```bash
# Tester Nginx 1
curl -I http://localhost:8081

# Tester Nginx 2
curl -I http://localhost:8082

# Vérifier la version PHP
docker compose -f docker/docker-compose.yml exec php1 php -v

# Lister les routes Laravel
docker compose -f docker/docker-compose.yml exec php1 php artisan route:list
```

## 🔐 Sécurité

### Pour la production

⚠️ **Cette configuration est pour le développement/démo.** En production :

1. **Changer tous les mots de passe** (MySQL root, user, APP_KEY)
2. **Utiliser des secrets Docker** au lieu de variables en clair
3. **Activer HTTPS** avec Let's Encrypt ou certificats auto-signés
4. **Limiter les ressources** (CPU, RAM) dans `docker-compose.yml`
5. **Restreindre les ports** : ne pas exposer MySQL (3306) publiquement
6. **Configurer un reverse proxy** (Traefik, HAProxy) devant Nginx
7. **Activer les logs centralisés** (ELK, Loki, CloudWatch…)

## 📚 Concepts clés

### Pourquoi séparer Nginx et PHP-FPM ?

- **Nginx** : serveur web ultra-rapide pour les fichiers statiques (CSS, JS, images)
- **PHP-FPM** : interpréteur PHP optimisé pour le code dynamique
- **Communication** : Nginx envoie les requêtes `.php` à PHP-FPM via le protocole FastCGI

### Rôle de `entrypoint.sh`

Script qui s'exécute au démarrage de chaque container PHP pour :
1. Copier le bon fichier `.env`
2. Attendre que MySQL soit prêt
3. Installer les dépendances Composer et NPM
4. Générer la clé Laravel et lancer les migrations (uniquement sur `php1`)
5. Démarrer PHP-FPM

### Pourquoi deux serveurs PHP identiques ?

- **Haute disponibilité** : si `php1` plante, `php2` continue de servir
- **Déploiements sans downtime** : mettre à jour `php1`, tester, puis `php2`
- **Canary deployments** : tester une nouvelle version sur 10% du trafic

## 🤝 Contribution

### Workflow de développement

1. Créer une branche : `git checkout -b feature/ma-fonctionnalité`
2. Faire les modifications
3. Tester localement : `docker compose up --build`
4. Commit et push
5. Ouvrir une Pull Request

### Conventions

- Commits en français ou anglais, mais cohérents
- Tester avant de pousser
- Mettre à jour ce README si vous ajoutez des services

## 📞 Support

En cas de problème :
1. Consulter la section **Dépannage**
2. Vérifier les logs : `docker compose logs -f`
3. Ouvrir une issue sur le repo GitHub

---

**Auteurs** : Équipe Docker Laravel  
**Dernière mise à jour** : Novembre 2025
