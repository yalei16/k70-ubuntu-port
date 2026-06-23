# Docker 构建环境

## 快速开始

```bash
# 构建镜像
docker-compose build

# 启动容器
docker-compose up -d

# 进入容器
docker-compose exec builder bash

# 在容器内编译
./build-local.sh v6.12 all
```

## 手动使用 Docker

```bash
# 构建镜像
docker build -t k70-ubuntu-builder .

# 运行容器
docker run -it --rm   -v $(pwd):/workspace   -v k70-ccache:/root/.ccache   --privileged   k70-ubuntu-builder

# 在容器内编译
./build-local.sh v6.12 kernel
```

## 优势

- 环境一致性：所有开发者使用相同环境
- 隔离性：不影响主机系统
- 可复现：GitHub Actions 和本地使用相同基础镜像
- 缓存持久化：ccache 数据保存在 Docker volume 中
