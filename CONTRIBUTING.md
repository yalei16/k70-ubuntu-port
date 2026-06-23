# 贡献指南

感谢你对 K70 Ubuntu 移植项目的关注！

## 如何贡献

### 报告问题

1. 搜索现有 Issue，避免重复
2. 使用正确的模板创建 Issue
3. 提供尽可能详细的信息
4. 附上相关日志和截图

### 提交代码

1. Fork 本仓库
2. 创建功能分支: `git checkout -b feature/xxx`
3. 提交更改: `git commit -m "type: description"`
4. 推送分支: `git push origin feature/xxx`
5. 创建 Pull Request

### 提交规范

提交信息格式: `type: description`

type 类型:
- `dts`: 设备树修改
- `kernel`: 内核配置或补丁
- `edk2`: UEFI 固件配置
- `script`: 脚本修改
- `docs`: 文档更新
- `ci`: CI/CD 配置
- `fix`: 错误修复
- `feat`: 新功能

示例:
```
dts: fix gpio-keys node for vermeer
kernel: enable CONFIG_DRM_MSM_DPU for display
edk2: update memory map for 16GB variant
script: add firmware extraction tool
docs: update porting guide with audio section
```

### 代码风格

- DTS: 使用 Tab 缩进，对齐属性
- Shell: 遵循 Google Shell Style Guide
- Python: 遵循 PEP 8
- YAML: 2 空格缩进

### 测试要求

- DTS 修改必须通过 `dtc` 编译检查
- 内核配置修改必须能编译通过
- 脚本修改必须在本地测试

## 开发流程

### 设置开发环境

```bash
# 克隆仓库
git clone https://github.com/YOUR_USERNAME/k70-ubuntu-port.git
cd k70-ubuntu-port

# 安装依赖
sudo apt install -y     build-essential crossbuild-essential-arm64     device-tree-compiler git bc bison flex     libncurses-dev libssl-dev

# 配置 Git
 git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### 本地测试

```bash
# 编译 DTS
cd dts
dtc -I dts -O dtb -o sm8550-xiaomi-vermeer.dtb sm8550-xiaomi-vermeer.dts

# 完整编译
./build-local.sh v6.12 all

# 分析日志
python3 scripts/analyze-panic.py kernel.log
```

### 使用 GitHub Actions

推送代码后 Actions 会自动运行:
- DTS 检查
- 内核编译
- EDK2 编译

在 PR 页面查看检查结果。

## 硬件捐赠

如果你有 K70 相关硬件资源（如备用主板、调试工具），欢迎联系项目维护者。

## 联系方式

- GitHub Issues: 技术讨论和问题报告
- GitHub Discussions: 一般性讨论

## 行为准则

- 尊重他人，保持友善
- 专注于技术讨论
- 接受不同意见
- 帮助新手入门
