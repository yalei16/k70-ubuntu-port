#!/bin/bash
# GitHub Actions 内核构建脚本

set -e

KERNEL_VERSION="${1:-v6.12}"
WORKSPACE="$(pwd)"
BUILD_DIR="${WORKSPACE}/build"
OUT_DIR="${WORKSPACE}/out"

echo "=== 内核构建开始 ==="
echo "版本: $KERNEL_VERSION"
echo "工作目录: $WORKSPACE"

mkdir -p "$BUILD_DIR" "$OUT_DIR"

# 克隆内核
if [ ! -d "$BUILD_DIR/linux-src" ]; then
    echo "克隆内核源码..."
    git clone --depth 1 --branch "$KERNEL_VERSION"         https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git         "$BUILD_DIR/linux-src"
fi

# 克隆参考
if [ ! -d "$BUILD_DIR/sm8550-reference" ]; then
    echo "克隆参考内核..."
    git clone --depth 1 https://github.com/map220v/sm8550-mainline.git         "$BUILD_DIR/sm8550-reference"
fi

cd "$BUILD_DIR/linux-src"

# 复制 DTS
echo "复制设备树..."
cp "$WORKSPACE/dts/sm8550-xiaomi-vermeer.dts" arch/arm64/boot/dts/qcom/
cp "$BUILD_DIR/sm8550-reference/arch/arm64/boot/dts/qcom/sm8550-xiaomi-"*.dts    arch/arm64/boot/dts/qcom/ 2>/dev/null || true

# 更新 Makefile
if ! grep -q "sm8550-xiaomi-vermeer" arch/arm64/boot/dts/qcom/Makefile; then
    echo "dtb-$(CONFIG_ARCH_QCOM) += sm8550-xiaomi-vermeer.dtb"         >> arch/arm64/boot/dts/qcom/Makefile
fi

# 应用补丁
if [ -d "$WORKSPACE/kernel/patches" ]; then
    for patch in "$WORKSPACE/kernel/patches/"*.patch; do
        [ -f "$patch" ] || continue
        echo "应用补丁: $(basename $patch)"
        git apply "$patch" 2>/dev/null || echo "跳过: $(basename $patch)"
    done
fi

# 配置
echo "配置内核..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- sm8550_defconfig

if [ -f "$WORKSPACE/kernel/configs/vermeer.config" ]; then
    cat "$WORKSPACE/kernel/configs/vermeer.config" >> .config
fi

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

# 编译
echo "编译内核..."
make -j$(nproc) ARCH=arm64     CROSS_COMPILE="ccache aarch64-linux-gnu-"     CC="ccache aarch64-linux-gnu-gcc"     Image.gz dtbs

# 尝试 PE32+
make -j$(nproc) ARCH=arm64     CROSS_COMPILE="ccache aarch64-linux-gnu-"     CC="ccache aarch64-linux-gnu-gcc"     vmlinuz.efi 2>/dev/null || echo "vmlinuz.efi 失败"

# 模块
make -j$(nproc) ARCH=arm64     CROSS_COMPILE="ccache aarch64-linux-gnu-"     CC="ccache aarch64-linux-gnu-gcc"     modules

# 安装模块
mkdir -p "$OUT_DIR/modules"
make ARCH=arm64 INSTALL_MOD_PATH="$OUT_DIR/modules" modules_install

# 复制输出
mkdir -p "$OUT_DIR/boot"
cp arch/arm64/boot/Image.gz "$OUT_DIR/boot/"
[ -f arch/arm64/boot/vmlinuz.efi ] && cp arch/arm64/boot/vmlinuz.efi "$OUT_DIR/boot/"
cp arch/arm64/boot/dts/qcom/sm8550-xiaomi-vermeer.dtb "$OUT_DIR/boot/"

echo "=== 内核构建完成 ==="
ls -la "$OUT_DIR/boot/"
