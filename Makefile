# K70 Ubuntu Port - Makefile
# 简化常用构建操作

.PHONY: help build kernel edk2 rootfs clean flash docker

DEVICE := vermeer
KERNEL_VERSION := v6.12

help:
	@echo "K70 Ubuntu Port 构建工具"
	@echo ""
	@echo "可用目标:"
	@echo "  make build        - 完整构建所有组件"
	@echo "  make kernel       - 只编译内核"
	@echo "  make edk2         - 只编译 EDK2"
	@echo "  make rootfs       - 只构建 rootfs"
	@echo "  make dts-check    - 检查设备树"
	@echo "  make flash        - 刷入设备"
	@echo "  make clean        - 清理构建目录"
	@echo "  make docker       - 使用 Docker 构建"
	@echo "  make setup        - 安装依赖"

build:
	./build-local.sh $(KERNEL_VERSION) all

kernel:
	./build-local.sh $(KERNEL_VERSION) kernel

edk2:
	./build-local.sh $(KERNEL_VERSION) edk2

rootfs:
	bash .github/workflows/scripts/build-rootfs.sh

dts-check:
	cd dts && dtc -I dts -O dtb -o sm8550-xiaomi-$(DEVICE).dtb sm8550-xiaomi-$(DEVICE).dts
	@echo "DTS 检查通过"

flash:
	./flash.sh

clean:
	rm -rf build/ out/ release/
	@echo "清理完成"

docker:
	docker-compose build
	docker-compose run --rm builder ./build-local.sh $(KERNEL_VERSION) all

setup:
	@echo "安装系统依赖..."
	sudo apt-get update
	sudo apt-get install -y 		build-essential crossbuild-essential-arm64 		device-tree-compiler git bc bison flex 		libncurses-dev libssl-dev ccache 		abootimg fastboot adb 		python3 python3-pip
	@echo "依赖安装完成"
