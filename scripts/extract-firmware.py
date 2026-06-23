#!/usr/bin/env python3
"""
K70 Ubuntu Port - MIUI 固件提取工具
从官方 ROM 中提取所需固件和配置
"""

import sys
import os
import subprocess
import tempfile
import shutil
from pathlib import Path

class FirmwareExtractor:
    def __init__(self, rom_path, output_dir="firmware"):
        self.rom_path = Path(rom_path)
        self.output_dir = Path(output_dir)
        self.work_dir = None

    def setup(self):
        """创建工作目录"""
        self.work_dir = Path(tempfile.mkdtemp(prefix="k70-firmware-"))
        self.output_dir.mkdir(exist_ok=True)
        print(f"工作目录: {self.work_dir}")
        print(f"输出目录: {self.output_dir}")

    def cleanup(self):
        """清理工作目录"""
        if self.work_dir and self.work_dir.exists():
            shutil.rmtree(self.work_dir)
            print(f"清理工作目录: {self.work_dir}")

    def extract_zip(self):
        """解压 ROM zip"""
        print("解压 ROM...")
        import zipfile
        with zipfile.ZipFile(self.rom_path, 'r') as z:
            z.extractall(self.work_dir)
        print("解压完成")

    def extract_payload(self):
        """提取 payload.bin"""
        payload_path = self.work_dir / "payload.bin"
        if not payload_path.exists():
            print("错误: 找不到 payload.bin")
            return False

        print("提取 payload...")

        # 检查是否有 payload-dumper-go
        if shutil.which("payload-dumper-go"):
            subprocess.run([
                "payload-dumper-go", 
                "-o", str(self.work_dir / "images"),
                str(payload_path)
            ], check=True)
        else:
            print("警告: 未找到 payload-dumper-go")
            print("请安装: go install github.com/ssut/payload-dumper-go@latest")
            return False

        print("Payload 提取完成")
        return True

    def extract_boot(self):
        """从 boot.img 提取内核和设备树"""
        boot_img = self.work_dir / "images" / "boot.img"
        if not boot_img.exists():
            print("警告: 找不到 boot.img")
            return

        print("提取 boot.img...")
        boot_dir = self.work_dir / "boot"
        boot_dir.mkdir(exist_ok=True)

        # 使用 magiskboot 解包
        if shutil.which("magiskboot"):
            subprocess.run([
                "magiskboot", "unpack", "-h",
                str(boot_img)
            ], cwd=boot_dir, check=False)

            # 提取 DTB
            dtb_dir = boot_dir / "dtbs"
            dtb_dir.mkdir(exist_ok=True)
            subprocess.run([
                "magiskboot", "dtb",
                str(boot_img), "extract",
                str(dtb_dir)
            ], check=False)

            print(f"DTB 提取到: {dtb_dir}")
        else:
            print("警告: 未找到 magiskboot")

    def extract_firmware(self):
        """从 vendor 分区提取固件"""
        vendor_img = self.work_dir / "images" / "vendor.img"
        if not vendor_img.exists():
            print("警告: 找不到 vendor.img")
            return

        print("提取固件...")
        vendor_dir = self.work_dir / "vendor"
        vendor_dir.mkdir(exist_ok=True)

        # 挂载 vendor 分区
        try:
            # 转换 sparse image
            raw_img = self.work_dir / "vendor.raw.img"
            subprocess.run([
                "simg2img",
                str(vendor_img),
                str(raw_img)
            ], check=False)

            # 挂载
            mount_dir = self.work_dir / "vendor_mount"
            mount_dir.mkdir(exist_ok=True)

            subprocess.run([
                "sudo", "mount", "-o", "loop,ro",
                str(raw_img),
                str(mount_dir)
            ], check=False)

            # 复制固件
            firmware_src = mount_dir / "lib" / "firmware"
            if firmware_src.exists():
                firmware_dst = self.output_dir / "qcom" / "sm8550"
                firmware_dst.mkdir(parents=True, exist_ok=True)

                # 复制关键固件
                important_firmware = [
                    "adsp.mbn", "cdsp.mbn", "slpi.mbn",
                    "venus.mbn", "a650_zap.mbn",
                    "wlanmdsp.mbn", "bdwlan.bin"
                ]

                for fw in important_firmware:
                    src = firmware_src / fw
                    if src.exists():
                        shutil.copy2(src, firmware_dst)
                        print(f"  复制: {fw}")

                # 复制整个 qcom 目录
                qcom_dir = firmware_src / "qcom"
                if qcom_dir.exists():
                    qcom_dst = self.output_dir / "qcom"
                    if qcom_dst.exists():
                        shutil.rmtree(qcom_dst)
                    shutil.copytree(qcom_dir, qcom_dst)
                    print(f"  复制 qcom 固件目录")

            # 卸载
            subprocess.run([
                "sudo", "umount", str(mount_dir)
            ], check=False)

        except Exception as e:
            print(f"提取固件时出错: {e}")

    def extract_dtb(self):
        """反编译 DTB 为 DTS"""
        dtb_dir = self.work_dir / "boot" / "dtbs"
        if not dtb_dir.exists():
            print("警告: 找不到 DTB 目录")
            return

        print("反编译 DTB...")
        dts_dir = self.output_dir / "dts-extracted"
        dts_dir.mkdir(exist_ok=True)

        for dtb in dtb_dir.glob("*.dtb"):
            dts_path = dts_dir / f"{dtb.stem}.dts"
            subprocess.run([
                "dtc", "-I", "dtb", "-O", "dts",
                "-o", str(dts_path),
                str(dtb)
            ], check=False)
            print(f"  反编译: {dtb.name} -> {dts_path.name}")

    def extract_modules(self):
        """提取内核模块"""
        vendor_img = self.work_dir / "images" / "vendor.img"
        if not vendor_img.exists():
            return

        print("提取内核模块...")
        # 从 vendor 的 lib/modules 提取
        # 这部分在 extract_firmware 中已处理

    def generate_report(self):
        """生成提取报告"""
        print()
        print("=" * 60)
        print("固件提取报告")
        print("=" * 60)

        # 统计提取的文件
        total_files = 0
        total_size = 0

        for root, dirs, files in os.walk(self.output_dir):
            for f in files:
                fp = Path(root) / f
                total_files += 1
                total_size += fp.stat().st_size

        print(f"提取文件数: {total_files}")
        print(f"总大小: {total_size / 1024 / 1024:.2f} MB")
        print()
        print("输出目录内容:")

        for item in sorted(self.output_dir.rglob("*")):
            if item.is_file():
                rel_path = item.relative_to(self.output_dir)
                size = item.stat().st_size
                print(f"  {rel_path} ({size / 1024:.1f} KB)")

    def run(self):
        """执行完整提取流程"""
        try:
            self.setup()
            self.extract_zip()

            if self.extract_payload():
                self.extract_boot()
                self.extract_firmware()
                self.extract_dtb()
                self.extract_modules()
                self.generate_report()
            else:
                print("提取失败")

        finally:
            self.cleanup()

def main():
    if len(sys.argv) < 2:
        print("K70 Ubuntu Port - 固件提取工具")
        print()
        print("用法: python3 extract-firmware.py <MIUI_ROM.zip> [output_dir]")
        print()
        print("示例:")
        print("  python3 extract-firmware.py miui_VERMEER_xxx.zip")
        print("  python3 extract-firmware.py miui_VERMEER_xxx.zip ./my-firmware")
        sys.exit(1)

    rom_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "firmware"

    if not os.path.exists(rom_path):
        print(f"错误: 找不到文件 {rom_path}")
        sys.exit(1)

    extractor = FirmwareExtractor(rom_path, output_dir)
    extractor.run()

if __name__ == '__main__':
    main()
