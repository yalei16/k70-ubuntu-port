# 常见问题

## Q: 为什么需要 EDK2/UEFI？

A: 小米的 Android Bootloader (ABL) 只能加载 Android 格式的 boot.img。
要启动标准 Linux 内核，需要：
1. 用 EDK2 替换 ABL（高风险）
2. 用 EDK2 链式加载（推荐）
3. 使用内核补丁绕过 ABL 检查（不稳定）

## Q: 可以保留 Android 双系统吗？

A: 可以。建议分区方案：
- sda31: Ubuntu rootfs
- sda32: ESP (rEFInd/UEFI)
- sda33: 数据分区
- 保留原有 Android 分区

## Q: 主线内核支持哪些硬件？

A: SM8550 主线支持（截至 2026）：
- ✅ CPU/GPU (Adreno 740)
- ✅ UFS 4.0
- ✅ USB3 + DP Altmode
- ✅ PCIe (WiFi/NVMe)
- ✅ 基础音频
- ✅ 电源管理
- ❌ 相机（需要额外工作）
- ❌ 指纹（低优先级）
- ❌ 5G 调制解调器（复杂）

## Q: 编译失败怎么办？

A: 检查：
1. 交叉编译工具链是否安装
2. 内核配置是否正确
3. 设备树语法是否有误
4. 查看 `build/linux-src/compile.log`

## Q: 如何调试启动问题？

A: 方法：
1. 串口调试（推荐）
2. 使用 `earlyprintk` 内核参数
3. 检查 `last_kmsg`（如果能进入 recovery）
4. 使用 QEMU 模拟（有限）

## Q: 固件从哪里获取？

A: 从 MIUI 官方 ROM 提取：
```bash
# 提取固件
./payload-dumper-go ROM.zip

# 挂载 vendor 分区
simg2img vendor.img vendor.raw
mount -o loop vendor.raw /mnt/vendor

# 复制固件
cp -r /mnt/vendor/lib/firmware/qcom/sm8550/ ./firmware/
```
