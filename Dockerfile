FROM debian:12.6-slim

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive
ENV NGINX_VERSION 1.25.1
ENV PHP_V 8.2
ENV php_conf /etc/php/8.2/fpm/php.ini
ENV fpm_conf /etc/php/8.2/fpm/pool.d/www.conf
ENV COMPOSER_VERSION 2.5.8

#Installing base requirements
RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends curl gcc make autoconf libc-dev zlib1g-dev pkg-config --no-install-suggests -q -y gnupg2 dirmngr wget apt-transport-https lsb-release ca-certificates \
# Preparing external repositories
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/nginx/ bookworm main" >> /etc/apt/sources.list.d/nginx.list \
    && wget -O /etc/apt/trusted.gpg.d/nginx.gpg https://packages.sury.org/nginx/apt.gpg \
    && echo "deb https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list \
# Installing requirements
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -q -y \
            apt-utils \
            nano \
            zip \
            unzip \
            python3-pip \
            python3-setuptools \
            git \
            libmemcached-dev \
            libmemcached11 \
            libmagickwand-dev \
            nginx \
            php${PHP_V}-fpm \
            php${PHP_V}-cli \
            php${PHP_V}-bcmath \
            php${PHP_V}-dev \
            php${PHP_V}-common \
            php${PHP_V}-opcache \
            php${PHP_V}-readline \
            php${PHP_V}-mbstring \
            php${PHP_V}-curl \
            php${PHP_V}-gd \
            php${PHP_V}-imagick \
            php${PHP_V}-mysql \
            php${PHP_V}-zip \
            php${PHP_V}-pgsql \
            php${PHP_V}-intl \
            php${PHP_V}-xml \
            php${PHP_V}-ldap \
            php-pear \
    && pecl -d php_suffix=${PHP_V} install -o -f redis memcached \
# Installing PHP requirements
    && mkdir -p /run/php \
    && apt-get install python3-wheel \
    && apt-get install supervisor \
    && echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
    && rm -rf /etc/nginx/sites-enabled/default \
# Apply Configs
    && sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} \
    && sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 256M/g" ${php_conf} \
    && sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${php_conf} \
    && sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${php_conf} \
    && sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf} \
    && sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/${PHP_V}/fpm/php-fpm.conf \
    && sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_children = 5/pm.max_children = 4/g" ${fpm_conf} \
    && sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${fpm_conf} \
    && sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${fpm_conf} \
    && sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm_conf} \
    && sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm_conf} \
    && echo "extension=redis.so" > /etc/php/${PHP_V}/mods-available/redis.ini \
    && echo "extension=memcached.so" > /etc/php/${PHP_V}/mods-available/memcached.ini \
    && echo "extension=imagick.so" > /etc/php/${PHP_V}/mods-available/imagick.ini \
    && ln -sf /etc/php/${PHP_V}/mods-available/redis.ini /etc/php/${PHP_V}/fpm/conf.d/20-redis.ini \
    && ln -sf /etc/php/${PHP_V}/mods-available/redis.ini /etc/php/${PHP_V}/cli/conf.d/20-redis.ini \
    && ln -sf /etc/php/${PHP_V}/mods-available/memcached.ini /etc/php/${PHP_V}/fpm/conf.d/20-memcached.ini \
    && ln -sf /etc/php/${PHP_V}/mods-available/memcached.ini /etc/php/${PHP_V}/cli/conf.d/20-memcached.ini \
    && ln -sf /etc/php/${PHP_V}/mods-available/imagick.ini /etc/php/${PHP_V}/fpm/conf.d/20-imagick.ini \
    && ln -sf /etc/php/${PHP_V}/mods-available/imagick.ini /etc/php/${PHP_V}/cli/conf.d/20-imagick.ini \
# Install Composer
    && curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
    && rm -rf /tmp/composer-setup.php \
# Clean up
    && rm -rf /tmp/pear \
    && apt-get purge -y --auto-remove $buildDeps \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/apt/cache/*

# Supervisor config
COPY ./supervisord.conf /etc/supervisord.conf
COPY ./supervisor_stdout.py /usr/bin/supervisor_stdout.py
RUN chmod o+x /usr/bin/supervisor_stdout.py

# Override nginx's default config
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Override default nginx welcome page
COPY html /usr/share/nginx/html

# Copy Scripts
COPY ./start.sh /start.sh

EXPOSE 80

CMD ["/start.sh"]
