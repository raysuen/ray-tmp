#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#by raysuen
#v2.0
"""
金仓数据库内存分析工具 - 分析 Committed_AS 与 CommitLimit 关系
版本: 2.0
功能: 评估内核内存过载承诺策略、风险等级，支持趋势监控
"""

import os
import sys
import time
import argparse
import logging
from typing import Dict, Optional, List, Tuple
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


class CommitLimitAnalyzer:
    """CommitLimit 分析器"""

    def __init__(self, human_readable: bool = False):
        self.human_readable = human_readable
        self.meminfo: Dict[str, int] = {}
        self.overcommit_settings: Dict[str, int] = {}

    @staticmethod
    def read_meminfo() -> Dict[str, int]:
        """读取 /proc/meminfo 返回字典"""
        meminfo = {}
        try:
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if ':' not in line:
                        continue
                    key, value = line.split(':', 1)
                    # 提取数值（第一个数字段）
                    num_part = value.strip().split()[0]
                    meminfo[key.strip()] = int(num_part)
        except Exception as e:
            logger.error(f"读取 /proc/meminfo 失败: {e}")
        return meminfo

    def read_overcommit_settings(self) -> Dict[str, int]:
        """读取 /proc/sys/vm/overcommit_* 设置"""
        settings = {}
        try:
            with open('/proc/sys/vm/overcommit_memory', 'r') as f:
                settings['overcommit_memory'] = int(f.read().strip())
            with open('/proc/sys/vm/overcommit_ratio', 'r') as f:
                settings['overcommit_ratio'] = int(f.read().strip())
        except Exception as e:
            logger.error(f"读取 overcommit 设置失败: {e}")
        return settings

    def refresh(self) -> bool:
        """刷新当前内存数据"""
        self.meminfo = self.read_meminfo()
        self.overcommit_settings = self.read_overcommit_settings()
        return 'Committed_AS' in self.meminfo and 'CommitLimit' in self.meminfo

    def format_size(self, size_kb: int) -> str:
        if not self.human_readable:
            return f"{size_kb:,} KB"
        if size_kb >= 1024 * 1024:
            return f"{size_kb / (1024 * 1024):.2f} GB"
        if size_kb >= 1024:
            return f"{size_kb / 1024:.2f} MB"
        return f"{size_kb} KB"

    def analyze(self) -> Optional[Dict]:
        """执行分析并打印结果，返回关键指标"""
        if not self.refresh():
            logger.error("无法获取必要的内存信息")
            return None

        committed_as = self.meminfo.get('Committed_AS', 0)
        commit_limit = self.meminfo.get('CommitLimit', 0)
        mem_total = self.meminfo.get('MemTotal', 0)
        swap_total = self.meminfo.get('SwapTotal', 0)
        swap_free = self.meminfo.get('SwapFree', 0)

        usage_percent = (committed_as / commit_limit * 100) if commit_limit > 0 else 0
        available_commit = commit_limit - committed_as

        overcommit_mode = self.overcommit_settings.get('overcommit_memory', 0)
        overcommit_ratio = self.overcommit_settings.get('overcommit_ratio', 50)

        # 模式描述
        mode_desc = {
            0: "启发式过载 (默认)",
            1: "总是过载",
            2: "禁止过载 (严格限制)"
        }

        print("=" * 90)
        print("Committed_AS 与 CommitLimit 关系分析")
        print("=" * 90)

        print("\n内存基本信息:")
        print(f"  - 物理内存总量: {self.format_size(mem_total)}")
        print(f"  - 交换空间总量: {self.format_size(swap_total)}")
        print(f"  - 可用交换空间: {self.format_size(swap_free)}")

        print("\n过载承诺设置:")
        print(f"  - overcommit_memory: {overcommit_mode} ({mode_desc.get(overcommit_mode, '未知')})")
        print(f"  - overcommit_ratio: {overcommit_ratio}%")

        print("\n承诺内存分析:")
        print(f"  - Committed_AS (已提交内存): {self.format_size(committed_as)}")
        print(f"  - CommitLimit (提交限制): {self.format_size(commit_limit)}")
        print(f"  - 当前使用率: {usage_percent:.2f}%")
        print(f"  - 剩余承诺空间: {self.format_size(available_commit)}")

        # 理论计算验证（根据模式给出解释）
        if overcommit_mode == 0 or overcommit_mode == 2:
            theoretical = swap_total + (mem_total * overcommit_ratio / 100)
            print(f"  - 理论 CommitLimit (公式 swap + mem_total*ratio/100): {self.format_size(int(theoretical))}")
            if commit_limit != int(theoretical):
                print(f"  - 实际与理论差异: {self.format_size(commit_limit - int(theoretical))}")
        elif overcommit_mode == 1:
            print("  - 模式1 (总是过载): CommitLimit 通常为很大的值，实际不受限")

        # 风险评估
        print("\n风险评估:")
        if overcommit_mode == 0:
            if usage_percent > 90:
                print("  ⚠️  警告: 承诺内存使用率超过 90%，系统可能接近内存过载限制")
            elif usage_percent > 70:
                print(f"  ℹ️  提示: 承诺内存使用率较高 ({usage_percent:.1f}%)，建议关注")
            else:
                print(f"  ✓ 正常: 承诺内存使用率 {usage_percent:.1f}%，处于安全范围")
            if committed_as > (mem_total + swap_total):
                print("  ⚠️  警告: 已提交内存超过物理内存+交换空间总和")
        elif overcommit_mode == 2:
            if usage_percent >= 100:
                print("  🚨 严重: 承诺内存已达限制，新进程可能无法分配内存")
            elif usage_percent > 95:
                print(f"  ⚠️  警告: 承诺内存接近限制 ({usage_percent:.1f}%)")
            else:
                print(f"  ✓ 正常: 承诺内存使用率 {usage_percent:.1f}%")

        # 建议
        print("\n建议:")
        if available_commit < mem_total * 0.1 and overcommit_mode != 1:
            print("  - 剩余承诺空间不足物理内存的10%，建议增加交换空间或提高 overcommit_ratio")
        if swap_total == 0:
            print("  - 系统没有启用交换空间，内存压力可能较大，建议添加 swap")
        if overcommit_mode == 2 and usage_percent > 80:
            print("  - 严格过载模式下，请监控内存分配失败事件 (dmesg | grep -i 'out of memory')")

        return {
            'committed_as': committed_as,
            'commit_limit': commit_limit,
            'usage_percent': usage_percent,
            'available_commit': available_commit,
            'overcommit_mode': overcommit_mode,
            'risk_level': 'high' if usage_percent > 90 else 'medium' if usage_percent > 70 else 'low'
        }

    def show_top_processes(self, limit: int = 15) -> None:
        """显示按 VmSize 排序的前 limit 个进程"""
        print(f"\n{'=' * 90}")
        print(f"进程级别承诺内存分析 (前 {limit} 个，按 VmSize 排序)")
        print(f"{'=' * 90}")

        processes = []
        for pid_dir in Path('/proc').iterdir():
            if not pid_dir.is_dir() or not pid_dir.name.isdigit():
                continue
            pid = pid_dir.name
            status_file = pid_dir / 'status'
            if not status_file.exists():
                continue
            try:
                with status_file.open('r') as f:
                    name = None
                    vmsize = None
                    for line in f:
                        if line.startswith('Name:'):
                            name = line.split(':', 1)[1].strip()
                        elif line.startswith('VmSize:'):
                            vmsize = int(line.split()[1])
                            if name is not None:
                                break
                    if name and vmsize is not None:
                        processes.append({'pid': pid, 'name': name, 'vmsize': vmsize})
            except (PermissionError, ValueError):
                continue

        if not processes:
            print("未获取到任何进程信息")
            return

        processes.sort(key=lambda x: x['vmsize'], reverse=True)
        total_vmsize = sum(p['vmsize'] for p in processes)

        print(f"\n{'PID':<8} {'进程名':<25} {'VmSize':>15} {'占比':>8}")
        print("-" * 60)
        for proc in processes[:limit]:
            pid = proc['pid']
            name = proc['name'][:25]
            vmsize = self.format_size(proc['vmsize'])
            percent = (proc['vmsize'] / total_vmsize * 100) if total_vmsize > 0 else 0
            print(f"{pid:<8} {name:<25} {vmsize:>15} {percent:>7.2f}%")

        print(f"\n总计 {len(processes)} 个进程，总 VmSize: {self.format_size(total_vmsize)}")

        # 与 Committed_AS 对比
        committed_as = self.meminfo.get('Committed_AS', 0)
        if committed_as > 0:
            diff = committed_as - total_vmsize
            print(f"系统 Committed_AS: {self.format_size(committed_as)}")
            print(f"差值: {self.format_size(diff)} (内核内存、共享内存、缓存等)")

    def monitor_trend(self, interval: int = 5, count: int = 10) -> None:
        """监控 Committed_AS 和 CommitLimit 使用率的变化趋势"""
        print(f"\n{'=' * 90}")
        print(f"Committed_AS 趋势监控 (每 {interval} 秒采样，共 {count} 次)")
        print(f"{'=' * 90}")

        readings = []
        for i in range(count):
            if not self.refresh():
                logger.error("无法读取内存信息，停止监控")
                break
            committed_as = self.meminfo.get('Committed_AS', 0)
            commit_limit = self.meminfo.get('CommitLimit', 0)
            usage = (committed_as / commit_limit * 100) if commit_limit > 0 else 0
            timestamp = time.strftime('%H:%M:%S')
            readings.append((timestamp, committed_as, usage))
            print(f"[{timestamp}] Committed_AS: {self.format_size(committed_as)} ({usage:.1f}%)")

            if i < count - 1:
                time.sleep(interval)

        if len(readings) >= 2:
            first_ts, first_val, first_pct = readings[0]
            last_ts, last_val, last_pct = readings[-1]
            change = last_val - first_val
            change_pct = (change / first_val * 100) if first_val > 0 else 0
            print(f"\n趋势分析:")
            print(f"  开始: {self.format_size(first_val)} ({first_pct:.1f}%)")
            print(f"  结束: {self.format_size(last_val)} ({last_pct:.1f}%)")
            print(f"  变化: {self.format_size(change)} ({change_pct:+.2f}%)")
            if change > 0:
                print("  趋势: 上升 (可能内存泄漏或负载增加)")
            elif change < 0:
                print("  趋势: 下降")
            else:
                print("  趋势: 稳定")


def main():
    parser = argparse.ArgumentParser(description="分析 Committed_AS 与 CommitLimit 的关系及风险")
    parser.add_argument('-m', '--monitor', action='store_true', help="开启趋势监控模式")
    parser.add_argument('-i', '--interval', type=int, default=5, help="监控采样间隔(秒，默认5)")
    parser.add_argument('-c', '--count', type=int, default=10, help="监控采样次数(默认10)")
    parser.add_argument('-p', '--processes', type=int, default=15, help="显示前多少个进程的 VmSize (默认15)")
    parser.add_argument('--human', action='store_true', help="使用人类可读的单位")
    parser.add_argument('--no-proc', action='store_true', help="不显示进程列表")
    args = parser.parse_args()

    if os.geteuid() != 0:
        logger.warning("建议以 root 用户运行以获取完整进程信息")

    analyzer = CommitLimitAnalyzer(human_readable=args.human)

    if args.monitor:
        analyzer.monitor_trend(interval=args.interval, count=args.count)
    else:
        result = analyzer.analyze()
        if result and not args.no_proc:
            analyzer.show_top_processes(limit=args.processes)
        print("\n分析完成")


if __name__ == "__main__":
    main()