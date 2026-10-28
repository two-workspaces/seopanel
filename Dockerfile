# Seo Panel on PHP 8.3 and Apache. The official image is PHP 8.1.0 with the web
# installer; this one installs and upgrades the database itself on boot and runs the
# report and site-auditor crons.
FROM php:8.3-apache-trixie

RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends libfreetype-dev libjpeg62-turbo-dev libpng-dev libzip-dev; \
	docker-php-ext-configure gd --with-freetype --with-jpeg; \
	docker-php-ext-install -j"$(nproc)" gd mysqli zip; \
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	find /usr/local -type f -name '*.so*' -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u | xargs -r dpkg-query --search | cut -d: -f1 | sort -u | xargs -rt apt-mark manual; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	apt-get install -y --no-install-recommends mariadb-client; \
	rm -rf /var/lib/apt/lists/*

# The code stays in the image, owned by root; only tmp/ (sitemaps, CSV imports) is
# the web server's. The database is all the state there is.
# upgrade: github seopanel/Seo-Panel
ARG SEOPANEL_VERSION=6.0.0
RUN set -eux; \
	curl -fsSL "https://github.com/seopanel/Seo-Panel/archive/refs/tags/${SEOPANEL_VERSION}.tar.gz" \
		| tar -xz -C /var/www/html --strip-components=1 --no-same-owner; \
	rm -rf /var/www/html/docker-compose.yml /var/www/html/sample_env /var/www/html/data/test.php; \
	chmod 755 /var/www/html; chown -R www-data: /var/www/html/tmp
ENV SEOPANEL_VERSION=${SEOPANEL_VERSION}

RUN { cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini; \
	printf '%s\n' 'memory_limit = 256M' 'upload_max_filesize = 32M' 'post_max_size = 32M' \
		'max_execution_time = 300' 'expose_php = Off' > /usr/local/etc/php/conf.d/seopanel.ini; }

# Apache on Railway's $PORT, IPv6 and IPv4. Errors go to stdout: Railway paints all of
# stderr red, including Apache's startup notices.
ENV PORT=8080
RUN set -eux; \
	printf 'Listen [::]:${PORT}\nListen 0.0.0.0:${PORT}\n' > /etc/apache2/ports.conf; \
	ln -sfT /dev/stdout /var/log/apache2/error.log; \
	sed -i 's/^ServerTokens OS/ServerTokens Prod/; s/^ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf; \
	printf '%s\n' 'RemoteIPHeader X-Real-IP' 'RemoteIPInternalProxy 100.64.0.0/10' > /etc/apache2/conf-available/remoteip.conf; \
	a2enmod remoteip rewrite >/dev/null; a2enconf remoteip >/dev/null
COPY seopanel.conf /etc/apache2/sites-available/000-default.conf
COPY sp-setup.php /usr/local/share/seopanel/
RUN echo ok > /usr/local/share/seopanel/healthz
COPY --chmod=0755 railway-entrypoint.sh /railway-entrypoint.sh
WORKDIR /var/www/html
ENTRYPOINT ["/railway-entrypoint.sh"]
STOPSIGNAL SIGTERM
