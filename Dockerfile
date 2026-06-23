FROM ubuntu:24.04

LABEL maintainer="K70 Ubuntu Port Team"
LABEL description="Build environment for K70 Ubuntu port"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 安装基础依赖
RUN apt-get update && apt-get install -y     build-essential     crossbuild-essential-arm64     device-tree-compiler     git     bc     bison     flex     libncurses-dev     libssl-dev     ccache     cmake     ninja-build     python3     python3-pip     qemu-user-static     qemu-system-arm     u-boot-tools     unzip     wget     xz-utils     zip     abootimg     fastboot     adb     debootstrap     binfmt-support     dosfstools     e2fsprogs     parted     && rm -rf /var/lib/apt/lists/*

# 配置 ccache
RUN ccache --max-size=20G

# 创建工作目录
WORKDIR /workspace

# 默认命令
CMD ["/bin/bash"]
