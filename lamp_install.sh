#!/bin/bash

install() {
    local url=$1
    local filename=$2

    wget $url
    tar -xzvf $filename
    rm -rf $filename
}

make_and_leave() {
    make
    make install
    cd ..
}

# versions of each package are taken from cli arguments
# for now only works with sudo
if [ "$#" -ne 3 ]; then
    echo "Usage: sudo $0 <apache_ver> <mariadb_ver> <php_ver>"
    exit 1
fi

# check if the script is being run with sudo
if [ $(id -u) -ne 0 ]; then
    echo "Error: Make sure that the script is run with sudo."
    exit 1
fi

APACHE_VER=$1
MARIADB_VER=$2
PHP_VER=$3

# main installation links
APACHE_INSTALL="https://archive.apache.org/dist/httpd/httpd-${APACHE_VER}.tar.gz"
MARIADB_INSTALL="https://archive.mariadb.org//mariadb-${MARIADB_VER}/source/mariadb-${MARIADB_VER}.tar.gz"
PHP_INSTALL="https://www.php.net/distributions/php-${PHP_VER}.tar.gz"

#extra installation links
APR_INSTALL="https://dlcdn.apache.org//apr/apr-1.7.4.tar.gz"
APRUTIL_INSTALL="https://dlcdn.apache.org//apr/apr-util-1.6.3.tar.gz"
PCRE_INSTALL="https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz"
EXPAT_INSTALL="https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.gz"

# check if necessary tools are installed, if not then install
apt-get update
apt-get install -y wget

# verify the versions
# for testing: apache 2.4.59, mariadb 11.3.2 php 8.3.6 
if ! wget --spider -q "https://archive.apache.org/dist/httpd/httpd-${APACHE_VER}.tar.gz"; then
    echo "Error: APACHE version ${APACHE_VER} does not exist b"
    exit 2
fi

if ! wget --spider -q "https://archive.mariadb.org//mariadb-${MARIADB_VER}/source/mariadb-${MARIADB_VER}.tar.gz"; then
    echo "Error: MariaDB version ${MARIADB_VER} does not exist"
    exit 2
fi

if ! wget --spider -q "https://www.php.net/distributions/php-${PHP_VER}.tar.gz"; then
    echo "Error: PHP version ${PHP_VER} does not exist"
    exit 3
fi

apt-get install -y build-essential libtool autoconf re2c pkg-config

# APACHE
# from the official documentation https://httpd.apache.org/docs/2.4/install.html
install $APACHE_INSTALL "httpd-${APACHE_VER}.tar.gz"

cd httpd-${APACHE_VER}

# download APR and APR-util inside srclib/ as per documentation
cd srclib/

install $APR_INSTALL "apr-1.7.4.tar.gz"

install $APRUTIL_INSTALL "apr-util-1.6.3.tar.gz"

mv apr-1.7.4 apr
mv apr-util-1.6.3 apr-util

cd ..
cd ..

# install PCRE
install $PCRE_INSTALL "pcre-8.45.tar.gz"

cd pcre-8.45

./configure --prefix=/opt/pcre

make_and_leave

# install expat
install $EXPAT_INSTALL "expat-2.6.2.tar.gz"

cd expat-2.6.2

./configure --prefix=/opt/expat

make_and_leave

cd httpd-${APACHE_VER}

./configure --prefix=/opt/apache --with-pcre=/opt/pcre/bin/pcre-config --with-expat=/opt/expat

make_and_leave

# deploy and test

/opt/apache/bin/apachectl -k start

if curl -s http://localhost/ | grep -q "<html>" ; then
    echo "successfully deployed apache server"
    rm -rf httpd-${APACHE_VER} pcre-8.45 expat-2.6.2
else
    echo "Error: Apache server was not deployed"
    exit 5
fi

/opt/apache/bin/apachectl -k stop

# MARIADB

# dependencies for mariadb
apt build-dep -y mariadb-server

install $MARIADB_INSTALL "mariadb-${MARIADB_VER}.tar.gz"

cd mariadb-${MARIADB_VER}

mkdir build-mariadb
cd build-mariadb

cmake .. --install-prefix=/opt/mariadb

make_and_leave

cd ..

mkdir -p /opt/mariadb/data
useradd -r mariadb
chown -R mariadb /opt/mariadb

printf "[mariadbd]\ndatadir=/opt/mariadb/data\n" > /opt/mariadb/my.cnf

/opt/mariadb/scripts/mariadb-install-db --user=mariadb --datadir=/opt/mariadb/data
/opt/mariadb/bin/mariadbd-safe --defaults-file=/opt/mariadb/my.cnf --user=mariadb &

sleep 10

echo "SELECT 1;" | /opt/mariadb/bin/mariadb -u root
if [ $? -eq 0 ]; then
    echo "successfully connected to MariaDB as root."
    rm -rf mariadb-${MARIADB_VER}
else
    echo "Error: failed to connect to MariaDB as root."
    exit 6
fi

# PHP
install $PHP_INSTALL "php-${PHP_VER}.tar.gz"

cd php-${PHP_VER}

./configure --prefix=/opt/php --with-apxs2=/opt/apache/bin/apxs --with-pdo-mysql --without-sqlite3  --without-pdo-sqlite

make_and_leave

# check php version
if /opt/php/bin/php -v | grep -q "${PHP_VER}" ; then
    echo "php successfully installed"
    rm -rf php-${PHP_VER}
else
    echo "Error: php was not installed correctly"
    exit 7
fi

echo "AddType application/x-httpd-php .php" >> /opt/apache/conf/httpd.conf
echo "<?php phpinfo();" > /opt/apache/htdocs/info.php

/opt/apache/bin/apachectl -k start

if curl -s http://localhost/info.php | grep -q "<table>" ; then
    echo "successfully attached php to apache"
else
    echo "Error: php was not attached to apache"
    exit 8
fi

/opt/apache/bin/apachectl -k stop

echo "LAMP stack was successfully installed!"
