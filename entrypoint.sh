#!/bin/bash
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
envsubst < /workdir/passwd.template > /tmp/passwd
export LD_PRELOAD=libnss_wrapper.so
export NSS_WRAPPER_PASSWD=/tmp/passwd
export NSS_WRAPPER_GROUP=/etc/group

if [ ! -d /volume/themes ]; then
  mkdir -p /volume/themes
fi

if [ ! -d /volume/modules ]; then
  mkdir -p /volume/modules
fi

if [ ! -d /volume/default ]; then
  cp -rf /tmp/default/ /volume/
  cp /volume/default/default.settings.php /volume/default/settings.php
fi

# Move Nginx configuration if does not exist
if [ ! -f /volume/conf/default.conf ]; then
    # Move Nginx configuration to volume
    mkdir -p /volume/conf/
    mv /workdir/default.conf /volume/conf/default.conf
fi

if [ ! -f /tmp/dav_auth ]; then
  # Create WebDAV Basic auth user
  echo ${DAV_PASS}|htpasswd -i -c /tmp/dav_auth ${DAV_USER}
fi

exec "/usr/bin/supervisord"
