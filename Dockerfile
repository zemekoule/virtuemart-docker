ARG JOOMLA_TAG=5
ARG PHP_VERSION=8.3
FROM joomla:${JOOMLA_TAG}-php${PHP_VERSION}-apache

ARG ARG_UID=1000
ARG ARG_GID=1000

# Build tools potřebné pro pecl install, pak je smažeme
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
      $PHPIZE_DEPS \
      zip unzip \
      default-mysql-client \
      less mc bash-completion \
  && pecl install xdebug \
  && docker-php-ext-enable xdebug \
  && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
  && composer completion bash > /root/.composer-completion.bash \
  && apt-get purge -y --auto-remove $PHPIZE_DEPS \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Sjednocení UID/GID s hostitelem (aby soubory v ./src/ a ./modules/ měly správného vlastníka)
RUN userdel -f www-data \
  && if getent group www-data ; then groupdel www-data; fi \
  && groupadd -g ${ARG_GID} www-data \
  && useradd -l -u ${ARG_UID} -g www-data -d /home/www-data -s /bin/bash www-data \
  && install -d -m 0755 -o www-data -g www-data /home/www-data

# Bash niceties
RUN echo 'alias ll="ls -la"' >> /etc/bash.bashrc \
  && echo 'alias lla="ls -la"' >> /etc/bash.bashrc \
  && echo '[[ $BASH_VERSION ]] && . /usr/share/bash-completion/bash_completion' >> /etc/bash.bashrc \
  && cp /root/.composer-completion.bash /home/www-data/.composer-completion.bash \
  && echo 'source ~/.composer-completion.bash' >> /home/www-data/.bashrc \
  && chown www-data:www-data /home/www-data/.composer-completion.bash /home/www-data/.bashrc
