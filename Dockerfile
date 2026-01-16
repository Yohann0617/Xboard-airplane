FROM phpswoole/swoole:php8.1-alpine

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# 设置工作目录
WORKDIR /www

# 设置 Composer 环境变量
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1

# 复制配置文件
COPY .docker /

# 复制所有项目文件
COPY . /www

# 安装依赖、配置 Composer、安装包、运行命令、设置权限（一次性完成）
RUN set -eux; \
    install-php-extensions pcntl bcmath inotify zip; \
    apk --no-cache add shadow supervisor nginx sqlite nginx-mod-http-brotli mysql-client git patch; \
    addgroup -S -g 1000 www; \
    adduser -S -G www -u 1000 www; \
    composer config --no-plugins allow-plugins.cweagans/composer-patches true; \
    composer config audit.block-insecure false; \
    composer install --optimize-autoloader --no-dev --no-interaction --prefer-dist --ignore-platform-reqs --no-scripts; \
    php artisan package:discover --ansi || true; \
    php artisan storage:link 2>/dev/null || true; \
    if [ -f /www/.env.example ]; then cp -f /www/.env.example /www/.env; fi; \
    chown -R www:www /www; \
    chmod -R 775 /www; \
    rm -rf /tmp/* /var/cache/apk/* /root/.composer/cache

CMD ["/usr/bin/supervisord", "--nodaemon", "-c", "/etc/supervisor/supervisord.conf"]
