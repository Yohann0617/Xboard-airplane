FROM phpswoole/swoole:php8.1-alpine

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

RUN install-php-extensions pcntl bcmath inotify zip \ 
&& apk --no-cache add shadow supervisor nginx sqlite nginx-mod-http-brotli mysql-client git patch \
&& addgroup -S -g 1000 www && adduser -S -G www -u 1000 www 

# 设置工作目录
WORKDIR /www

# 设置 Composer 环境变量
ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1

# 复制配置文件
COPY .docker /

# 复制所有项目文件
COPY . /www

# 配置 Composer 允许的插件
RUN composer config --no-plugins allow-plugins.cweagans/composer-patches true

# 尝试安装依赖（如果 patches 失败，则禁用插件重试）
RUN composer install --optimize-autoloader --no-dev --no-interaction --prefer-dist --ignore-platform-reqs --no-scripts || \
    (echo "=== Installing without patches plugin ===" && \
     composer config --no-plugins allow-plugins.cweagans/composer-patches false && \
     composer install --optimize-autoloader --no-dev --no-interaction --prefer-dist --ignore-platform-reqs --no-scripts --no-plugins)

# 手动运行必要的脚本
RUN php artisan package:discover --ansi || true

# 创建 storage link（忽略错误）
RUN php artisan storage:link 2>/dev/null || true

# 确保 .env 文件存在
RUN if [ -f /www/.env.example ]; then cp -f /www/.env.example /www/.env; fi

# 设置文件权限
RUN chown -R www:www /www && chmod -R 775 /www

CMD ["/usr/bin/supervisord", "--nodaemon", "-c", "/etc/supervisor/supervisord.conf"]
