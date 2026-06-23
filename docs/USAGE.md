# K70 Ubuntu Port GitHub 仓库使用说明

## 快速部署到 GitHub

### 1. 创建 GitHub 仓库

1. 访问 https://github.com/new
2. 仓库名称: `k70-ubuntu-port`
3. 选择 "Public" 或 "Private"
4. 不要初始化 README（我们已有）
5. 点击 "Create repository"

### 2. 推送代码

```bash
# 解压下载的 zip 文件
cd k70-ubuntu-port

# 初始化 git
git init
git add .
git commit -m "Initial commit: K70 Ubuntu port infrastructure"

# 添加远程仓库（替换 YOUR_USERNAME）
git remote add origin https://github.com/YOUR_USERNAME/k70-ubuntu-port.git

# 推送
git push -u origin main
```

### 3. 配置 GitHub Actions

无需额外配置，`.github/workflows/` 目录已包含工作流文件。

首次推送后，Actions 会自动运行。

### 4. 配置 GitHub Secrets（可选）

如需推送通知到 Telegram/Discord:
- Settings → Secrets and variables → Actions
- 添加 `TELEGRAM_BOT_TOKEN` 和 `TELEGRAM_CHAT_ID`

## 工作流说明

### 主工作流: `main.yml`

触发条件:
- 推送到 `main` 或 `dev` 分支
- 修改 `dts/`, `kernel/`, `edk2/` 目录
- 手动触发 (workflow_dispatch)

任务:
1. **build-kernel**: 编译主线内核 + DTB + 模块 + initramfs
2. **build-edk2**: 编译 EDK2 UEFI 固件
3. **build-rootfs**: 构建 Ubuntu ARM64 rootfs
4. **release**: 打包所有产物并发布到 GitHub Release

### DTS 检查工作流: `dts-check.yml`

触发条件:
- 修改 `dts/` 目录

任务:
1. 编译 DTS 为 DTB
2. 检查 DTB 大小
3. 与小米平板 6S Pro 参考 DTS 对比
4. 验证节点完整性

## 本地开发流程

### 修改设备树

```bash
# 编辑 DTS
vim dts/sm8550-xiaomi-vermeer.dts

# 本地验证
cd dts
dtc -I dts -O dtb -o sm8550-xiaomi-vermeer.dtb sm8550-xiaomi-vermeer.dts

# 提交并推送
git add dts/
git commit -m "dts: fix panel timing for vermeer"
git push

# GitHub Actions 自动编译
```

### 本地完整编译

```bash
# 一键编译所有组件
./build-local.sh v6.12 all

# 只编译内核
./build-local.sh v6.12 kernel

# 只编译 EDK2
./build-local.sh v6.12 edk2
```

### 刷机测试

```bash
# 进入 fastboot
adb reboot bootloader

# 运行刷机脚本
./flash.sh
```

## 目录结构说明

```
k70-ubuntu-port/
├── .github/workflows/          # CI/CD 工作流
│   ├── main.yml              # 主编译工作流
│   └── dts-check.yml         # DTS 检查工作流
├── dts/                      # 设备树（核心）
│   └── sm8550-xiaomi-vermeer.dts
├── kernel/                   # 内核配置和补丁
│   ├── configs/
│   │   └── vermeer.config    # 额外内核配置
│   └── patches/              # 内核补丁（如有）
├── edk2/                     # EDK2 设备配置
│   └── device/
│       └── vermeer/
│           ├── vermeer.dsc    # EDK2 描述文件
│           ├── vermeer.fdf    # 闪存布局
│           └── build.sh      # 本地构建脚本
├── scripts/                  # 辅助脚本
│   └── gen-initramfs.sh      # initramfs 生成
├── firmware/                 # 固件文件（从 MIUI 提取）
├── rootfs/                   # rootfs 配置
├── docs/                     # 文档
│   ├── PORTING.md            # 移植指南
│   └── FAQ.md                # 常见问题
├── build-local.sh            # 本地一键构建
├── flash.sh                  # 刷机脚本
├── README.md                 # 项目说明
├── LICENSE                   # 许可证
└── .gitignore                # Git 忽略规则
```

## 协作开发

### 提交规范

```
dts: fix gpio-keys node for vermeer
kernel: enable CONFIG_DRM_MSM_DPU
edk2: update memory map for 16GB variant
docs: add charging configuration notes
```

### Pull Request 流程

1. Fork 仓库
2. 创建分支: `git checkout -b feature/dsi-panel`
3. 修改并提交
4. 推送: `git push origin feature/dsi-panel`
5. 在 GitHub 创建 PR
6. Actions 自动运行检查
7. 审核后合并

## 故障排除

### Actions 编译失败

1. 查看 Actions 日志
2. 检查错误信息
3. 本地复现: `./build-local.sh`
4. 修复后重新推送

### 本地编译失败

```bash
# 清理并重新编译
rm -rf build/
./build-local.sh v6.12 all
```

### 刷机后无法启动

1. 检查串口日志
2. 确认 boot.img 格式正确
3. 检查设备树地址
4. 尝试使用 TWRP 恢复

## 更新维护

### 更新内核版本

修改 `.github/workflows/main.yml`:
```yaml
env:
  KERNEL_VERSION: "v6.13"  # 修改这里
```

或推送时指定:
```bash
git tag v6.13-test
git push origin v6.13-test
```

### 更新 EDK2

```bash
cd build/edk2-msm-src
git pull origin main
cd ../..
git add build/edk2-msm-src  # 或使用子模块
git commit -m "edk2: update to latest"
```

## 获取帮助

- 查看 [docs/PORTING.md](docs/PORTING.md)
- 查看 [docs/FAQ.md](docs/FAQ.md)
- 提交 Issue（附上 Actions 日志和串口输出）
- 加入 linux-msm 社区讨论
