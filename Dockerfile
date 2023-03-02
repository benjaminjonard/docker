FROM debian:11-slim

# Set version label
LABEL maintainer="Benjamin Jonard <jonard.benjamin@gmail.com>"

ARG GITHUB_RELEASE

# Environment variables
ENV APP_ENV=prod
ENV PUID='1000'
ENV PGID='1000'
ENV USER='koillection'

COPY entrypoint.sh /

# Add User and Group
RUN addgroup --gid "$PGID" "$USER" && \
    adduser --gecos '' --no-create-home --disabled-password --uid "$PUID" --gid "$PGID" "$USER"

# Install some basics dependencies
RUN apt-get update && \
    apt-get install -y curl wget lsb-release

# Add PHP
RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

# Nodejs
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -

# Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# Install packages
RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    apt-transport-https \
    gnupg2 \
    git \
    unzip \
    nginx-light \
    openssl \
    php8.2 \
    php8.2-pgsql \
    php8.2-mysql \
    php8.2-mbstring \
    php8.2-gd \
    php8.2-xml \
    php8.2-zip \
    php8.2-fpm \
    php8.2-intl \
    php8.2-apcu \
    nodejs \
    yarn

# Clone the repo
RUN mkdir -p /var/www/koillection && \
    curl -o /tmp/koillection.tar.gz -L "https://github.com/koillection/koillection/archive/$GITHUB_RELEASE.tar.gz" && \
    tar xf /tmp/koillection.tar.gz -C /var/www/koillection --strip-components=1 && \
    rm -rf /tmp/*

#Install composer dependencies
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    cd /var/www/koillection && \
    composer install --no-dev --classmap-authoritative && \
    composer clearcache

# Dump translation files for javascript
RUN cd /var/www/koillection/ && \
    php bin/console bazinga:js-translation:dump assets/js --format=js

# Install javascript dependencies and build assets
RUN cd /var/www/koillection/assets && \
    yarn --version && \
    yarn install && \
    yarn build

# Clean up
RUN yarn cache clean && \
    rm -rf /var/www/koillection/assets/node_modules && \
    apt-get purge -y wget lsb-release git nodejs yarn apt-transport-https ca-certificates gnupg2 unzip && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/local/bin/composer

# Set permissions
RUN chown -R "$USER":"$USER" /var/www/koillection && \
    chmod +x /entrypoint.sh && \
    mkdir /run/php

# Add nginx and PHP config files
COPY default.conf /etc/nginx/nginx.conf
COPY php.ini /etc/php/8.2/fpm/conf.d/php.ini

EXPOSE 80

VOLUME /uploads

WORKDIR /var/www/koillection

HEALTHCHECK CMD curl --fail http://localhost:80/ || exit 1

ENTRYPOINT [ "/entrypoint.sh" ]

CMD [ "nginx" ]
