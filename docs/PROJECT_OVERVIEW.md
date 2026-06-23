# K70 Ubuntu Port 项目总览

## 项目架构

```
k70-ubuntu-port/
├── 📁 .github/                    # GitHub 配置
│   ├── 📁 ISSUE_TEMPLATE/        # Issue 模板
│   │   ├── bug-report.md
│   │   ├── feature-request.md
│   │   └── porting-progress.md
│   └── 📁 workflows/             # CI/CD 工作流
│       ├── 📁 reusable/          # 可复用工作流
│       │   ├── kernel-build.yml
│       │   └── edk2-build.yml
│       ├── 📁 scripts/           # 工作流辅助脚本
│       │   ├── build-kernel.sh
│       │   ├── build-edk2.sh
│       │   ├── build-rootfs.sh
│       │   └── pack-release.sh
│       ├── main.yml              # 主 CI 工作流
│       ├── dts-check.yml         # DTS 检查
│       ├── matrix-build.yml      # 多设备矩阵构建
│       └── nightly.yml           # 定时夜间构建
├── 📁 dts/                       # 设备树
│   └── sm8550-xiaomi-vermeer.dts
├── 📁 kernel/                    # 内核配置
│   ├── 📁 configs/
│   │   └── vermeer.config
│   └── 📁 patches/               # 内核补丁
├── 📁 edk2/                      # UEFI 配置
│   └── 📁 device/
│       └── 📁 vermeer/
│           ├── vermeer.dsc
│           ├── vermeer.fdf
│           └── build.sh
├── 📁 scripts/                   # 开发工具
│   ├── dts-compare.py            # DTS 对比分析
│   ├── analyze-panic.py          # Panic 日志分析
│   ├── extract-firmware.py       # 固件提取
│   └── gen-initramfs.sh          # initramfs 生成
├── 📁 docs/                      # 文档
│   ├── PORTING.md                # 移植指南
│   ├── FAQ.md                    # 常见问题
│   ├── USAGE.md                  # 使用说明
│   ├── SELF_HOSTED_RUNNER.md     # 自托管 Runner
│   └── DOCKER.md                 # Docker 使用
├── 📁 firmware/                  # 固件文件（从 MIUI 提取）
├── 📁 rootfs/                    # rootfs 配置
├── 📁 .vscode/                   # VS Code 配置
│   ├── settings.json
│   ├── extensions.json
│   └── launch.json
├── build-local.sh                # 本地一键构建
├── flash.sh                      # 刷机脚本
├── Makefile                      # 常用操作快捷方式
├── Dockerfile                    # Docker 构建环境
├── docker-compose.yml            # Docker Compose 配置
├── openclaw-config.yaml          # OpenClaw 集成配置
├── README.md                     # 项目说明
├── CONTRIBUTING.md               # 贡献指南
├── CHANGELOG.md                  # 更新日志
├── LICENSE                       # 许可证
└── .gitignore                    # Git 忽略规则
```

## 工作流说明

### 自动化流程

```
代码推送
    │
    ▼
┌─────────────────┐
│  DTS 检查       │ ──→ 编译验证、节点对比
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  内核编译       │ ──→ Image.gz + DTB + 模块
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  EDK2 编译      │ ──→ UEFI 固件
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  Rootfs 构建    │ ──→ Ubuntu ARM64 rootfs
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  打包发布       │ ──→ GitHub Release
└─────────────────┘
```

### 触发方式

| 触发条件 | 工作流 | 说明 |
|---------|--------|------|
| 推送到 main/dev | main.yml | 完整 CI |
| 修改 dts/ | dts-check.yml | DTS 验证 |
| 手动触发 | workflow_dispatch | 可选择构建目标 |
| 定时触发 | nightly.yml | 每日凌晨构建 |
| 多设备 | matrix-build.yml | 批量构建多个设备 |

## 开发工具链

### 本地开发

```bash
# 快速开始
make setup          # 安装依赖
make kernel         # 编译内核
make edk2           # 编译 EDK2
make build          # 完整构建
make flash          # 刷入设备
make dts-check      # 检查 DTS
```

### Docker 开发

```bash
make docker         # 使用 Docker 构建
docker-compose up   # 启动开发环境
```

### VS Code 集成

- 推荐扩展已配置
- 调试配置已预设
- 代码格式化规则已设置

## GitHub Actions 高级功能

### 可复用工作流

- `reusable/kernel-build.yml` — 通用内核编译
- `reusable/edk2-build.yml` — 通用 EDK2 编译

可被主工作流或其他仓库调用。

### 矩阵构建

支持同时构建多个设备：
```yaml
strategy:
  matrix:
    device: [vermeer, socrates, houji]
```

### 自托管 Runner

支持在本地机器（如你的 HX90G）上运行：
- 无时间限制
- 更大内存/存储
- ccache 持久化

详见 `docs/SELF_HOSTED_RUNNER.md`

## OpenClaw 集成

AI 辅助开发工具配置：
- 自动编译触发
- 日志分析
- DTS 对比
- 固件提取

配置见 `openclaw-config.yaml`

## 扩展计划

### 短期（1-2 个月）
- [ ] 完善 vermeer 设备树
- [ ] 首次启动到 shell
- [ ] 显示驱动调试

### 中期（3-6 个月）
- [ ] 触摸、音频支持
- [ ] WiFi/BT 工作
- [ ] 电源管理优化

### 长期（6-12 个月）
- [ ] 相机支持
- [ ] 5G 调制解调器
- [ ] 上游化提交

## 社区协作

### Issue 标签

| 标签 | 用途 |
|------|------|
| `bug` | 错误报告 |
| `enhancement` | 功能请求 |
| `dts` | 设备树相关 |
| `kernel` | 内核相关 |
| `edk2` | UEFI 相关 |
| `documentation` | 文档 |
| `good first issue` | 新手友好 |

### 分支策略

```
main          稳定分支，保护分支
  │
  ├── dev     开发分支，日常提交
  │   │
  │   ├── feature/dsi-panel    功能分支
  │   ├── feature/audio
  │   └── bugfix/gpio-keys
  │
  └── release/v0.1  发布分支
```

## 性能优化

### 编译加速

| 方法 | 效果 |
|------|------|
| ccache | 缓存编译结果，二次编译快 5-10 倍 |
| 自托管 Runner | 更多 CPU/内存，并行度更高 |
| Docker 缓存 | 层缓存，环境准备更快 |
| 增量编译 | 只编译修改的文件 |

### 存储优化

- 构建产物自动清理（30-90 天）
- Release 草稿模式，手动确认后发布
- 固件文件使用 Git LFS（大文件）

## 安全考虑

1. **Secrets 管理**
   - 使用 GitHub Secrets 存储敏感信息
   - 不在代码中硬编码密钥

2. **Runner 安全**
   - 自托管 Runner 仅用于私有仓库
   - Fork PR 不自动执行 Actions
   - 使用 Docker 隔离构建环境

3. **固件版权**
   - 固件文件不提交到 Git
   - 从官方 ROM 提取
   - 遵守设备厂商许可

## 联系方式

- GitHub Issues: 技术讨论
- GitHub Discussions: 一般讨论
- 提交 PR 参与贡献

## 许可证

- 内核补丁/DTS: GPL-2.0
- EDK2 配置: BSD-2-Clause
- 工具脚本: MIT
