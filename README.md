# K70 (vermeer) Ubuntu Port

> 红米 K70 (SM8550) 桌面版 Ubuntu 移植项目

## 项目状态

| 组件 | 状态 | 备注 |
|------|------|------|
| 设备树 (DTS) | 🚧 WIP | 基础框架，需根据实际硬件调整 |
| 主线内核 | 🚧 WIP | 基于 6.12+，SM8550 支持成熟 |
| EDK2 UEFI | 🚧 WIP | 基于 sm8550 QRD 配置 |
| 显示 | ⏳ 未开始 | 需提取面板参数 |
| 触摸 | ⏳ 未开始 | 需确认芯片型号 |
| USB | ⏳ 未开始 | 基础支持已配置 |
| 存储 (UFS) | ⏳ 未开始 | 主线已支持 UFS 4.0 |
| WiFi/BT | ⏳ 未开始 | 需固件 |
| 音频 | ⏳ 未开始 | 需拓扑配置 |
| 充电 | ⏳ 未开始 | 120W 快充需适配 |
| 相机 | ⏳ 未开始 | 低优先级 |
| 指纹 | ⏳ 未开始 | 低优先级 |

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/YOUR_USERNAME/k70-ubuntu-port.git
cd k70-ubuntu-port
```

### 2. 本地编译内核

```bash
# 安装依赖
sudo apt install -y build-essential crossbuild-essential-arm64     device-tree-compiler git bc bison flex libncurses-dev libssl-dev

# 编译
bash .github/workflows/scripts/build-kernel.sh v6.12
```

### 3. GitHub Actions 自动编译

每次推送代码到 `main` 或 `dev` 分支，GitHub Actions 会自动：
- 编译主线内核 + vermeer DTB
- 编译 EDK2 UEFI 固件
- 构建 Ubuntu ARM64 rootfs
- 打包并发布到 Release

手动触发：Actions → K70 Ubuntu Port CI → Run workflow

## 仓库结构

```
k70-ubuntu-port/
├── .github/workflows/          # GitHub Actions 工作流
│   ├── main.yml               # 主 CI 工作流
│   └── dts-check.yml          # DTS 检查工作流
├── dts/                       # 设备树
│   └── sm8550-xiaomi-vermeer.dts
├── kernel/                    # 内核配置和补丁
│   ├── configs/
│   │   └── vermeer.config     # 额外内核配置
│   └── patches/               # 内核补丁（如有）
├── edk2/                      # EDK2 设备配置
│   └── device/
│       └── vermeer/
│           ├── vermeer.dsc    # EDK2 描述文件
│           ├── vermeer.fdf    # 闪存描述文件
│           └── build.sh       # 本地构建脚本
├── scripts/                   # 辅助脚本
│   └── gen-initramfs.sh       # initramfs 生成
├── firmware/                  # 固件文件（从 MIUI 提取）
├── rootfs/                    # rootfs 配置
└── docs/                      # 文档
```

## 关键参考资源

- [小米平板 6S Pro 主线内核](https://github.com/map220v/sm8550-mainline) - 最重要的 SM8550 参考
- [edk2-msm](https://github.com/edk2-porting/edk2-msm) - UEFI 固件
- [LineageOS vermeer](https://github.com/xiaomi-8550/android_device_xiaomi_vermeer) - Android 设备树参考
- [PostmarketOS 移植指南](https://wiki.postmarketos.org/wiki/Porting_to_a_new_device)

## 贡献

欢迎提交 PR！特别是：
- 修正设备树中的硬件参数
- 添加缺失的驱动支持
- 改进构建脚本
- 补充文档

## 许可证

内核补丁和 DTS 遵循 GPL-2.0。
EDK2 配置遵循 BSD-2-Clause。

## 免责声明

此项目为实验性质，刷机可能导致设备变砖。请确保已备份数据并了解风险。
