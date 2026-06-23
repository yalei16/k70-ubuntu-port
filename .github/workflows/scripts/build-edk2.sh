#!/bin/bash
# GitHub Actions EDK2 构建脚本

set -e

WORKSPACE="$(pwd)"
BUILD_DIR="${WORKSPACE}/build"
OUT_DIR="${WORKSPACE}/out"

echo "=== EDK2 构建开始 ==="

# 克隆
if [ ! -d "$BUILD_DIR/edk2-msm-src" ]; then
    echo "克隆 edk2-msm..."
    git clone --recursive --depth 1         https://github.com/edk2-porting/edk2-msm.git         "$BUILD_DIR/edk2-msm-src"
fi

# 复制设备配置
mkdir -p "$BUILD_DIR/edk2-msm-src/Platform/Qualcomm/sm8550/vermeer"
cp "$WORKSPACE/edk2/device/vermeer/"*    "$BUILD_DIR/edk2-msm-src/Platform/Qualcomm/sm8550/vermeer/"

cd "$BUILD_DIR/edk2-msm-src"

export WORKSPACE="$(pwd)"
export EDK_TOOLS_PATH="$WORKSPACE/BaseTools"
export GCC5_AARCH64_PREFIX=aarch64-linux-gnu-

# BaseTools
if [ ! -f "$WORKSPACE/BaseTools/Source/C/bin/GenFv" ]; then
    echo "编译 BaseTools..."
    make -C "$WORKSPACE/BaseTools" -j$(nproc)
fi

source "$WORKSPACE/edksetup.sh"

# 编译
echo "编译 vermeer..."
build -a AARCH64 -t GCC5     -p "Platform/Qualcomm/sm8550/vermeer/vermeer.dsc"     -b RELEASE -j$(nproc)

# 复制输出
mkdir -p "$OUT_DIR/edk2"
find "$WORKSPACE/Build/vermeer" -name "*.fd" -o -name "*.img" |     xargs -I{} cp {} "$OUT_DIR/edk2/" 2>/dev/null || true

echo "=== EDK2 构建完成 ==="
ls -la "$OUT_DIR/edk2/" 2>/dev/null || echo "无输出"
