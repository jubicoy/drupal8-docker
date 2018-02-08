FROM jubicoy/nginx-php:php7
ENV DRUPAL_VERSION 8.4.4
ENV COMPOSER_VERSION 1.4.1
ENV SABRE_VERSION "~3.1.0"

RUN apt-get update \
    && apt-get -y install \
      apache2-utils \
      curl \
      git \
      gzip \
      mysql-client \
      netcat \
      php7.0-cli \
      php7.0-common \
      php7.0-curl \
      php7.0-dev \
      php7.0-fpm \
      php7.0-gd \
      php7.0-imap \
      php7.0-json \
      php7.0-mbstring \
      php7.0-mcrypt \
      php7.0-mysql \
      php7.0-pgsql \
      php7.0-sqlite \
      php7.0-zip \
      php-imagick \
      php-memcache \
      php-pear \
      php-redis \
      wget \
    && rm -rf /var/lib/apt/lists/*

RUN curl -k https://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz | tar zx -C /var/www/ \
  && mv /var/www/drupal-${DRUPAL_VERSION} /var/www/drupal \
  && cp -rf /var/www/drupal/sites/default /tmp/ \
  && cp -f /var/www/drupal/robots.txt /workdir/

# Composer for Sabre installation
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION}

# WebDAV configuration
#RUN apt-get install -y apache2-utils
RUN mkdir -p /var/www/webdav && mkdir -p /var/www/webdav/locks && chmod -R 777 /var/www/webdav/locks
ADD config/webdav.conf /etc/nginx/conf.d/webdav.conf
ADD sabre/index.php /var/www/webdav/index.php

# Sabre with composer
RUN cd /var/www/webdav && composer require sabre/dav ${SABRE_VERSION} && composer update sabre/dav && cd

# Add configuration files
ADD config/default.conf /workdir/default.conf
RUN rm -rf /etc/nginx/conf.d/default.conf && ln -s /volume/conf/default.conf /etc/nginx/conf.d/default.conf
RUN mv /etc/php/7.0/fpm/php.ini /tmp/php.ini

RUN mkdir /workdir/drupal-config && chmod 777 /workdir/drupal-config
ADD config/drupal-cache-config/* /workdir/drupal-config/

RUN mkdir /volume && chmod 777 /volume \
  && rm -rf /var/www/drupal/themes/ \
  && rm -rf /var/www/drupal/modules/ \
  && rm -rf /var/www/drupal/sites/default \
  && ln -s /volume/themes/ /var/www/drupal/themes \
  && ln -s /volume/modules/ /var/www/drupal/modules \
  && ln -s /volume/default/ /var/www/drupal/sites/default \
  && ln -s /volume/libraries/ /var/www/drupal/libraries \
  && rm -rf /var/www/drupal/robots.txt \
  && ln -s /volume/robots.txt /var/www/drupal/robots.txt \
  && ln -s /volume/conf/php.ini /etc/php/7.0/fpm/php.ini

ADD config/nginx.conf /etc/nginx/nginx.conf

VOLUME ["/volume"]

# Additional CA certificate bundle (Mozilla)
ADD mailchimp-ca.sh /workdir/mailchimp-ca.sh
RUN chmod a+x /workdir/mailchimp-ca.sh \
  && bash /workdir/mailchimp-ca.sh \
  && update-ca-certificates

# Install drush
RUN composer global require drush/drush:9.1.0

# Install latest APCu module
RUN mkdir -p /tmp/apcu-build \
  && cd /tmp/apcu-build \
  && git clone https://github.com/krakjoe/apcu \
  && cd apcu \
  && git checkout v5.1.9 \
  && phpize7.0 \
  && ./configure --with-php-config=/usr/bin/php-config7.0 \
  && make \
  && TEST_PHP_ARGS='-n' make test \
  && make install \
  && cd \
  && rm -rf /tmp/apcu-build

# Install jsmin php extension
RUN git clone -b feature/php7 https://github.com/sqmk/pecl-jsmin.git /workdir/pecl-jsmin \
  && cd /workdir/pecl-jsmin \
    && phpize \
    && ./configure \
    && make install clean \
    && cd .. \
  && touch /etc/php/7.0/cli/conf.d/20-jsmin.ini \
  && echo 'extension="jsmin.so"' >> /etc/php/7.0/cli/conf.d/20-jsmin.ini \
  && echo 'extension="jsmin.so"' >> /tmp/php.ini

# PHP max upload size
RUN sed -i '/upload_max_filesize/c\upload_max_filesize = 250M' /tmp/php.ini \
  && sed -i '/post_max_size/c\post_max_size = 250M' /tmp/php.ini

ADD entrypoint.sh /workdir/entrypoint.sh
RUN chown -R 104:0 /var/www \
  && chmod -R g+rw /var/www \
  && chmod a+x /workdir/entrypoint.sh \
  && chmod g+rw /workdir

EXPOSE 5000
EXPOSE 5005

USER 100104
