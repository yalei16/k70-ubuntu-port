#!/bin/bash
# EDK2 vermeer 构建脚本

set -e

DEVICE="vermeer"
SOC="sm8550"

# 颜色输出
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
NC='[0m'

echo -e "${GREEN}=== EDK2 vermeer 构建脚本 ===${NC}"

# 检查依赖
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}错误: 需要 python3${NC}"; exit 1; }
command -v git >/dev/null 2>&1 || { echo -e "${RED}错误: 需要 git${NC}"; exit 1; }

# 设置 EDK2 环境
export WORKSPACE="$(pwd)/edk2-msm-src"
export EDK_TOOLS_PATH="$WORKSPACE/BaseTools"
export GCC5_AARCH64_PREFIX=aarch64-linux-gnu-

# 初始化子模块（如需要）
if [ ! -d "$WORKSPACE/BaseTools" ]; then
    echo -e "${YELLOW}初始化 EDK2 子模块...${NC}"
    cd "$WORKSPACE"
    git submodule update --init --recursive
    cd -
fi

# 编译 BaseTools（如需要）
if [ ! -f "$WORKSPACE/BaseTools/Source/C/bin/GenFv" ]; then
    echo -e "${YELLOW}编译 BaseTools...${NC}"
    make -C "$WORKSPACE/BaseTools" -j$(nproc)
fi

# 设置环境
source "$WORKSPACE/edksetup.sh"

# 编译
BUILD_TYPE="RELEASE"
[ "$1" = "debug" ] && BUILD_TYPE="DEBUG"

echo -e "${GREEN}开始编译 $DEVICE ($BUILD_TYPE)...${NC}"
build -a AARCH64 -t GCC5 -p "Platform/Qualcomm/$SOC/$DEVICE/$DEVICE.dsc" -b $BUILD_TYPE -j$(nproc)

# 查找输出
OUTPUT_DIR="$WORKSPACE/Build/$DEVICE/${BUILD_TYPE}_GCC5/FV"
if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${GREEN}编译完成！${NC}"
    echo "输出目录: $OUTPUT_DIR"
    ls -la "$OUTPUT_DIR"

    # 复制到发布目录
    mkdir -p "${WORKSPACE}/../release/edk2"
    cp "$OUTPUT_DIR"/*.fd "${WORKSPACE}/../release/edk2/" 2>/dev/null || true
    cp "$OUTPUT_DIR"/*.img "${WORKSPACE}/../release/edk2/" 2>/dev/null || true
else
    echo -e "${RED}编译失败，未找到输出目录${NC}"
    exit 1
fi
