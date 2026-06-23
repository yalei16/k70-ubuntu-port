#!/bin/bash
# K70 Ubuntu Port - initramfs 生成脚本
# 用法: ./gen-initramfs.sh <modules_dir> <output_file>

set -e

MODULES_DIR="${1:-./modules}"
OUTPUT="${2:-./initramfs.cpio.zst}"
WORK_DIR=$(mktemp -d)

echo "=== 生成 K70 initramfs ==="
echo "模块目录: $MODULES_DIR"
echo "输出文件: $OUTPUT"

# 创建基础目录结构
mkdir -p "$WORK_DIR"/{bin,sbin,lib,lib64,proc,sys,dev,run,tmp,etc,mnt,usr}
mkdir -p "$WORK_DIR"/lib/modules

# 复制 busybox（静态链接）
if command -v busybox &> /dev/null; then
    cp $(which busybox) "$WORK_DIR/bin/"
    for applet in sh mount umount mkdir mknod sleep echo cat ls insmod modprobe                   switch_root mountpoint grep sed awk chmod chroot; do
        ln -sf busybox "$WORK_DIR/bin/$applet"
    done
else
    echo "警告: 未找到 busybox，尝试安装..."
    sudo apt-get install -y busybox-static
    cp $(which busybox) "$WORK_DIR/bin/"
fi

# 复制必要的动态库
if [ -d "$MODULES_DIR/lib" ]; then
    cp -r "$MODULES_DIR/lib/modules"/* "$WORK_DIR/lib/modules/" 2>/dev/null || true
fi

# 复制内核模块依赖
if [ -f "$MODULES_DIR/modules.dep" ]; then
    cp "$MODULES_DIR/modules.dep" "$WORK_DIR/lib/modules/"
fi

# 创建 init 脚本
cat > "$WORK_DIR/init" << 'INITEOF'
#!/bin/sh
# K70 initramfs init

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

# 挂载基本文件系统
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mount -t tmpfs none /run

# 等待设备稳定
sleep 1

echo "=== K70 Ubuntu Port Initramfs ==="
echo "正在初始化系统..."

# 加载基本模块
modprobe ext4 2>/dev/null || true
modprobe usb_storage 2>/dev/null || true
modprobe dwc3 2>/dev/null || true

# 查找 rootfs 分区
# 尝试多种方式定位 rootfs
ROOT_DEV=""

# 1. 通过 UUID
if [ -n "$rootuuid" ]; then
    ROOT_DEV=$(findfs UUID="$rootuuid" 2>/dev/null)
fi

# 2. 通过 PARTUUID
if [ -z "$ROOT_DEV" ] && [ -n "$rootpartuuid" ]; then
    ROOT_DEV=$(findfs PARTUUID="$rootpartuuid" 2>/dev/null)
fi

# 3. 通过设备路径
if [ -z "$ROOT_DEV" ] && [ -n "$root" ]; then
    ROOT_DEV="$root"
fi

# 4. 自动探测（查找最大的 ext4 分区）
if [ -z "$ROOT_DEV" ]; then
    for dev in /dev/sda* /dev/mmcblk0p*; do
        if [ -b "$dev" ]; then
            fstype=$(blkid -s TYPE -o value "$dev" 2>/dev/null)
            if [ "$fstype" = "ext4" ]; then
                size=$(blockdev --getsize64 "$dev" 2>/dev/null || echo 0)
                if [ "$size" -gt 10000000000 ]; then  # > 10GB
                    ROOT_DEV="$dev"
                    echo "自动探测到 rootfs: $ROOT_DEV ($(($size/1024/1024/1024))GB)"
                    break
                fi
            fi
        fi
    done
fi

if [ -z "$ROOT_DEV" ]; then
    echo "错误: 无法找到 rootfs 分区"
    echo "可用的块设备:"
    ls -la /dev/sda* /dev/mmcblk* 2>/dev/null || true

    # 进入应急 shell
    echo "进入应急 shell..."
    /bin/sh
    exit 1
fi

echo "挂载 rootfs: $ROOT_DEV"
mkdir -p /mnt/root
mount -t ext4 "$ROOT_DEV" /mnt/root

if [ ! -f /mnt/root/sbin/init ]; then
    echo "错误: rootfs 中没有找到 /sbin/init"
    umount /mnt/root
    /bin/sh
    exit 1
fi

# 挂载伪文件系统到 rootfs
mount --move /proc /mnt/root/proc
mount --move /sys /mnt/root/sys
mount --move /dev /mnt/root/dev
mount --move /run /mnt/root/run

# 切换根目录
echo "切换到真实 rootfs..."
exec switch_root /mnt/root /sbin/init
INITEOF

chmod +x "$WORK_DIR/init"

# 创建必要的设备节点（如果 devtmpfs 不可用）
mknod -m 666 "$WORK_DIR/dev/null" c 1 3 2>/dev/null || true
mknod -m 666 "$WORK_DIR/dev/zero" c 1 5 2>/dev/null || true
mknod -m 666 "$WORK_DIR/dev/random" c 1 8 2>/dev/null || true
mknod -m 666 "$WORK_DIR/dev/urandom" c 1 9 2>/dev/null || true
mknod -m 666 "$WORK_DIR/dev/tty" c 5 0 2>/dev/null || true
mknod -m 666 "$WORK_DIR/dev/console" c 5 1 2>/dev/null || true

# 打包 initramfs
echo "打包 initramfs..."
cd "$WORK_DIR"
find . | cpio -o -H newc 2>/dev/null | zstd -19 -o "$OUTPUT"

echo "完成: $OUTPUT ($(stat -c%s "$OUTPUT") bytes)"

# 清理
rm -rf "$WORK_DIR"
