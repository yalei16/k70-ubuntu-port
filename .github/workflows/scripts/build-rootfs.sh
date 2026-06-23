#!/bin/bash
# GitHub Actions Rootfs 构建脚本

set -e

WORKSPACE="$(pwd)"
OUT_DIR="${WORKSPACE}/out"
ROOTFS_DIR="${WORKSPACE}/build/rootfs"

echo "=== Rootfs 构建开始 ==="

mkdir -p "$OUT_DIR" "$ROOTFS_DIR"

# 安装依赖
sudo apt-get update
sudo apt-get install -y debootstrap qemu-user-static binfmt-support

# 注册 binfmt
sudo systemctl restart systemd-binfmt || true

# 第一阶段
echo "debootstrap 第一阶段..."
sudo debootstrap --arch=arm64 --foreign noble "$ROOTFS_DIR"     http://ports.ubuntu.com/ubuntu-ports

# 复制 qemu
sudo cp /usr/bin/qemu-aarch64-static "$ROOTFS_DIR/usr/bin/"

# 第二阶段
echo "debootstrap 第二阶段..."
sudo chroot "$ROOTFS_DIR" /debootstrap/debootstrap --second-stage

# 配置系统
echo "配置系统..."
sudo chroot "$ROOTFS_DIR" bash -c '
    echo "vermeer" > /etc/hostname
    echo "127.0.0.1 localhost vermeer" >> /etc/hosts

    # 配置源
    cat > /etc/apt/sources.list << EOF
deb http://ports.ubuntu.com/ubuntu-ports noble main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports noble-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports noble-security main restricted universe multiverse
EOF

    apt-get update

    # 安装必要包
    DEBIAN_FRONTEND=noninteractive apt-get install -y         linux-image-generic         systemd systemd-boot         network-manager         openssh-server         sudo         vim nano         htop         curl wget         firmware-linux-free         wireless-tools         wpasupplicant         bluetooth         pulseaudio         alsa-utils

    # 创建用户
    useradd -m -s /bin/bash -G sudo ubuntu
    echo "ubuntu:ubuntu" | chpasswd

    # 启用服务
    systemctl enable ssh
    systemctl enable NetworkManager

    # 配置网络
    cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: NetworkManager
  wifis:
    wlan0:
      dhcp4: true
      access-points:
        "YOUR_WIFI_SSID":
          password: "YOUR_WIFI_PASSWORD"
EOF

    # 配置 SSH
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config

    # 清理
    apt-get clean
    rm -rf /var/lib/apt/lists/*
'

# 复制固件（如有）
if [ -d "$WORKSPACE/firmware/qcom" ]; then
    echo "复制固件..."
    sudo mkdir -p "$ROOTFS_DIR/lib/firmware/qcom"
    sudo cp -r "$WORKSPACE/firmware/qcom/"* "$ROOTFS_DIR/lib/firmware/qcom/" 2>/dev/null || true
fi

# 打包
echo "打包 rootfs..."
cd "$WORKSPACE/build"
sudo tar --zstd -cf "$OUT_DIR/rootfs-vermeer.tar.zst" rootfs/

echo "=== Rootfs 构建完成 ==="
ls -lh "$OUT_DIR/rootfs-vermeer.tar.zst"
