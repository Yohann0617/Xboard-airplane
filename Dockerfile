FROM phpswoole/swoole:php8.1-alpine

# 复制 PHP 扩展安装器
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# 安装系统依赖和 PHP 扩展
RUN set -eux; \
    install-php-extensions pcntl bcmath inotify zip; \
    apk --no-cache add \
        shadow \
        supervisor \
        nginx \
        sqlite \
        nginx-mod-http-brotli \
        mysql-client \
        git \
        patch \
        tzdata; \
    addgroup -S -g 1000 www; \
    adduser -S -G www -u 1000 www; \
    rm -rf /tmp/* /var/cache/apk/*

# 设置工作目录
WORKDIR /www

# 设置环境变量
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1 \
    TZ=Asia/Shanghai

# 先复制 composer 文件（利用 Docker 缓存）
COPY composer.json composer.lock* /www/
COPY patches /www/patches/

# 配置 Composer 并安装依赖
RUN set -eux; \
    composer config --no-plugins allow-plugins.cweagans/composer-patches true; \
    composer config audit.block-insecure false; \
    composer install \
        --optimize-autoloader \
        --no-dev \
        --no-interaction \
        --prefer-dist \
        --ignore-platform-reqs \
        --no-scripts \
        --no-autoloader; \
    rm -rf /root/.composer/cache

# 复制配置文件和项目文件
COPY .docker /
COPY . /www

# 完成 Composer 安装并执行 Laravel 命令
RUN set -eux; \
    composer dump-autoload --optimize --no-dev; \
    php artisan package:discover --ansi || true; \
    php artisan storage:link 2>/dev/null || true; \
    [ -f /www/.env.example ] && cp -f /www/.env.example /www/.env || true; \
    chown -R www:www /www; \
    chmod -R 775 /www/storage /www/bootstrap/cache

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD php artisan --version || exit 1

# 暴露端口
EXPOSE 80 443

CMD ["/usr/bin/supervisord", "--nodaemon", "-c", "/etc/supervisor/supervisord.conf"]
