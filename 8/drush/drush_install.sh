#!/bin/bash
wget http://files.drush.org/drush.phar

chmod +x drush.phar
mv drush.phar /usr/local/bin/drush

yes | drush init
