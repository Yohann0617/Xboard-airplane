.PHONY: help build build-multi run stop clean logs shell test

# 变量定义
IMAGE_NAME ?= xboard
IMAGE_TAG ?= latest
CONTAINER_NAME ?= xboard-app
PLATFORM ?= linux/amd64

# 颜色输出
GREEN  := \033[0;32m
YELLOW := \033[0;33m
NC     := \033[0m

help: ## 显示帮助信息
	@echo "$(GREEN)XBoard Docker 管理命令:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

build: ## 构建 Docker 镜像（单阶段）
	@echo "$(GREEN)构建镜像: $(IMAGE_NAME):$(IMAGE_TAG)$(NC)"
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

build-multi: ## 构建 Docker 镜像（多阶段优化版）
	@echo "$(GREEN)构建多阶段镜像: $(IMAGE_NAME):$(IMAGE_TAG)$(NC)"
	docker build -f Dockerfile.multistage -t $(IMAGE_NAME):$(IMAGE_TAG) .

build-platform: ## 构建指定平台的镜像
	@echo "$(GREEN)构建镜像 [$(PLATFORM)]: $(IMAGE_NAME):$(IMAGE_TAG)$(NC)"
	docker buildx build --platform $(PLATFORM) -t $(IMAGE_NAME):$(IMAGE_TAG) . --load

build-push: ## 构建并推送镜像到仓库
	@echo "$(GREEN)构建并推送镜像: $(IMAGE_NAME):$(IMAGE_TAG)$(NC)"
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_NAME):$(IMAGE_TAG) . --push

run: ## 运行容器
	@echo "$(GREEN)启动容器: $(CONTAINER_NAME)$(NC)"
	docker run -d \
		--name $(CONTAINER_NAME) \
		-p 80:80 \
		-p 443:443 \
		-v $(PWD)/storage:/www/storage \
		-v $(PWD)/.env:/www/.env \
		--restart unless-stopped \
		$(IMAGE_NAME):$(IMAGE_TAG)

stop: ## 停止容器
	@echo "$(YELLOW)停止容器: $(CONTAINER_NAME)$(NC)"
	docker stop $(CONTAINER_NAME) || true
	docker rm $(CONTAINER_NAME) || true

restart: stop run ## 重启容器

logs: ## 查看容器日志
	docker logs -f $(CONTAINER_NAME)

shell: ## 进入容器 shell
	docker exec -it $(CONTAINER_NAME) /bin/sh

shell-root: ## 以 root 用户进入容器
	docker exec -u root -it $(CONTAINER_NAME) /bin/sh

clean: stop ## 清理容器和镜像
	@echo "$(YELLOW)清理镜像: $(IMAGE_NAME):$(IMAGE_TAG)$(NC)"
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true

clean-all: clean ## 清理所有相关资源
	@echo "$(YELLOW)清理所有构建缓存$(NC)"
	docker builder prune -f

inspect: ## 查看镜像信息
	docker image inspect $(IMAGE_NAME):$(IMAGE_TAG)

size: ## 查看镜像大小
	@docker images $(IMAGE_NAME):$(IMAGE_TAG) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

ps: ## 查看运行中的容器
	docker ps -f name=$(CONTAINER_NAME)

test: ## 测试容器健康状况
	@echo "$(GREEN)测试容器健康状况$(NC)"
	docker exec $(CONTAINER_NAME) php artisan --version
	docker exec $(CONTAINER_NAME) php -v

composer-install: ## 在容器中运行 composer install
	docker exec $(CONTAINER_NAME) composer install --optimize-autoloader

artisan: ## 在容器中运行 artisan 命令 (使用: make artisan CMD="migrate")
	docker exec $(CONTAINER_NAME) php artisan $(CMD)

# 快捷命令
dev: build run logs ## 开发模式：构建、运行、查看日志
prod: build-multi run ## 生产模式：多阶段构建并运行
