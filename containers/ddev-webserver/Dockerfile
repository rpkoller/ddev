### ---------------------------ddev-webserver-base--------------------------------
### Build ddev-php-base from ddev-webserver-base
### ddev-php-base is the basic of ddev-php-prod
### and ddev-webserver-* (For DDEV local Usage)
FROM ddev/ddev-php-base:v1.24.7 AS ddev-webserver-base
SHELL ["/bin/bash", "-eu","-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

ENV NGINX_SITE_TEMPLATE=/etc/nginx/nginx-site.conf
ENV APACHE_SITE_TEMPLATE=/etc/apache2/apache-site.conf
ENV TERMINUS_CACHE_DIR=/mnt/ddev-global-cache/terminus/cache
ENV CAROOT=/mnt/ddev-global-cache/mkcert

# TARGETPLATFORM is Docker buildx's target platform (e.g. linux/arm64), while
# BUILDPLATFORM is the platform of the build host (e.g. linux/amd64)
ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM
ARG DEFAULT_LOCALES="en_CA.UTF-8 UTF-8\nen_US.UTF-8 UTF-8\nen_GB.UTF-8 UTF-8\nes_ES.UTF-8 UTF-8\nes_MX.UTF-8 UTF-8\nde_DE.UTF-8 UTF-8\nde_AT.UTF-8 UTF-8\nfr_CA.UTF-8 UTF-8\nfr_FR.UTF-8 UTF-8\nja_JP.UTF-8 UTF-8\npt_PT.UTF-8 UTF-8\npt_BR.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8\n"

ADD ddev-webserver-etc-skel /
RUN /sbin/mkhomedir_helper www-data

# This curl is here to catch diagnostic information for sury.org
# failures, see https://github.com/oerdnj/deb.sury.org/issues/2046
RUN curl -I https://packages.sury.org/php/dists/bookworm/InRelease

# symfony cli
RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.deb.sh' | bash

# Install mariadb_repo_setup to get mariadb-client from them directly
RUN curl -LsSf https://r.mariadb.com/downloads/mariadb_repo_setup -o /usr/local/bin/mariadb_repo_setup && chmod +x /usr/local/bin/mariadb_repo_setup
# Search for CHANGE_MARIADB_CLIENT to update related code.
RUN mariadb_repo_setup --mariadb-server-version="mariadb-10.11" --skip-maxscale --skip-tools

# Set up Postgresql apt repository
RUN install -d /usr/share/postgresql-common/pgdg && curl -s -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc

RUN apt-get -qq update
RUN apt-get install -y postgresql-common && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

RUN DEBIAN_FRONTEND=noninteractive apt-get -qq install -y -o Dpkg::Options::="--force-confold" --no-install-recommends --no-install-suggests -y \
    bash-completion \
    gettext \
    git \
    graphviz \
    less \
    libcap2-bin \
    libldap-common \
    libmagickcore-6.q16-6-extra \
    locales \
    mariadb-client \
    openssh-client \
    patch \
    postgresql-client \
    pv \
    python-is-python3 \
    rsync \
    sqlite3 \
    supervisor \
    symfony-cli \
    unzip \
    vim-tiny \
    xz-utils \
    zip

RUN update-alternatives --install /usr/bin/vim vim /usr/bin/vim.tiny 10

RUN printf "${DEFAULT_LOCALES}" > /etc/locale.gen && locale-gen

# Arbitrary user needs to be able to bind to privileged ports (for nginx and apache2)
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/nginx
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/apache2

# magerun and magerun2 for magento
RUN curl --fail -sSL https://files.magerun.net/n98-magerun-latest.phar -o /usr/local/bin/magerun && chmod 777 /usr/local/bin/magerun
RUN curl --fail -sSL https://raw.githubusercontent.com/netz98/n98-magerun/develop/res/autocompletion/bash/n98-magerun.phar.bash -o /etc/bash_completion.d/n98-magerun.phar
RUN curl --fail -sSL https://files.magerun.net/n98-magerun2-latest.phar -o /usr/local/bin/magerun2 && chmod 777 /usr/local/bin/magerun2
RUN curl --fail -sSL https://raw.githubusercontent.com/netz98/n98-magerun2/develop/res/autocompletion/bash/n98-magerun2.phar.bash -o /etc/bash_completion.d/n98-magerun2.phar && chmod +x /usr/local/bin/magerun

RUN apt-get -qq autoremove && apt-get -qq clean -y && rm -rf /var/lib/apt/lists/* /tmp/*

ADD ddev-webserver-base-files /
ADD ddev-webserver-base-scripts /

# /usr/local/bin may need to be updated by start.sh, etc
RUN chmod -f ugo+rwx /usr/local/bin /usr/local/bin/composer

# Install older mariadb client and mariadb-dump into /usr/local/mariadb-old/bin
# to solve variety of problems with newer mariadb-dump.
RUN if [ "$(dpkg --print-architecture)" = "arm64" ]; then cd /tmp && curl -L -s --fail -O "https://dlm.mariadb.com/3607865/MariaDB/mariadb-10.11.6/repo/debian/pool/main/m/mariadb/mariadb-client_10.11.6+maria~deb12_arm64.deb" -O "https://dlm.mariadb.com/3607494/MariaDB/mariadb-10.11.6/repo/debian/pool/main/m/mariadb/mariadb-client-core_10.11.6+maria~deb12_arm64.deb"; fi
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then cd /tmp && curl -L -s --fail -O "https://dlm.mariadb.com/3607675/MariaDB/mariadb-10.11.6/repo/debian/pool/main/m/mariadb/mariadb-client_10.11.6+maria~deb12_amd64.deb" -O "https://dlm.mariadb.com/3607123/MariaDB/mariadb-10.11.6/repo/debian/pool/main/m/mariadb/mariadb-client-core_10.11.6+maria~deb12_amd64.deb"; fi
RUN set -x && cd /tmp && for item in *.deb; do dpkg-deb -x ${item} extracted; done
RUN mkdir -p /usr/local/mariadb-old/bin && cp -ap /tmp/extracted/usr/bin/{mariadb,mariadb-dump,mysql,mysqldump} /usr/local/mariadb-old/bin

### Drupal 11+ requires a minimum sqlite3 version (3.45 currently)
### TODO: When we have this from upstream Debian 13 Trixie, we must remove this stanza
ARG SQLITE_VERSION="3.45.1"
RUN mkdir -p /usr/local/sqlite3-drupal11 && cd /usr/local/sqlite3-drupal11 && \
    wget https://snapshot.debian.org/archive/debian/20240203T152533Z/pool/main/s/sqlite3/sqlite3_${SQLITE_VERSION}-1_${TARGETARCH}.deb && \
    wget https://snapshot.debian.org/archive/debian/20240203T152533Z/pool/main/s/sqlite3/libsqlite3-0_${SQLITE_VERSION}-1_${TARGETARCH}.deb

### -------------------------END ddev-webserver-base------------------------------

### -------------------------ddev-webserver-dev-base------------------------------
### Build ddev-webserver-dev-base from ddev-webserver-base
FROM ddev-webserver-base AS ddev-webserver-dev-base
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]

ENV CAROOT=/mnt/ddev-global-cache/mkcert
ENV PHP_DEFAULT_VERSION="8.3"

RUN curl -s --fail https://packages.blackfire.io/gpg.key > /usr/share/keyrings/blackfire-archive-keyring.asc
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/blackfire-archive-keyring.asc] http://packages.blackfire.io/debian any main" > /etc/apt/sources.list.d/blackfire.list
RUN apt-get -qq update

RUN DEBIAN_FRONTEND=noninteractive apt-get -qq install -o Dpkg::Options::="--force-confold" --no-install-recommends --no-install-suggests -y \
    blackfire \
    blackfire-php \
    fontconfig \
    iproute2 \
    iputils-ping \
    jq \
    libpcre3 \
    nano \
    ncurses-bin \
    netcat-traditional \
    sudo \
    telnet \
    tree

RUN curl --fail -JL -s -o /usr/local/bin/mkcert "https://dl.filippo.io/mkcert/latest?for=${TARGETPLATFORM}" && chmod +x /usr/local/bin/mkcert

# blackfire user by default is set up with /dev/null as homedir, and 999 as uid, which
# can break people. Use a real homedir
RUN mkdir -p /home/blackfire && chown blackfire:blackfire /home/blackfire && usermod -d /home/blackfire blackfire

ADD ddev-webserver-dev-base-files /
RUN phpdismod blackfire xdebug
RUN phpdismod xhprof

RUN set -x && set -o pipefail && tag=$(curl -L --fail --silent "https://api.github.com/repos/axllent/mailpit/releases/latest" | jq -r .tag_name) && curl --fail -sSL "https://github.com/axllent/mailpit/releases/download/${tag}/mailpit-linux-${TARGETARCH}.tar.gz" -o /tmp/mailpit.tar.gz && tar -zx -C /usr/local/bin -f /tmp/mailpit.tar.gz mailpit && rm /tmp/mailpit.tar.gz

RUN curl -sSL --fail --output /usr/local/bin/phive "https://phar.io/releases/phive.phar" && chmod 777 /usr/local/bin/phive
# Install terminus cli
RUN set -o pipefail && curl --fail -sSL https://github.com/pantheon-systems/terminus/releases/download/$(curl -L --fail --silent "https://api.github.com/repos/pantheon-systems/terminus/releases/latest" | perl -nle'print $& while m{"tag_name": "\K.*?(?=")}g')/terminus.phar --output /usr/local/bin/terminus && chmod 777 /usr/local/bin/terminus
# Install platform cli
RUN set -o pipefail && curl -fsSL https://raw.githubusercontent.com/platformsh/cli/main/installer.sh | bash
# Install upsun cli
RUN set -o pipefail && curl -fsSL https://raw.githubusercontent.com/platformsh/cli/main/installer.sh | VENDOR=upsun bash
# Install lagoon cli
RUN set -o pipefail && tag=$(curl -L --fail --silent "https://api.github.com/repos/uselagoon/lagoon-cli/releases/latest" | jq -r .tag_name) && curl --fail -sSL "https://github.com/uselagoon/lagoon-cli/releases/download/$tag/lagoon-cli-$tag-linux-${TARGETARCH}" --output /usr/local/bin/lagoon && chmod 777 /usr/local/bin/lagoon
# Install lagoon-sync
RUN set -x && set -o pipefail && tag=$(curl -L --fail --silent "https://api.github.com/repos/uselagoon/lagoon-sync/releases/latest" | jq -r .tag_name) && curl --fail -sSL "https://github.com/uselagoon/lagoon-sync/releases/download/${tag}/lagoon-sync_${tag:1}_linux_${TARGETARCH}" --output /usr/local/bin/lagoon-sync && chmod 777 /usr/local/bin/lagoon-sync

RUN mkdir -p "/opt/phpstorm-coverage" && \
    chmod a+rw "/opt/phpstorm-coverage"

RUN curl --fail -sSL --output /usr/local/bin/acli https://github.com/acquia/cli/releases/latest/download/acli.phar && chmod 777 /usr/local/bin/acli

RUN set -o pipefail && tag=$(curl -L --fail --silent "https://api.github.com/repos/backdrop-contrib/drush/releases/latest" | jq -r .tag_name) && curl --fail -sSL "https://github.com/backdrop-contrib/drush/releases/download/${tag}/backdrop-drush-extension.zip" -o /tmp/backdrop-drush-extension.zip && unzip -o /tmp/backdrop-drush-extension.zip -d /var/tmp/backdrop_drush_commands && chmod -R ugo+w /var/tmp/backdrop_drush_commands && rm /tmp/backdrop-drush-extension.zip

RUN mkdir -p /etc/nginx/sites-enabled /var/log/apache2 /var/run/apache2 /var/lib/apache2/module/enabled_by_admin /var/lib/apache2/module/disabled_by_admin && \
    touch /var/log/php-fpm.log && \
    chmod ugo+rw /var/log/php-fpm.log && \
    chmod ugo+rwx /var/run && \
    touch /var/log/nginx/access.log && \
    touch /var/log/nginx/error.log && \
    chmod -R ugo+rw /var/log/nginx/ && \
    chmod ugo+rwx /usr/local/bin/* && \
    ln -sf /usr/sbin/php-fpm${PHP_DEFAULT_VERSION} /usr/sbin/php-fpm

RUN chmod -R 777 /var/log

# we need to create the /var/cache/linux and /var/lib/nginx manually for the arm64 image and chmod them, please don't remove them!
RUN mkdir -p /mnt/ddev-global-cache/mkcert /run/{php,blackfire} /var/cache/nginx /var/lib/nginx && chmod -R ugo+rw /mnt/ddev-global-cache/

RUN chmod -fR ugo+w /usr/sbin /usr/bin /etc/nginx /var/cache/nginx /var/lib/nginx /run /var/www /etc/php/*/*/conf.d/ /var/lib/php/modules /etc/alternatives /usr/local/lib/node_modules /etc/php /etc/apache2 /var/log/apache2/ /var/run/apache2 /var/lib/apache2 /mnt/ddev-global-cache/*

RUN mkdir -p /var/xhprof && curl --fail  -o /tmp/xhprof.tgz -sSL https://pecl.php.net/get/xhprof && tar -zxf /tmp/xhprof.tgz --strip-components=1 -C /var/xhprof && chmod 777 /var/xhprof/xhprof_html && rm /tmp/xhprof.tgz

# Install https://github.com/perftools/php-profiler for XHGui
RUN COMPOSER_HOME=/tmp/composer composer global require perftools/php-profiler --dev && \
    mv /tmp/composer/vendor/perftools/php-profiler /usr/local/xhgui.collector/php-profiler && \
    rm -rf /tmp/composer && \
    chmod -R ugo+rw /usr/local/xhgui.collector

RUN touch /var/log/nginx/error.log /var/log/nginx/access.log /var/log/php-fpm.log && \
    chmod 666 /var/log/nginx/error.log /var/log/nginx/access.log /var/log/php-fpm.log

RUN a2dismod mpm_event
RUN a2enmod ssl headers expires

# scripts added last because they're most likely place to make changes, speeds up build
ADD ddev-webserver-base-scripts /
RUN chmod ugo+x /start.sh /healthcheck.sh

# Composer, etc may need to be updated by composer self-update
RUN chmod -f ugo+rwx /usr/local/bin /usr/local/bin/*

RUN chmod ugo+w /etc/ssl/certs /usr/local/share/ca-certificates

HEALTHCHECK --interval=1s --retries=120 --timeout=120s --start-period=120s CMD ["/healthcheck.sh"]
CMD ["/start.sh"]
RUN apt-get -qq clean -y && rm -rf /var/lib/apt/lists/* /tmp/*
RUN update-alternatives --set php /usr/bin/php${PHP_DEFAULT_VERSION}

### -------------------------END ddev-webserver-dev-base--------------------------

### -----------------------------ddev-webserver-----------------------------------
### This could be known as ddev-webserver-dev as it's development-env targeted
### But for historical reasons, it's just ddev-webserver
### Build ddev-webserver by turning ddev-webserver-dev-base into one layer
FROM scratch AS ddev-webserver
ENV PHP_DEFAULT_VERSION="8.3"
ENV NGINX_SITE_TEMPLATE=/etc/nginx/nginx-site.conf
ENV APACHE_SITE_TEMPLATE=/etc/apache2/apache-site.conf
ENV TERMINUS_CACHE_DIR=/mnt/ddev-global-cache/terminus/cache
ENV TERMINUS_HIDE_UPDATE_MESSAGE=1
ENV CAROOT=/mnt/ddev-global-cache/mkcert
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_CACHE_DIR=/mnt/ddev-global-cache/composer
ENV COMPOSER_PROCESS_TIMEOUT=2000
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm
ENV MH_SMTP_BIND_ADDR=127.0.0.1:1025
ENV BASH_ENV=/etc/bash.nointeractive.bashrc
ENV LANG=C.UTF-8
ENV XHPROF_OUTPUT_DIR=/tmp/xhprof
ENV PLATFORMSH_CLI_UPDATES_CHECK=0

COPY --from=ddev-webserver-dev-base / /
HEALTHCHECK --interval=1s --retries=120 --timeout=120s --start-period=120s CMD ["/healthcheck.sh"]
CMD ["/start.sh"]
### ----------------------------END ddev-webserver--------------------------------

### -------------------------ddev-webserver-prod-base-----------------------------
### Build ddev-webserver-prod-base from ddev-webserver-base
### This image is aimed at actual hardened production environments
FROM ddev-webserver-base AS ddev-webserver-prod-base
SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]

ENV CAROOT=/mnt/ddev-global-cache/mkcert
ENV PHP_DEFAULT_VERSION="8.3"
ARG TARGETPLATFORM
ARG TARGETARCH

RUN curl -s --fail https://packages.blackfire.io/gpg.key > /usr/share/keyrings/blackfire-archive-keyring.asc
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/blackfire-archive-keyring.asc] http://packages.blackfire.io/debian any main" > /etc/apt/sources.list.d/blackfire.list
RUN apt-get -qq update

# Blackfire outputs errors about not having systemd, but they do no harm to our usage
RUN DEBIAN_FRONTEND=noninteractive apt-get -qq install -o Dpkg::Options::="--force-confold" --no-install-recommends --no-install-suggests -y \
    blackfire-php 2>/dev/null

RUN curl --fail -JL -s -o /usr/local/bin/mkcert "https://dl.filippo.io/mkcert/latest?for=${TARGETPLATFORM}" && chmod +x /usr/local/bin/mkcert

ADD ddev-webserver-prod-files /
RUN phpdismod blackfire
RUN phpdismod xhprof

RUN set -o pipefail && tag=$(curl -L --fail --silent "https://api.github.com/repos/backdrop-contrib/drush/releases/latest" | jq -r .tag_name) && curl --fail -sSL "https://github.com/backdrop-contrib/drush/releases/download/${tag}/backdrop-drush-extension.zip" -o /tmp/backdrop-drush-extension.zip && unzip -o /tmp/backdrop-drush-extension.zip -d /var/tmp/backdrop_drush_commands && chmod -R ugo+w /var/tmp/backdrop_drush_commands && rm /tmp/backdrop-drush-extension.zip

RUN mkdir -p /etc/nginx/sites-enabled /var/lock/apache2 /var/log/apache2 /var/run/apache2 /var/lib/apache2/module/enabled_by_admin /var/lib/apache2/module/disabled_by_admin && \
    touch /var/log/php-fpm.log && \
    chmod ugo+rw /var/log/php-fpm.log && \
    chmod ugo+rwx /var/run && \
    touch /var/log/nginx/access.log && \
    touch /var/log/nginx/error.log && \
    chmod -R ugo+rw /var/log/nginx/ && \
    chmod ugo+rx /usr/local/bin/* && \
    ln -sf /usr/sbin/php-fpm${PHP_DEFAULT_VERSION} /usr/sbin/php-fpm

RUN chmod -R 777 /var/log

# we need to create the /var/cache/linux and /var/lib/nginx manually for the arm64 image and chmod them, please don't remove them!
RUN mkdir -p /mnt/ddev-global-cache/mkcert /run/php /var/cache/nginx /var/lib/nginx && chmod -R ugo+rw /home /mnt/ddev-global-cache/

RUN chmod -fR ugo+w /usr/sbin /usr/bin /etc/nginx /var/cache/nginx /var/lib/nginx /run /var/www /etc/php/*/*/conf.d/ /var/lib/php/modules /etc/alternatives /usr/local/lib/node_modules /etc/php /etc/apache2 /var/lock/apache2 /var/log/apache2/ /var/run/apache2 /var/lib/apache2 /mnt/ddev-global-cache/*

RUN touch /var/log/nginx/error.log /var/log/nginx/access.log /var/log/php-fpm.log && \
    chmod 666 /var/log/nginx/error.log /var/log/nginx/access.log /var/log/php-fpm.log

RUN a2dismod mpm_event
RUN a2enmod ssl headers expires

# scripts added last because they're most likely place to make changes, speeds up build
ADD ddev-webserver-prod-scripts /
RUN chmod ugo+x /start.sh /healthcheck.sh

RUN /sbin/mkhomedir_helper www-data

RUN chmod ugo+w /etc/ssl/certs /usr/local/share/ca-certificates

HEALTHCHECK --interval=1s --retries=120 --timeout=120s --start-period=120s CMD ["/healthcheck.sh"]
CMD ["/start.sh"]
RUN apt-get -qq clean -y && rm -rf /var/lib/apt/lists/* /tmp/*
RUN update-alternatives --set php /usr/bin/php${PHP_DEFAULT_VERSION}

### -----------------------END ddev-webserver-prod-base---------------------------

### ---------------------------ddev-webserver-prod--------------------------------
### Build ddev-webserver-prod, the hardened version of ddev-webserver-base
### (Withut dev features, single layer)
FROM scratch AS ddev-webserver-prod
ENV PHP_DEFAULT_VERSION="8.3"
ENV NGINX_SITE_TEMPLATE=/etc/nginx/nginx-site.conf
ENV APACHE_SITE_TEMPLATE=/etc/apache2/apache-site.conf
ENV TERMINUS_CACHE_DIR=/mnt/ddev-global-cache/terminus/cache
ENV TERMINUS_HIDE_UPDATE_MESSAGE=1
ENV CAROOT=/mnt/ddev-global-cache/mkcert
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_CACHE_DIR=/mnt/ddev-global-cache/composer
ENV COMPOSER_PROCESS_TIMEOUT=2000
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV TERM=xterm
ENV BASH_ENV=/etc/bash.nointeractive.bashrc
ENV PLATFORMSH_CLI_UPDATES_CHECK=0

COPY --from=ddev-webserver-prod-base / /
HEALTHCHECK --interval=1s --retries=120 --timeout=120s --start-period=120s CMD ["/healthcheck.sh"]
CMD ["/start.sh"]
### -------------------------END ddev-webserver-prod------------------------------
