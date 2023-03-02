#!/bin/bash

set -e

echo "**** 1/11 - Make sure /uploads folders exist ****"
[ ! -f /uploads ] && \
	mkdir -p /uploads

echo "**** 2/11 - Create the symbolic link for the /uploads folder ****"
[ ! -L /var/www/koillection/public/uploads ] && \
	cp -r /var/www/koillection/public/uploads/. /uploads && \
	rm -r /var/www/koillection/public/uploads && \
	ln -s /uploads /var/www/koillection/public/uploads

echo "**** 3/11 - Setting env variables ****"
rm -rf /var/www/koillection/.env.local
touch /var/www/koillection/.env.local

echo "APP_ENV=${APP_ENV:-prod}" >> "/var/www/koillection/.env.local"
echo "APP_DEBUG=${APP_DEBUG:-0}" >> "/var/www/koillection/.env.local"
echo "APP_SECRET=${APP_SECRET:-$(openssl rand -base64 21)}" >> "/var/www/koillection/.env.local"

echo "JWT_SECRET_KEY=${JWT_SECRET_KEY:-%kernel.project_dir%/config/jwt/private.pem}" >> "/var/www/koillection/.env.local"
echo "JWT_PUBLIC_KEY=${JWT_PUBLIC_KEY:-%kernel.project_dir%/config/jwt/public.pem}" >> "/var/www/koillection/.env.local"
echo "JWT_SECRET_KEY=${JWT_SECRET_KEY:-$(openssl rand -base64 21)}" >> "/var/www/koillection/.env.local"

echo "DB_DRIVER=${DB_DRIVER:-}" >> "/var/www/koillection/.env.local"
echo "DB_NAME=${DB_NAME:-}" >> "/var/www/koillection/.env.local"
echo "DB_HOST=${DB_HOST:-}" >> "/var/www/koillection/.env.local"
echo "DB_PORT=${DB_PORT:-}" >> "/var/www/koillection/.env.local"
echo "DB_USER=${DB_USER:-}" >> "/var/www/koillection/.env.local"
echo "DB_PASSWORD=${DB_PASSWORD:-}" >> "/var/www/koillection/.env.local"
echo "DB_VERSION=${DB_VERSION:-}" >> "/var/www/koillection/.env.local"

echo "CORS_ALLOW_ORIGIN=${CORS_ALLOW_ORIGIN:-'^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$'}" >> "/var/www/koillection/.env.local"

echo "session.cookie_secure=${HTTPS_ENABLED}" >> /etc/php/8.2/fpm/conf.d/php.ini
echo "date.timezone=${PHP_TZ}" >> /etc/php/8.2/fpm/conf.d/php.ini

echo "**** 4/11 - Migrate the database ****"
cd /var/www/koillection && \
php bin/console doctrine:migration:migrate --no-interaction --allow-no-migration --env=prod

echo "**** 5/11 - Refresh cached values ****"
cd /var/www/koillection && \
php bin/console app:refresh-cached-values --env=prod

echo "**** 6/11 - Create API keys ****"
cd /var/www/koillection && \
php bin/console lexik:jwt:generate-keypair --overwrite --env=prod

echo "**** 7/11 - Create user and use PUID/PGID ****"
PUID=${PUID:-1000}
PGID=${PGID:-1000}
if [ ! "$(id -u "$USER")" -eq "$PUID" ]; then usermod -o -u "$PUID" "$USER" ; fi
if [ ! "$(id -g "$USER")" -eq "$PGID" ]; then groupmod -o -g "$PGID" "$USER" ; fi
echo -e " \tUser UID :\t$(id -u "$USER")"
echo -e " \tUser GID :\t$(id -g "$USER")"

echo "**** 8/11 - Set Permissions ****" && \
find /uploads -type d \( ! -user "$USER" -o ! -group "$USER" \) -exec chown -R "$USER":"$USER" \{\} \;
find /uploads \( ! -user "$USER" -o ! -group "$USER" \) -exec chown "$USER":"$USER" \{\} \;
usermod -a -G "$USER" www-data
find /uploads -type d \( ! -perm -ug+w -o ! -perm -ugo+rX \) -exec chmod -R ug+w,ugo+rX \{\} \;
find /uploads \( ! -perm -ug+w -o ! -perm -ugo+rX \) -exec chmod ug+w,ugo+rX \{\} \;

echo "**** 9/11 - Create nginx log files ****" && \
mkdir -p /logs/nginx
chown -R "$USER":"$USER" /logs/nginx

echo "**** 10/11 - Create symfony log files ****" && \
[ ! -f /var/www/koillection/var/log ] && \
	mkdir -p /var/www/koillection/var/log

[ ! -f /var/www/koillection/var/log/prod.log ] && \
	touch /var/www/koillection/var/log/prod.log

chown -R www-data:www-data /var/www/koillection/var

echo "**** 11/11 - Setup complete, starting the server. ****"
php-fpm8.2
exec $@

echo "**** All done ****"