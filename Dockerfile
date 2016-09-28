FROM jubicoy/nginx-php:latest
ENV DRUPAL_VERSION 8.1.10

RUN apt-get update && \
    apt-get -y install php5-fpm php5-mysql php-apc \
    php5-imagick php5-imap php5-mcrypt php5-curl \
    php5-cli php5-gd php5-pgsql php5-sqlite \
    php5-common php-pear curl php5-json php5-redis php5-memcache \
    gzip netcat mysql-client wget

RUN curl -k https://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz | tar zx -C /var/www/
RUN mv /var/www/drupal-${DRUPAL_VERSION} /var/www/drupal
RUN cp -rf /var/www/drupal/sites/default /tmp/

# Composer for Sabre installation
ENV COMPOSER_VERSION 1.0.0-alpha11
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION}

# WebDAV configuration
RUN apt-get install -y apache2-utils
RUN mkdir -p /var/www/webdav && mkdir -p /var/www/webdav/locks && chmod -R 777 /var/www/webdav/locks
ADD config/webdav.conf /etc/nginx/conf.d/webdav.conf
ADD sabre/index.php /var/www/webdav/index.php

# Sabre with composer
RUN cd /var/www/webdav && composer require sabre/dav ~3.1.0 && composer update sabre/dav && cd

# Add configuration files
ADD config/default.conf /workdir/default.conf
RUN rm -rf /etc/nginx/conf.d/default.conf && ln -s /volume/conf/default.conf /etc/nginx/conf.d/default.conf
ADD entrypoint.sh /workdir/entrypoint.sh

RUN mkdir /volume && chmod 777 /volume
RUN rm -rf /var/www/drupal/themes/ && rm -rf /var/www/drupal/modules/ && rm -rf /var/www/drupal/sites/default
RUN ln -s /volume/themes/ /var/www/drupal/themes
RUN ln -s /volume/modules/ /var/www/drupal/modules
RUN ln -s /volume/default/ /var/www/drupal/sites/default
RUN chown -R 104:0 /var/www && chmod -R g+rw /var/www && \
    chmod a+x /workdir/entrypoint.sh && chmod g+rw /workdir

VOLUME ["/volume"]

# Additional CA certificate bundle (Mozilla)
ADD mailchimp-ca.sh /workdir/mailchimp-ca.sh
RUN chmod a+x /workdir/mailchimp-ca.sh && bash /workdir/mailchimp-ca.sh
RUN update-ca-certificates

# Install drush
ADD drush/drush_install.sh /workdir/drush_install.sh
RUN chmod a+x /workdir/drush_install.sh && bash /workdir/drush_install.sh

EXPOSE 5000
EXPOSE 5005

USER 104
