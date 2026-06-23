#!/usr/bin/env python3
"""
K70 Ubuntu Port - 内核 Panic 日志分析工具
自动识别常见错误模式并给出修复建议
"""

import sys
import re
from collections import Counter

class PanicAnalyzer:
    def __init__(self, log_path):
        self.log_path = log_path
        self.log_content = ""
        self.errors = []
        self.warnings = []

    def load_log(self):
        """加载日志文件"""
        with open(self.log_path, 'r', errors='ignore') as f:
            self.log_content = f.read()
        print(f"加载日志: {len(self.log_content)} 字符")

    def analyze_panic(self):
        """分析 panic 类型"""
        panic_patterns = [
            (r'Unable to handle kernel (\w+) at virtual address', 
             "内核访问无效地址", "critical"),
            (r'Kernel panic - not syncing: (.*)', 
             "内核 panic", "critical"),
            (r'Oops: (.*)', 
             "内核 Oops", "critical"),
            (r'Watchdog detected hard LOCKUP', 
             "硬锁死", "critical"),
            (r'Out of memory: Kill process', 
             "内存不足", "warning"),
            (r'Call trace:', 
             "调用栈跟踪", "info"),
        ]

        for pattern, desc, level in panic_patterns:
            matches = re.findall(pattern, self.log_content)
            if matches:
                self.errors.append({
                    'type': desc,
                    'level': level,
                    'matches': matches,
                    'count': len(matches)
                })

    def analyze_device_tree(self):
        """分析设备树相关错误"""
        dt_patterns = [
            (r'Failed to resolve (.*)', 
             "设备树解析失败", "检查 phandle 引用"),
            (r'missing (.*) property', 
             "缺少必要属性", "添加缺失属性"),
            (r'Invalid (.*) property', 
             "属性值无效", "修正属性值"),
            (r'gpio.*not found', 
             "GPIO 未找到", "检查 GPIO 定义"),
            (r'regulator.*not found', 
             "Regulator 未找到", "检查电源配置"),
        ]

        for pattern, desc, suggestion in dt_patterns:
            matches = re.findall(pattern, self.log_content, re.IGNORECASE)
            if matches:
                self.warnings.append({
                    'type': desc,
                    'suggestion': suggestion,
                    'matches': matches
                })

    def analyze_drivers(self):
        """分析驱动加载错误"""
        driver_patterns = [
            (r'(\w+): probe of (.*) failed', 
             "驱动探测失败", "检查硬件连接和配置"),
            (r'(\w+): (.*) not found', 
             "设备未找到", "检查设备树节点"),
            (r'Failed to load firmware (.*)', 
             "固件加载失败", "从 MIUI 提取固件"),
            (r'(\w+): timeout', 
             "驱动超时", "检查时钟和复位配置"),
        ]

        for pattern, desc, suggestion in driver_patterns:
            matches = re.findall(pattern, self.log_content, re.IGNORECASE)
            if matches:
                self.warnings.append({
                    'type': desc,
                    'suggestion': suggestion,
                    'matches': matches
                })

    def analyze_boot(self):
        """分析启动阶段错误"""
        boot_patterns = [
            (r'VFS: Cannot open root device', 
             "无法打开根设备", "检查 root= 参数和分区"),
            (r'No filesystem could mount root', 
             "无法挂载根文件系统", "检查文件系统类型"),
            (r'Failed to mount (.*)', 
             "挂载失败", "检查 fstab 配置"),
            (r'init not found', 
             "找不到 init", "检查 rootfs 完整性"),
        ]

        for pattern, desc, suggestion in boot_patterns:
            if re.search(pattern, self.log_content, re.IGNORECASE):
                self.errors.append({
                    'type': desc,
                    'level': 'critical',
                    'suggestion': suggestion
                })

    def generate_report(self):
        """生成分析报告"""
        print("=" * 60)
        print("K70 内核启动日志分析报告")
        print("=" * 60)
        print()

        # 错误摘要
        if self.errors:
            print("-" * 60)
            print(f"[严重错误] 发现 {len(self.errors)} 个严重问题:")
            print("-" * 60)
            for err in self.errors:
                print(f"\n  ❌ {err['type']}")
                if 'matches' in err:
                    for match in err['matches'][:3]:  # 只显示前3个
                        print(f"     - {match}")
                if 'suggestion' in err:
                    print(f"     建议: {err['suggestion']}")

        # 警告
        if self.warnings:
            print()
            print("-" * 60)
            print(f"[警告] 发现 {len(self.warnings)} 个潜在问题:")
            print("-" * 60)
            for warn in self.warnings:
                print(f"\n  ⚠️  {warn['type']}")
                if 'matches' in warn:
                    for match in warn['matches'][:3]:
                        print(f"     - {match}")
                print(f"     建议: {warn['suggestion']}")

        # 统计
        print()
        print("-" * 60)
        print("[统计] 错误类型分布:")
        print("-" * 60)

        all_types = [e['type'] for e in self.errors] + [w['type'] for w in self.warnings]
        type_counts = Counter(all_types)

        for t, count in type_counts.most_common():
            print(f"  {t}: {count} 次")

        # 修复建议汇总
        print()
        print("=" * 60)
        print("[修复建议汇总]")
        print("=" * 60)

        suggestions = []
        for err in self.errors:
            if 'suggestion' in err:
                suggestions.append(err['suggestion'])
        for warn in self.warnings:
            suggestions.append(warn['suggestion'])

        unique_suggestions = list(set(suggestions))
        for i, suggestion in enumerate(unique_suggestions, 1):
            print(f"{i}. {suggestion}")

        # 如果没有任何问题
        if not self.errors and not self.warnings:
            print()
            print("✅ 未检测到明显错误！")
            print("如果设备仍无法启动，请检查:")
            print("  - 串口连接是否正确")
            print("  - 波特率是否为 115200")
            print("  - 是否捕获完整启动日志")

def main():
    if len(sys.argv) < 2:
        print("用法: python3 analyze-panic.py <kernel-log.txt>")
        print("  或: dmesg | python3 analyze-panic.py -")
        sys.exit(1)

    log_path = sys.argv[1]

    if log_path == '-':
        # 从标准输入读取
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.log') as f:
            f.write(sys.stdin.read())
            log_path = f.name

    if not os.path.exists(log_path):
        print(f"错误: 找不到文件 {log_path}")
        sys.exit(1)

    analyzer = PanicAnalyzer(log_path)
    analyzer.load_log()
    analyzer.analyze_panic()
    analyzer.analyze_device_tree()
    analyzer.analyze_drivers()
    analyzer.analyze_boot()
    analyzer.generate_report()

if __name__ == '__main__':
    main()
