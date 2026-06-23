#!/bin/bash
# 打包发布脚本

set -e

WORKSPACE="$(pwd)"
OUT_DIR="${WORKSPACE}/out"
RELEASE_DIR="${WORKSPACE}/release"

echo "=== 打包发布 ==="

mkdir -p "$RELEASE_DIR/boot"
mkdir -p "$RELEASE_DIR/edk2"
mkdir -p "$RELEASE_DIR/rootfs"

# 复制内核文件
if [ -f "$OUT_DIR/boot/Image.gz" ]; then
    cp "$OUT_DIR/boot/Image.gz" "$RELEASE_DIR/boot/"
fi

if [ -f "$OUT_DIR/boot/vmlinuz.efi" ]; then
    cp "$OUT_DIR/boot/vmlinuz.efi" "$RELEASE_DIR/boot/"
fi

if [ -f "$OUT_DIR/boot/sm8550-xiaomi-vermeer.dtb" ]; then
    cp "$OUT_DIR/boot/sm8550-xiaomi-vermeer.dtb" "$RELEASE_DIR/boot/"
fi

if [ -f "$OUT_DIR/boot/initramfs.cpio.zst" ]; then
    cp "$OUT_DIR/boot/initramfs.cpio.zst" "$RELEASE_DIR/boot/"
fi

# 复制 EDK2
if [ -d "$OUT_DIR/edk2" ]; then
    cp "$OUT_DIR/edk2/"* "$RELEASE_DIR/edk2/" 2>/dev/null || true
fi

# 复制 rootfs
if [ -f "$OUT_DIR/rootfs/rootfs-vermeer.tar.zst" ]; then
    cp "$OUT_DIR/rootfs/rootfs-vermeer.tar.zst" "$RELEASE_DIR/rootfs/"
fi

# 复制模块
if [ -d "$OUT_DIR/modules" ]; then
    mkdir -p "$RELEASE_DIR/modules"
    cp -r "$OUT_DIR/modules/lib/modules" "$RELEASE_DIR/modules/" 2>/dev/null || true
fi

# 生成刷机脚本
cat > "$RELEASE_DIR/flash.sh" << 'FLASH_EOF'
#!/bin/bash
# K70 Ubuntu Port 刷机脚本
set -e

FASTBOOT="${FASTBOOT:-fastboot}"
DIR="$(dirname "$0")"

echo "=== K70 Ubuntu Port 刷机工具 ==="

# 检查设备
if ! $FASTBOOT devices | grep -q "fastboot"; then
    echo "错误: 未检测到 fastboot 设备"
    echo "请进入 fastboot 模式: 音量下 + 电源键"
    exit 1
fi

read -p "确认刷机? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

# 刷入 EDK2
if [ -f "$DIR/edk2/uefi.img" ]; then
    echo "[1/4] 刷入 EDK2..."
    $FASTBOOT flash xbl "$DIR/edk2/uefi.img" ||         $FASTBOOT flash boot "$DIR/edk2/uefi.img" || true
fi

# 刷入内核
if [ -f "$DIR/boot/Image.gz" ] && [ -f "$DIR/boot/sm8550-xiaomi-vermeer.dtb" ]; then
    echo "[2/4] 刷入内核..."
    if command -v abootimg &> /dev/null; then
        abootimg --create "$DIR/boot/boot.img"             -k "$DIR/boot/Image.gz"             -f "$DIR/boot/sm8550-xiaomi-vermeer.dtb"             -c "cmdline=console=ttyMSM0,115200n8 root=/dev/sda31 rw"
        $FASTBOOT flash boot "$DIR/boot/boot.img"
    else
        echo "警告: 未找到 abootimg，请手动打包 boot.img"
    fi
fi

# 刷入 DTBO
if [ -f "$DIR/boot/sm8550-xiaomi-vermeer.dtb" ]; then
    echo "[3/4] 刷入 DTBO..."
    $FASTBOOT flash dtbo "$DIR/boot/sm8550-xiaomi-vermeer.dtb" 2>/dev/null || true
fi

# Rootfs 提示
echo "[4/4] Rootfs 准备"
echo "请手动刷入 rootfs 到 ext4 分区"
echo "文件: $DIR/rootfs/rootfs-vermeer.tar.zst"

# 重启
read -p "是否重启? [Y/n]: " reboot
[[ "$reboot" =~ ^[Nn]$ ]] || $FASTBOOT reboot

echo "刷机完成！"
FLASH_EOF

chmod +x "$RELEASE_DIR/flash.sh"

# 生成 README
cat > "$RELEASE_DIR/README.txt" << 'README_EOF'
K70 (vermeer) Ubuntu Port Build
================================

文件说明:
- boot/Image.gz          压缩内核镜像
- boot/vmlinuz.efi       PE32+ 格式内核（UEFI 引导）
- boot/*.dtb             设备树二进制文件
- boot/initramfs.cpio.zst initramfs
- edk2/*.img             EDK2 UEFI 固件
- rootfs/*.tar.zst       Ubuntu rootfs
- modules/               内核模块
- flash.sh               刷机脚本

刷机步骤:
1. 进入 fastboot 模式（音量下 + 电源键）
2. 运行 ./flash.sh
3. 手动刷入 rootfs 到目标分区

调试:
- 连接 USB 串口: minicom -D /dev/ttyUSB0 -b 115200
- 查看启动日志排查问题

警告:
- 此版本为开发测试版
- 刷机前请备份数据
- 需要已解锁 Bootloader
README_EOF

echo "=== 打包完成 ==="
ls -la "$RELEASE_DIR/"

# 创建压缩包
cd "$RELEASE_DIR"
zip -r "$OUT_DIR/k70-ubuntu-port-release.zip" .

echo "发布包: $OUT_DIR/k70-ubuntu-port-release.zip"
