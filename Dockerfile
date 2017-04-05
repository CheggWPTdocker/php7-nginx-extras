FROM alpine:edge
MAINTAINER jgilley@chegg.com

ENV APP_ENV DEVELOPMENT
ENV php_ini_dir /etc/php7/conf.d
ENV tideways_ext_version 4.0.7
ENV tideways_php_version 2.0.14
ENV tideways_dl https://github.com/tideways/

# if edge libraries are needed use the following:
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

RUN apk update

RUN	apk add \
	--virtual .basic_package ca-certificates supervisor

RUN	apk add \
	--virtual .redis_package hiredis

RUN apk add \
	--virtual .nginx_package nginx

RUN	apk add \
	--virtual .php7_package \
		mysql-client \
		php7 \
		php7-apcu \
		php7-bcmath \
		php7-bz2 \
		php7-ctype \
		php7-curl \
		php7-dev \
		php7-dom \
		php7-fpm \
		php7-gd \
		php7-gettext \
		php7-gmp \
		php7-iconv \
		php7-intl \
		php7-json \
		php7-mbstring \
		php7-memcached \
		php7-mcrypt \
		php7-mysqli \
		php7-openssl \
		php7-pdo \
		php7-pdo_dblib \
		php7-pdo_mysql \
		php7-pdo_pgsql \
		php7-pdo_sqlite \
		php7-phar \
		php7-redis \
		php7-soap \
		php7-sqlite3 \
		php7-session \
		php7-tidy \
		php7-xmlreader \
		php7-xmlrpc \
		php7-zip

RUN	apk add \
	--virtual .build_package \
		git curl file build-base autoconf

RUN apk add \
	--virtual .build_libraries \
		pcre-dev \
		libmemcached-dev \
		zlib-dev \
		php7-dev

# cleanup apk cache and update certificates
RUN	rm -rf /var/cache/apk/* && \
	update-ca-certificates

# Add the www-data user and group, fail on error
RUN set -x ; \
	addgroup -g 82 -S www-data ; \
	adduser -u 82 -D -S -G www-data www-data && exit 0 ; exit 1

# dont display errors 	sed -i -e 's/display_errors = Off/display_errors = On/g' /etc/php7/php.ini && \
# fix path off
# error log becomes stderr
# Enable php-fpm on nginx virtualhost configuration
RUN	sed -i -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php7/php.ini && \
	sed -i -e 's/;error_log = php_errors.log/error_log = \/proc\/self\/fd\/1/g' /etc/php7/php.ini


# Add the files
COPY container_confs /

# Remove the default nginx config
# Add the process control dirs for php, nginx, and supervisord
# configure permissions and owners for directories
RUN rm -rf /etc/nginx/conf.d/default.conf && \
	mkdir -p /run/php /run/nginx /run/supervisord /webroot && \
	mv /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh && \
	chmod +x /entrypoint.sh /wait-for-it.sh /etc/profile /etc/profile.d/*.sh && \
	chown -R nginx:www-data /run/nginx && \
	chown -R www-data:www-data /run/php && \
	chown -R www-data:www-data /webroot && \
	chmod -R ug+rw /webroot

#
# BUILD PHP Extensions
#

# Build & install ext/tideways & Tideways.php
RUN cd /tmp && \
	curl -L "${tideways_dl}/php-profiler-extension/archive/v${tideways_ext_version}.zip" \
    --output "/tmp/v${tideways_ext_version}.zip" && \
	cd /tmp && unzip "v${tideways_ext_version}.zip" && \
	cd "php-profiler-extension-${tideways_ext_version}" && \
	phpize && \
	./configure && \
	make && make install && \
	echo 'extension=tideways.so' > "${php_ini_dir}/22_tideways.ini" && \
    curl -L "${tideways_dl}/profiler/releases/download/v${tideways_php_version}/Tideways.php" \
	--output "$(php-config --extension-dir)/Tideways.php" && \
    ls -l "$(php-config --extension-dir)/Tideways.php"


# Build & install phpiredis
# RUN cd /tmp && \
#	git clone https://github.com/nrk/phpiredis.git phpiredis && \
#	cd phpiredis && \
#	phpize && \
#	./configure && \
#	make && make install && \
#	echo 'extension=phpiredis.so' > "${php_ini_dir}/33_phpiredis.ini"

# Build & install php7_memcache
# RUN cd /tmp && \
#	curl -fsSL 'https://github.com/websupport-sk/pecl-memcache/archive/NON_BLOCKING_IO_php7.zip' \
#	--output /tmp/memcache.zip && \
#	unzip memcache.zip && \
#	cd /tmp/pecl-memcache-NON_BLOCKING_IO_php7 && \
#	phpize && \
#	./configure --enable-memcache && \
#	make && make install && \
#	echo 'extension=memcache.so' > "${php_ini_dir}/35_memcache.ini"

# Build & install php7_apcu
# RUN cd /tmp && \
#	curl -fsSL 'http://pecl.php.net/get/apcu-5.1.8.tgz' \
#	--output /tmp/apcu.tgz && \
#	tar -zxvf apcu.tgz && \
#	cd /tmp/apcu-5.1.8 && \
#	phpize && \
#	./configure --enable-memcache && \
#	make && make install && \
#	echo 'extension=apcu.so' > "${php_ini_dir}/35_apcu.ini"

# report info
RUN php -m && php --ini

# cleanup temp dir
RUN	rm -rf /tmp/*

# the entry point definition
ENTRYPOINT ["/entrypoint.sh"]

# default command for entrypoint.sh
CMD ["supervisor"]
