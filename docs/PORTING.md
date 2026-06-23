# K70 Ubuntu 移植指南

## 阶段一：环境准备（第 1 周）

### 1.1 解锁 Bootloader
- 在小米官网申请解锁权限
- 等待 7 天
- 使用小米解锁工具解锁

### 1.2 安装编译环境
```bash
sudo apt update
sudo apt install -y     build-essential crossbuild-essential-arm64     device-tree-compiler git bc bison flex     libncurses-dev libssl-dev     abootimg fastboot adb     python3 python3-pip
```

### 1.3 提取 MIUI 固件
```bash
# 下载 MIUI 完整 ROM
# 解压后提取关键镜像
magiskboot unpack boot.img
magiskboot dtb boot.img extract dtbs/

# 反编译 DTB
for dtb in dtbs/*.dtb; do
    dtc -I dtb -O dts -o "$(basename $dtb .dtb).dts" "$dtb"
done
```

## 阶段二：设备树开发（第 2-3 周）

### 2.1 分析现有 DTS
- 对比小米平板 6S Pro 的 DTS
- 标记差异节点
- 提取 K70 特有的 GPIO、Regulator、Panel 配置

### 2.2 修改 vermeer.dts
关键修改点：
1. **显示面板**: 替换为 K70 的 AMOLED 参数
2. **触摸**: 确认芯片型号（Goodix GT9916?）
3. **按键**: 调整 GPIO 编号
4. **电池**: 配置 5000mAh + 120W 快充
5. **音频**: 添加 Soundwire/WSA 配置

### 2.3 验证 DTS
```bash
cd dts
dtc -I dts -O dtb -o sm8550-xiaomi-vermeer.dtb sm8550-xiaomi-vermeer.dts
```

## 阶段三：内核编译（第 3-4 周）

### 3.1 使用本地脚本
```bash
./build-local.sh v6.12 kernel
```

### 3.2 或使用 GitHub Actions
- 推送代码到 main 分支
- Actions 自动编译
- 下载编译产物

## 阶段四：EDK2 UEFI（第 4-5 周）

### 4.1 配置设备
- 修改 `edk2/device/vermeer/vermeer.dsc`
- 调整内存映射
- 添加设备驱动

### 4.2 编译
```bash
cd edk2/device/vermeer
./build.sh
```

## 阶段五：首次启动（第 5-6 周）

### 5.1 刷入测试
```bash
./flash.sh
```

### 5.2 调试
- 连接 USB 串口
- 使用 `minicom -D /dev/ttyUSB0 -b 115200`
- 查看启动日志

### 5.3 常见问题
- **黑屏**: 检查 DSI 面板配置
- **无法启动**: 检查内存地址
- **内核 panic**: 检查设备树节点

## 阶段六：完善功能（第 6-8 周）

### 6.1 显示
- 调整面板时序
- 配置 DSC 压缩
- 校准色彩

### 6.2 触摸
- 确认触摸芯片
- 配置中断和复位 GPIO

### 6.3 音频
- 配置 Soundwire 拓扑
- 测试扬声器和麦克风

### 6.4 网络
- 提取 WiFi 固件
- 配置蓝牙

### 6.5 充电
- 配置 120W 快充
- 温度监控

## 参考

- [PostmarketOS 移植指南](https://wiki.postmarketos.org/wiki/Porting_to_a_new_device)
- [linux-msm 文档](https://github.com/linux-msm)
- [edk2-msm Wiki](https://github.com/edk2-porting/edk2-msm/wiki)
