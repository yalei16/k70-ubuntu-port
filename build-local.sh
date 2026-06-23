#!/bin/bash
# K70 Ubuntu Port - 本地一键构建脚本
# 用法: ./build-local.sh [kernel_version] [target]

set -e

KERNEL_VERSION="${1:-v6.12}"
TARGET="${2:-all}"
DEVICE="vermeer"
SOC="sm8550"

# 颜色
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m'

WORK_DIR="$(pwd)"
BUILD_DIR="${WORK_DIR}/build"
OUT_DIR="${WORK_DIR}/out"

mkdir -p "${BUILD_DIR}" "${OUT_DIR}"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# ========== 检查依赖 ==========
check_deps() {
    log_step "检查依赖..."

    local deps=("git" "make" "gcc" "aarch64-linux-gnu-gcc" "dtc" "python3")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "缺少依赖: ${missing[*]}"
        log_info "安装命令: sudo apt install -y build-essential crossbuild-essential-arm64 device-tree-compiler python3"
        exit 1
    fi

    log_info "依赖检查通过"
}

# ========== 克隆内核 ==========
clone_kernel() {
    log_step "克隆内核源码 (${KERNEL_VERSION})..."

    if [ -d "${BUILD_DIR}/linux-src" ]; then
        log_warn "内核目录已存在，更新中..."
        cd "${BUILD_DIR}/linux-src"
        git fetch --depth 1 origin "${KERNEL_VERSION}"
        git checkout "${KERNEL_VERSION}"
        cd "${WORK_DIR}"
    else
        git clone --depth 1 --branch "${KERNEL_VERSION}"             https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git             "${BUILD_DIR}/linux-src"
    fi

    # 克隆参考仓库
    if [ ! -d "${BUILD_DIR}/sm8550-reference" ]; then
        log_info "克隆小米平板 6S Pro 参考内核..."
        git clone --depth 1 https://github.com/map220v/sm8550-mainline.git             "${BUILD_DIR}/sm8550-reference"
    fi
}

# ========== 准备设备树 ==========
prepare_dts() {
    log_step "准备设备树..."

    cd "${BUILD_DIR}/linux-src"

    # 复制我们的 DTS
    cp "${WORK_DIR}/dts/sm8550-xiaomi-vermeer.dts"        arch/arm64/boot/dts/qcom/

    # 复制参考 DTS
    cp "${BUILD_DIR}/sm8550-reference/arch/arm64/boot/dts/qcom/sm8550-xiaomi-"*.dts        arch/arm64/boot/dts/qcom/ 2>/dev/null || true

    # 更新 Makefile
    if ! grep -q "sm8550-xiaomi-vermeer" arch/arm64/boot/dts/qcom/Makefile; then
        echo "dtb-\$(CONFIG_ARCH_QCOM) += sm8550-xiaomi-vermeer.dtb"             >> arch/arm64/boot/dts/qcom/Makefile
    fi

    cd "${WORK_DIR}"
}

# ========== 配置内核 ==========
configure_kernel() {
    log_step "配置内核..."

    cd "${BUILD_DIR}/linux-src"

    # 基于 sm8550_defconfig
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- sm8550_defconfig

    # 应用额外配置
    if [ -f "${WORK_DIR}/kernel/configs/vermeer.config" ]; then
        cat "${WORK_DIR}/kernel/configs/vermeer.config" >> .config
    fi

    # 应用补丁
    if [ -d "${WORK_DIR}/kernel/patches" ]; then
        for patch in "${WORK_DIR}/kernel/patches/"*.patch; do
            if [ -f "$patch" ]; then
                log_info "应用补丁: $(basename $patch)"
                git apply "$patch" 2>/dev/null || log_warn "补丁已应用或失败: $(basename $patch)"
            fi
        done
    fi

    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

    cd "${WORK_DIR}"
}

# ========== 编译内核 ==========
build_kernel() {
    log_step "编译内核..."

    cd "${BUILD_DIR}/linux-src"

    local jobs=$(nproc)
    log_info "使用 ${jobs} 线程编译"

    # 编译内核
    make -j${jobs} ARCH=arm64         CROSS_COMPILE=aarch64-linux-gnu-         Image.gz dtbs

    # 尝试生成 PE32+ 格式
    log_info "尝试生成 vmlinuz.efi..."
    make -j${jobs} ARCH=arm64         CROSS_COMPILE=aarch64-linux-gnu-         vmlinuz.efi 2>/dev/null || log_warn "vmlinuz.efi 生成失败，使用 Image.gz"

    # 编译模块
    log_info "编译内核模块..."
    make -j${jobs} ARCH=arm64         CROSS_COMPILE=aarch64-linux-gnu-         modules

    # 安装模块
    mkdir -p "${OUT_DIR}/modules"
    make ARCH=arm64 INSTALL_MOD_PATH="${OUT_DIR}/modules" modules_install

    # 复制输出
    mkdir -p "${OUT_DIR}/boot"
    cp arch/arm64/boot/Image.gz "${OUT_DIR}/boot/"
    [ -f arch/arm64/boot/vmlinuz.efi ] && cp arch/arm64/boot/vmlinuz.efi "${OUT_DIR}/boot/"
    cp arch/arm64/boot/dts/qcom/sm8550-xiaomi-vermeer.dtb "${OUT_DIR}/boot/"

    cd "${WORK_DIR}"

    log_info "内核编译完成！"
    log_info "输出: ${OUT_DIR}/boot/"
}

