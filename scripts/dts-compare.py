#!/usr/bin/env python3
"""
K70 Ubuntu Port - DTS 对比分析工具
对比 vermeer DTS 和小米平板 6S Pro 参考 DTS
"""

import sys
import os
import re
from collections import defaultdict

class DTSComparator:
    def __init__(self, vermeer_path, reference_path):
        self.vermeer_path = vermeer_path
        self.reference_path = reference_path
        self.vermeer_nodes = {}
        self.reference_nodes = {}

    def parse_dts(self, filepath):
        """解析 DTS 文件，提取节点和属性"""
        nodes = {}
        current_node = None
        current_props = {}
        node_stack = []

        with open(filepath, 'r') as f:
            content = f.read()

        # 移除注释
        content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
        content = re.sub(r'//.*?$', '', content, flags=re.MULTILINE)

        lines = content.split('\n')

        for line in lines:
            line = line.strip()
            if not line:
                continue

            # 检测节点开始
            node_match = re.match(r'^(\w[\w@-]*)\s*\{', line)
            if node_match and not line.startswith('/'):
                node_name = node_match.group(1)
                if node_stack:
                    full_name = '->'.join(node_stack) + '->' + node_name
                else:
                    full_name = node_name
                node_stack.append(node_name)
                current_node = full_name
                current_props = {}
                nodes[current_node] = current_props
                continue

            # 检测节点结束
            if line == '};':
                if node_stack:
                    node_stack.pop()
                if node_stack:
                    current_node = '->'.join(node_stack)
                else:
                    current_node = None
                continue

            # 检测属性
            if current_node and '=' in line:
                prop_match = re.match(r'(\w+)\s*=', line)
                if prop_match:
                    prop_name = prop_match.group(1)
                    current_props[prop_name] = line

        return nodes

    def compare(self):
        """对比两个 DTS"""
        print("=" * 60)
        print("K70 (vermeer) DTS 对比分析报告")
        print("=" * 60)
        print()

        self.vermeer_nodes = self.parse_dts(self.vermeer_path)
        self.reference_nodes = self.parse_dts(self.reference_path)

        vermeer_set = set(self.vermeer_nodes.keys())
        reference_set = set(self.reference_nodes.keys())

        # 统计
        print(f"vermeer 节点总数: {len(vermeer_set)}")
        print(f"参考节点总数: {len(reference_set)}")
        print()

        # 共同节点
        common = vermeer_set & reference_set
        print(f"共同节点: {len(common)}")
        print()

        # vermeer 缺少的节点
        missing = reference_set - vermeer_set
        if missing:
            print("-" * 60)
            print(f"[警告] vermeer 缺少 {len(missing)} 个节点:")
            print("-" * 60)
            for node in sorted(missing):
                print(f"  - {node}")
                # 显示参考中的属性
                props = self.reference_nodes[node]
                if props:
                    print(f"    属性: {', '.join(props.keys())}")
            print()

        # vermeer 新增的节点
        extra = vermeer_set - reference_set
        if extra:
            print("-" * 60)
            print(f"[信息] vermeer 新增 {len(extra)} 个节点:")
            print("-" * 60)
            for node in sorted(extra):
                print(f"  + {node}")
            print()

        # 属性差异
        print("-" * 60)
        print("[分析] 共同节点的属性差异:")
        print("-" * 60)

        diff_count = 0
        for node in sorted(common):
            v_props = self.vermeer_nodes[node]
            r_props = self.reference_nodes[node]

            v_keys = set(v_props.keys())
            r_keys = set(r_props.keys())

            missing_props = r_keys - v_keys
            extra_props = v_keys - r_keys

            if missing_props or extra_props:
                diff_count += 1
                print(f"\n  节点: {node}")
                if missing_props:
                    print(f"    缺少属性: {', '.join(missing_props)}")
                if extra_props:
                    print(f"    新增属性: {', '.join(extra_props)}")

        if diff_count == 0:
            print("  无差异")

        print()
        print("=" * 60)
        print("对比完成")
        print("=" * 60)

        # 生成建议
        print()
        print("-" * 60)
        print("[建议] 需要关注的节点:")
        print("-" * 60)

        critical_nodes = [
            'memory', 'reserved-memory', 'soc', 'pm8550', 'pmk8550',
            'dsi', 'mdss', 'usb', 'pcie', 'ufs_mem_hc',
            'cpu', 'gpu', 'audio', 'bluetooth', 'wifi'
        ]

        for node in critical_nodes:
            if node not in vermeer_set and node in reference_set:
                print(f"  ⚠️  缺少关键节点: {node}")
            elif node in vermeer_set:
                print(f"  ✓ {node}")

def main():
    if len(sys.argv) < 3:
        print("用法: python3 dts-compare.py <vermeer.dts> <reference.dts>")
        sys.exit(1)

    vermeer = sys.argv[1]
    reference = sys.argv[2]

    if not os.path.exists(vermeer):
        print(f"错误: 找不到文件 {vermeer}")
        sys.exit(1)

    if not os.path.exists(reference):
        print(f"错误: 找不到文件 {reference}")
        sys.exit(1)

    comparator = DTSComparator(vermeer, reference)
    comparator.compare()

if __name__ == '__main__':
    main()
