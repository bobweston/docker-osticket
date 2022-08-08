FROM php:8.0-cli AS deployer 
ENV OSTICKET_VERSION=1.16.3
RUN set -x \
    && apt-get update \
    && apt-get install -y git-core \
    && git clone -b v${OSTICKET_VERSION} --depth 1 https://github.com/osTicket/osTicket.git \
    && cd osTicket \
    && php manage.php deploy -sv /data/upload \
    && mkdir /data/upload/images/attachments \
    && chown -R 82:82 /data/upload \
    # Hide setup
    && mv /data/upload/setup /data/upload/setup_hidden \
    && chown -R root:root /data/upload/setup_hidden \
    && chmod -R go= /data/upload/setup_hidden

FROM php:8.0-fpm-alpine
MAINTAINER Martin Campbell <martin@campbellsoftware.co.uk>. Updated to support php 8 and osticket 16.3 by Bob Weston
# environment for osticket
ENV HOME=/data
# setup workdir
WORKDIR /data
COPY --from=deployer /data/upload upload
RUN apk add --no-cache libzip-dev zip && docker-php-ext-configure zip && docker-php-ext-install zip && docker-php-ext-install pdo pdo_mysql

RUN set -x && \
    apk add --no-cache --update \
        wget \
        msmtp \
        ca-certificates \
        supervisor \
        nginx \
        libpng \
        c-client \
        openldap \
        libintl \
        libxml2 \
        icu \
        openssl && \
    apk add --no-cache --virtual .build-deps \
        imap-dev \
        libpng-dev \
        curl-dev \
        openldap-dev \
        gettext-dev \
        libxml2-dev \
        icu-dev \
        autoconf \
        g++ \
        make \
        pcre-dev && \
    docker-php-ext-install gd curl ldap mysqli sockets gettext xml intl opcache && \
    docker-php-ext-configure imap --with-imap-ssl && \
    docker-php-ext-install imap && \
    pecl install apcu && docker-php-ext-enable apcu && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* && \
    # Download languages packs
    wget -nv -O upload/include/i18n/fr.phar https://s3.amazonaws.com/downloads.osticket.com/lang/fr.phar && \
    wget -nv -O upload/include/i18n/ar.phar https://s3.amazonaws.com/downloads.osticket.com/lang/ar.phar && \
    wget -nv -O upload/include/i18n/pt_BR.phar https://s3.amazonaws.com/downloads.osticket.com/lang/pt_BR.phar && \
    wget -nv -O upload/include/i18n/it.phar https://s3.amazonaws.com/downloads.osticket.com/lang/it.phar && \
    wget -nv -O upload/include/i18n/es_ES.phar https://s3.amazonaws.com/downloads.osticket.com/lang/es_ES.phar && \
    wget -nv -O upload/include/i18n/de.phar https://s3.amazonaws.com/downloads.osticket.com/lang/de.phar && \
    mv upload/include/i18n upload/include/i18n.dist && \
    # Download LDAP plugin
    wget -nv -O upload/include/plugins/auth-ldap.phar https://s3.amazonaws.com/downloads.osticket.com/plugin/auth-ldap.phar && \
    # Create msmtp log
    touch /var/log/msmtp.log && \
    chown www-data:www-data /var/log/msmtp.log && \
    # File upload permissions
    mkdir -p /var/tmp/nginx && \
    chown nginx:www-data /var/tmp/nginx && chmod g+rx /var/tmp/nginx
COPY files/ /
VOLUME ["/data/upload/include/plugins","/data/upload/include/i18n","/var/log/nginx","/data/upload/images/attachments"]
EXPOSE 80
CMD ["/data/bin/start.sh"]
