FROM alpine:3.21

ARG ALPINE_PACKAGES="php83-iconv php83-pdo_mysql php83-pdo_pgsql php83-openssl php83-simplexml"
ARG COMPOSER_PACKAGES="aws/aws-sdk-php google/cloud-storage"
ARG UID=65534
ARG GID=82

ENV CONFIG_PATH=/srv/cfg
ENV PATH=$PATH:/srv/bin

LABEL org.opencontainers.image.authors=support@privatebin.org \
      org.opencontainers.image.vendor=PrivateBin \
      org.opencontainers.image.documentation=https://github.com/PrivateBin/docker-nginx-fpm-alpine/blob/master/README.md \
      org.opencontainers.image.source=https://github.com/PrivateBin/docker-nginx-fpm-alpine \
      org.opencontainers.image.licenses=zlib-acknowledgement

# Install dependencies
RUN apk upgrade --no-cache \
    && apk add --no-cache nginx php83 php83-ctype php83-fpm php83-gd \
        php83-opcache s6 tzdata ${ALPINE_PACKAGES} \
# Stabilize php config location
    && mv /etc/php83 /etc/php \
    && ln -s /etc/php /etc/php83 \
    && ln -s $(which php83) /usr/local/bin/php \
# Remove (some of the) default nginx & php config
    && rm -f /etc/nginx.conf /etc/nginx/http.d/default.conf /etc/php/php-fpm.d/www.conf \
    && rm -rf /etc/nginx/sites-* \
# Ensure nginx logs, even if the config has errors, are written to stderr
    && ln -s /dev/stderr /var/log/nginx/error.log \
# Create necessary directories
    && mkdir -p /srv/data \
# Support running s6 under a non-root user
    && mkdir -p /etc/s6/services/nginx/supervise /etc/s6/services/php-fpm83/supervise \
    && mkfifo \
        /etc/s6/services/nginx/supervise/control \
        /etc/s6/services/php-fpm83/supervise/control \
    && chown -R ${UID}:${GID} /etc/s6 /run /srv /var/lib/nginx /var/www \
    && chmod o+rwx /run /var/lib/nginx /var/lib/nginx/tmp

# Copy your local PrivateBin code
COPY PrivateBin/ /var/www/
RUN cd /var/www \
    && mv bin cfg lib tpl vendor /srv \
    && sed -i "s#define('PATH', '');#define('PATH', '/srv/');#" index.php

COPY etc/ /etc/

WORKDIR /var/www
# user nobody, group www-data
USER ${UID}:${GID}

# mark dirs as volumes that need to be writable, allows running the container --read-only
VOLUME /run /srv/data /tmp /var/lib/nginx/tmp

EXPOSE 8080

ENTRYPOINT ["/etc/init.d/rc.local"]
