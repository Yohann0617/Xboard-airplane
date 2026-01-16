FROM phpswoole/swoole:php8.1-alpine

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions pcntl bcmath inotify \ 
&& apk --no-cache add shadow supervisor nginx sqlite nginx-mod-http-brotli mysql-client git patch \
&& addgroup -S -g 1000 www && adduser -S -G www -u 1000 www 

#复制项目文件以及配置文件
WORKDIR /www
COPY .docker /
COPY . /www

# 设置 Composer 环境变量并安装依赖
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1

RUN set -ex \
    && composer install --optimize-autoloader --no-cache --no-dev --no-interaction --prefer-dist \
    && (php artisan storage:link || echo "Storage link already exists or failed, continuing...") \
    && cp -f /www/.env.example /www/.env \
    && chown -R www:www /www \
    && chmod -R 775 /www

CMD ["/usr/bin/supervisord", "--nodaemon", "-c", "/etc/supervisor/supervisord.conf"]