# ========== 生成 initramfs ==========
build_initramfs() {
    log_step "生成 initramfs..."

    if [ -f "${WORK_DIR}/scripts/gen-initramfs.sh" ]; then
        bash "${WORK_DIR}/scripts/gen-initramfs.sh"             "${OUT_DIR}/modules"             "${OUT_DIR}/boot/initramfs.cpio.zst"
    else
        log_warn "未找到 initramfs 生成脚本，跳过"
    fi
}

# ========== 编译 EDK2 ==========
build_edk2() {
    log_step "编译 EDK2..."

    if [ ! -d "${BUILD_DIR}/edk2-msm-src" ]; then
        log_info "克隆 edk2-msm..."
        git clone --recursive --depth 1             https://github.com/edk2-porting/edk2-msm.git             "${BUILD_DIR}/edk2-msm-src"
    fi

    # 复制设备配置
    mkdir -p "${BUILD_DIR}/edk2-msm-src/Platform/Qualcomm/sm8550/vermeer"
    cp "${WORK_DIR}/edk2/device/vermeer/"*        "${BUILD_DIR}/edk2-msm-src/Platform/Qualcomm/sm8550/vermeer/"

    cd "${BUILD_DIR}/edk2-msm-src"

    # 初始化环境
    export WORKSPACE="$(pwd)"
    export EDK_TOOLS_PATH="${WORKSPACE}/BaseTools"
    export GCC5_AARCH64_PREFIX=aarch64-linux-gnu-

    if [ ! -f "${WORKSPACE}/BaseTools/Source/C/bin/GenFv" ]; then
        log_info "编译 BaseTools..."
        make -C "${WORKSPACE}/BaseTools" -j$(nproc)
    fi

    source "${WORKSPACE}/edksetup.sh"

    # 编译
    build -a AARCH64 -t GCC5         -p "Platform/Qualcomm/sm8550/vermeer/vermeer.dsc"         -b RELEASE -j$(nproc)

    # 复制输出
    mkdir -p "${OUT_DIR}/edk2"
    find "${WORKSPACE}/Build/vermeer" -name "*.fd" -o -name "*.img" |         xargs -I{} cp {} "${OUT_DIR}/edk2/" 2>/dev/null || true

    cd "${WORK_DIR}"

    log_info "EDK2 编译完成！"
}

# ========== 打包 boot.img ==========
pack_boot() {
    log_step "打包 boot.img..."

    if ! command -v abootimg &> /dev/null; then
        log_warn "未找到 abootimg，跳过打包"
        return
    fi

    local kernel="${OUT_DIR}/boot/Image.gz"
    local dtb="${OUT_DIR}/boot/sm8550-xiaomi-vermeer.dtb"
    local initrd="${OUT_DIR}/boot/initramfs.cpio.zst"

    if [ ! -f "$kernel" ] || [ ! -f "$dtb" ]; then
        log_error "缺少内核或 DTB 文件"
        return
    fi

    abootimg --create "${OUT_DIR}/boot/boot.img"         -k "$kernel"         -r "$initrd"         -f "$dtb"         -c "cmdline=console=ttyMSM0,115200n8 root=/dev/sda31 rw"         2>/dev/null || log_warn "boot.img 打包失败"

    log_info "boot.img 打包完成"
}

# ========== 主流程 ==========
main() {
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  K70 Ubuntu Port 本地构建脚本  ${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""

    check_deps

    case "$TARGET" in
        kernel)
            clone_kernel
            prepare_dts
            configure_kernel
            build_kernel
            build_initramfs
            pack_boot
            ;;
        edk2)
            build_edk2
            ;;
        all|*)
            clone_kernel
            prepare_dts
            configure_kernel
            build_kernel
            build_initramfs
            build_edk2
            pack_boot
            ;;
    esac

    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  构建完成！                    ${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo "输出目录: ${OUT_DIR}"
    echo ""
    ls -la "${OUT_DIR}/"
}

main "$@"
