#!/bin/bash
# K70 Ubuntu Port 刷机脚本
# 警告: 此操作会修改设备分区，请确保已备份数据！

set -e

DEVICE="vermeer"
FASTBOOT="${FASTBOOT:-fastboot}"
OUT_DIR="$(dirname "$0")"

# 颜色
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  K70 Ubuntu Port 刷机工具      ${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# ========== 检查设备 ==========
log_step "检查设备连接..."

if ! $FASTBOOT devices | grep -q "fastboot"; then
    log_error "未检测到 fastboot 设备"
    echo ""
    echo "请进入 fastboot 模式:"
    echo "  1. 关机"
    echo "  2. 同时按住 音量下 + 电源键"
    echo "  3. 出现 fastboot 界面后松开"
    echo ""
    exit 1
fi

log_info "设备已连接"
$FASTBOOT getvar product 2>/dev/null || true
echo ""

# ========== 确认刷机 ==========
read -p "确认刷机? 这将覆盖现有系统 [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "已取消"
    exit 0
fi

# ========== 刷入 EDK2 UEFI ==========
log_step "[1/5] 刷入 EDK2 UEFI..."

if [ -f "${OUT_DIR}/edk2/uefi.img" ]; then
    $FASTBOOT flash xbl "${OUT_DIR}/edk2/uefi.img" || {
        log_warn "xbl 刷入失败，尝试 boot 分区..."
        $FASTBOOT flash boot "${OUT_DIR}/edk2/uefi.img" || true
    }
    log_info "EDK2 刷入成功"
else
    log_warn "未找到 EDK2 镜像，跳过"
fi

# ========== 刷入内核 ==========
log_step "[2/5] 刷入内核..."

if [ -f "${OUT_DIR}/boot/boot.img" ]; then
    $FASTBOOT flash boot "${OUT_DIR}/boot/boot.img"
    log_info "内核刷入成功"
elif [ -f "${OUT_DIR}/boot/Image.gz" ]; then
    log_warn "未找到 boot.img，但有 Image.gz"
    log_warn "请手动打包 boot.img 或使用自定义 recovery 刷入"
else
    log_error "未找到内核文件"
    exit 1
fi

# ========== 刷入 DTBO ==========
log_step "[3/5] 刷入 DTBO..."

if [ -f "${OUT_DIR}/boot/sm8550-xiaomi-vermeer.dtb" ]; then
    # 某些设备需要 dtbo 分区
    $FASTBOOT flash dtbo "${OUT_DIR}/boot/sm8550-xiaomi-vermeer.dtb" 2>/dev/null || {
        log_warn "dtbo 分区不存在或刷入失败"
    }
else
    log_warn "未找到 DTB 文件"
fi

# ========== 刷入 Rootfs ==========
log_step "[4/5] 准备 Rootfs..."

if [ -f "${OUT_DIR}/rootfs/rootfs-vermeer.tar.zst" ]; then
    log_info "找到 rootfs: ${OUT_DIR}/rootfs/rootfs-vermeer.tar.zst"
    log_warn "Rootfs 需要手动刷入到 ext4 分区"
    echo ""
    echo "建议操作:"
    echo "  1. 使用 TWRP 挂载 userdata 分区"
    echo "  2. 格式化为 ext4"
    echo "  3. 解压 rootfs:"
    echo "     tar --zstd -xf rootfs-vermeer.tar.zst -C /mnt/target"
    echo ""
    echo "或使用自定义分区方案（参考 K20 Pro 经验）:"
    echo "  sda31 - Ubuntu rootfs (ext4)"
    echo "  sda32 - ESP 分区 (fat32)"
    echo "  sda33 - 数据分区 (ext4)"
    echo ""
else
    log_warn "未找到 rootfs 文件"
fi

# ========== 重启 ==========
log_step "[5/5] 重启设备..."

echo ""
read -p "是否立即重启? [Y/n]: " reboot_confirm
if [[ ! "$reboot_confirm" =~ ^[Nn]$ ]]; then
    $FASTBOOT reboot
    log_info "设备重启中..."
    echo ""
    echo "首次启动可能需要几分钟"
    echo "连接串口查看启动日志:"
    echo "  minicom -D /dev/ttyUSB0 -b 115200"
else
    log_info "设备保持在 fastboot 模式"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  刷机完成！                    ${NC}"
echo -e "${GREEN}================================${NC}"
