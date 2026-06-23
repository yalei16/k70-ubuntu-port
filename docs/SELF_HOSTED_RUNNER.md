# 自托管 GitHub Actions Runner 配置

## 为什么需要自托管 Runner？

GitHub 免费提供的 runner 有以下限制：
- **2 核 CPU / 7GB 内存** — 编译 ARM64 内核非常慢
- **单次运行 6 小时限制** — 完整编译可能超时
- **无 ARM64 原生环境** — 需要 QEMU 模拟，效率低
- **存储限制 14GB** — 内核源码 + 编译产物可能超出

自托管 Runner 优势：
- 使用你的 HX90G 主机（x86_64，但可交叉编译）
- 或树莓派 5 / ARM64 服务器（原生编译）
- 无时间限制
- 可缓存编译结果

## 方案一：在你的 HX90G 上部署 Runner（推荐）

### 1. 下载 Runner

```bash
# 创建目录
mkdir -p ~/actions-runner && cd ~/actions-runner

# 下载最新版 Runner（x64）
curl -o actions-runner-linux-x64-2.321.0.tar.gz   -L https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz

# 解压
tar xzf ./actions-runner-linux-x64-2.321.0.tar.gz
```

### 2. 配置 Runner

在 GitHub 仓库页面：
- Settings → Actions → Runners → New self-hosted runner
- 选择 Linux → x64
- 复制配置命令（包含 token）

```bash
# 配置（替换 URL 和 TOKEN）
./config.sh --url https://github.com/YOUR_USERNAME/k70-ubuntu-port   --token YOUR_TOKEN   --name hx90g-k70-builder   --labels k70-builder,arm64-compile   --work _work
```

### 3. 安装为系统服务

```bash
sudo ./svc.sh install
sudo ./svc.sh start

# 查看状态
sudo systemctl status actions.runner.*
```

### 4. 安装编译依赖

```bash
sudo apt update
sudo apt install -y   build-essential crossbuild-essential-arm64   device-tree-compiler git bc bison flex   libncurses-dev libssl-dev   abootimg fastboot adb   python3 python3-pip   ccache ninja-build cmake   qemu-user-static qemu-system-arm   debootstrap binfmt-support

# 配置 ccache
ccache --max-size=20G
```

### 5. 修改工作流使用自托管 Runner

编辑 `.github/workflows/main.yml`：

```yaml
jobs:
  build-kernel:
    # 使用自托管 runner
    runs-on: [self-hosted, k70-builder]
    # 或同时使用 GitHub runner 作为备用
    # runs-on: ubuntu-24.04
```

## 方案二：混合策略（推荐配置）

```yaml
jobs:
  # 快速检查 — 使用 GitHub runner（免费）
  dts-check:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Check DTS syntax
        run: dtc -I dts -O dtb dts/sm8550-xiaomi-vermeer.dts

  # 完整编译 — 使用自托管 runner
  build-kernel:
    needs: dts-check
    runs-on: [self-hosted, k70-builder]
    timeout-minutes: 360  # 6小时，自托管无限制
    steps:
      - uses: actions/checkout@v4
      # ... 编译步骤

  # EDK2 编译 — 使用自托管（需要大量内存）
  build-edk2:
    needs: dts-check
    runs-on: [self-hosted, k70-builder]
    steps:
      # ... EDK2 编译
```

## 方案三：使用 GitHub Large Runner（付费）

如果愿意付费，GitHub 提供：
- 4 核 / 16GB — $0.016/分钟
- 8 核 / 32GB — $0.032/分钟
- 16 核 / 64GB — $0.064/分钟

配置：
```yaml
runs-on: ubuntu-latest-4-cores  # 或 8-cores, 16-cores
```

## Runner 缓存策略

### ccache 持久化

```bash
# 在 runner 上创建持久化缓存目录
sudo mkdir -p /var/cache/ccache-k70
sudo chown runner:runner /var/cache/ccache-k70

# 配置工作流
- name: Setup ccache
  uses: hendrikmuhs/ccache-action@v1.2
  with:
    key: k70-kernel
    path: /var/cache/ccache-k70
    max-size: 20G
```

### 源码缓存

```yaml
- name: Cache kernel source
  uses: actions/cache@v4
  with:
    path: build/linux-src
    key: linux-src-${{ env.KERNEL_VERSION }}
```

## 安全注意事项

自托管 runner 执行仓库代码，存在安全风险：

1. **仅用于私有仓库或受信任的 PR**
2. **禁用 fork PR 的自动执行**
   ```yaml
   on:
     pull_request:
       branches: [main]
   ```
   配合 Settings → Actions → Fork pull request workflows

3. **使用隔离环境**
   ```bash
   # 在 Docker 容器中运行
   runs-on: [self-hosted, k70-builder]
   container:
     image: ubuntu:24.04
     volumes:
       - /var/cache/ccache-k70:/ccache
   ```

4. **定期清理工作目录**
   ```bash
   # 添加到 crontab
   0 2 * * * rm -rf ~/actions-runner/_work/*
   ```

## 监控 Runner 状态

```bash
# 查看 runner 日志
cd ~/actions-runner
tail -f _diag/*.log

# 查看系统资源
htop
watch -n 1 'df -h; free -h'

# GitHub 上查看 runner 状态
# Settings → Actions → Runners
```

## 故障排除

### Runner 无法连接

```bash
# 检查服务状态
sudo systemctl status actions.runner.*

# 重新配置
./config.sh remove
./config.sh --url https://github.com/YOUR_USERNAME/k70-ubuntu-port --token NEW_TOKEN

# 重启服务
sudo ./svc.sh stop
sudo ./svc.sh start
```

### 编译内存不足

```bash
# 添加 swap
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 或减少并行度
make -j2  # 而不是 -j$(nproc)
```

### 磁盘空间不足

```bash
# 清理
rm -rf ~/actions-runner/_work/*/build/linux-src
ccache -C  # 清理 ccache（谨慎）

# 或使用外部存储
sudo mkdir -p /mnt/ssd/actions-work
sudo ln -s /mnt/ssd/actions-work ~/actions-runner/_work
```
