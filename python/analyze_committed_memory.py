#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#by raysuen
#v2.0
"""
金仓数据库内存分析工具 - 分析 Committed_AS 与进程实际内存使用
版本: 2.0
功能: 显示系统已提交内存(Committed_AS)与各进程的 RSS、Swap、PSS 对比
"""

import os
import sys
import argparse
import contextlib
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed
import logging

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


class MemoryAnalyzer:
    """内存分析器，封装所有读取和分析逻辑"""

    def __init__(self, top_n: int = 50, human_readable: bool = False):
        self.top_n = top_n
        self.human_readable = human_readable
        self.committed_as: Optional[int] = None
        self.processes: List[Dict] = []

    @staticmethod
    def get_committed_as() -> Optional[int]:
        """从 /proc/meminfo 获取 Committed_AS (KB)"""
        try:
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if line.startswith('Committed_AS'):
                        return int(line.split()[1])
        except Exception as e:
            logger.error(f"读取 /proc/meminfo 失败: {e}")
        return None

    @staticmethod
    def get_process_info(pid: int) -> Optional[Dict]:
        """获取单个进程的内存信息（RSS, Swap, PSS 等）"""
        try:
            status_path = Path(f"/proc/{pid}/status")
            if not status_path.exists():
                return None

            info = {'pid': pid, 'name': 'Unknown', 'vm_size': 0, 'vm_rss': 0, 'vm_swap': 0}
            # 读取 /proc/pid/status
            with status_path.open('r') as f:
                for line in f:
                    if line.startswith('Name:'):
                        info['name'] = line.split(':', 1)[1].strip()
                    elif line.startswith('VmSize:'):
                        info['vm_size'] = int(line.split()[1])
                    elif line.startswith('VmRSS:'):
                        info['vm_rss'] = int(line.split()[1])
                    elif line.startswith('VmSwap:'):
                        info['vm_swap'] = int(line.split()[1])
                    # 提前退出循环（如果已经获取所有需要字段）
                    if all(k in info for k in ('name', 'vm_size', 'vm_rss', 'vm_swap')):
                        break

            # 尝试读取 smaps_rollup 获取更准确的 RSS 和 PSS
            smaps_path = Path(f"/proc/{pid}/smaps_rollup")
            if smaps_path.exists():
                with smaps_path.open('r') as f:
                    content = f.read()
                    # 使用正则提取
                    import re
                    rss_match = re.search(r'Rss:\s+(\d+)', content)
                    if rss_match:
                        info['rss'] = int(rss_match.group(1))
                    swap_match = re.search(r'Swap:\s+(\d+)', content)
                    if swap_match:
                        info['swap'] = int(swap_match.group(1))
                    pss_match = re.search(r'Pss:\s+(\d+)', content)
                    if pss_match:
                        info['pss'] = int(pss_match.group(1))

            return info
        except (PermissionError, FileNotFoundError, ProcessLookupError):
            return None
        except Exception as e:
            logger.debug(f"读取进程 {pid} 失败: {e}")
            return None

    def collect_processes(self, parallel: bool = True, max_workers: int = 8) -> None:
        """收集所有进程的内存信息，支持并行加速"""
        pids = []
        for entry in Path('/proc').iterdir():
            if entry.is_dir() and entry.name.isdigit():
                pids.append(int(entry.name))

        logger.info(f"发现 {len(pids)} 个进程，开始收集信息...")

        if parallel and len(pids) > 100:
            with ThreadPoolExecutor(max_workers=max_workers) as executor:
                future_to_pid = {executor.submit(self.get_process_info, pid): pid for pid in pids}
                for future in as_completed(future_to_pid):
                    info = future.result()
                    if info:
                        self.processes.append(info)
        else:
            for pid in pids:
                info = self.get_process_info(pid)
                if info:
                    self.processes.append(info)

        # 按 RSS+Swap 排序
        self.processes.sort(key=lambda x: x.get('vm_rss', 0) + x.get('vm_swap', 0), reverse=True)
        logger.info(f"成功收集 {len(self.processes)} 个进程信息")

    def format_size(self, size_kb: int) -> str:
        """格式化大小，支持人类可读单位"""
        if not self.human_readable:
            return f"{size_kb:,} KB"
        if size_kb >= 1024 * 1024:
            return f"{size_kb / (1024 * 1024):.2f} GB"
        if size_kb >= 1024:
            return f"{size_kb / 1024:.2f} MB"
        return f"{size_kb} KB"

    def print_summary(self) -> None:
        """打印分析结果摘要"""
        if self.committed_as is None:
            self.committed_as = self.get_committed_as()
            if self.committed_as is None:
                logger.error("无法获取 Committed_AS，退出")
                return

        print("=" * 90)
        print("系统已提交内存(Committed_AS)及进程内存使用分析")
        print("=" * 90)
        print(f"系统总 Committed_AS: {self.format_size(self.committed_as)}")
        print("\n" + "=" * 90)
        print("各进程内存使用情况 (前{}个，按 RSS+Swap 排序):".format(self.top_n))
        print("=" * 90)

        # 打印表头
        print(f"{'PID':<8} {'进程名':<25} {'VmSize':>12} {'VmRSS':>12} {'VmSwap':>12} {'RSS+Swap':>12} {'占比%':>8}")
        print("-" * 100)

        total_rss_swap = 0
        shown = 0
        for proc in self.processes:
            if shown >= self.top_n:
                break
            pid = proc['pid']
            name = proc.get('name', 'Unknown')[:25]
            vm_size = proc.get('vm_size', 0)
            vm_rss = proc.get('vm_rss', 0)
            vm_swap = proc.get('vm_swap', 0)
            total = vm_rss + vm_swap
            total_rss_swap += total
            # 占比 = 进程的 VmSize 占 Committed_AS 的比例（更能反映承诺内存贡献）
            percent = (vm_size / self.committed_as) * 100 if self.committed_as > 0 else 0
            print(f"{pid:<8} {name:<25} {self.format_size(vm_size):>12} {self.format_size(vm_rss):>12} "
                  f"{self.format_size(vm_swap):>12} {self.format_size(total):>12} {percent:>7.2f}%")
            shown += 1

        print("\n" + "=" * 90)
        print("内存使用摘要:")
        print("-" * 90)
        print(f"所有进程总内存 (RSS+Swap): {self.format_size(total_rss_swap)}")
        if self.committed_as > total_rss_swap:
            diff = self.committed_as - total_rss_swap
            print(f"Committed_AS 与进程总内存差值: {self.format_size(diff)} (可能包含内核内存、slab、页缓存等)")
        else:
            print("警告: 进程总内存已超过 Committed_AS，可能统计有误")

    def print_pss_top(self) -> None:
        """按 PSS 排序显示前 20 个进程"""
        pss_procs = [p for p in self.processes if 'pss' in p]
        if not pss_procs:
            print("\n未获取到 PSS 信息（需要 smaps_rollup 支持）")
            return

        pss_procs.sort(key=lambda x: x.get('pss', 0), reverse=True)
        print("\n" + "=" * 90)
        print("按 PSS (按比例共享内存) 排序的前 20 个进程:")
        print("=" * 90)
        print(f"{'PID':<8} {'进程名':<25} {'PSS':>12} {'RSS':>12} {'差值(RSS-PSS)':>12}")
        print("-" * 70)

        for proc in pss_procs[:20]:
            pid = proc['pid']
            name = proc.get('name', 'Unknown')[:25]
            pss = proc.get('pss', 0)
            rss = proc.get('rss', proc.get('vm_rss', 0))
            diff = rss - pss
            print(f"{pid:<8} {name:<25} {self.format_size(pss):>12} {self.format_size(rss):>12} {self.format_size(diff):>12}")

    def save_output(self, filename: str) -> None:
        """将完整输出保存到文件"""
        try:
            with open(filename, 'w') as f:
                with contextlib.redirect_stdout(f):
                    self.print_summary()
                    self.print_pss_top()
            print(f"结果已保存到: {filename}")
        except Exception as e:
            logger.error(f"保存文件失败: {e}")


def main():
    parser = argparse.ArgumentParser(description="分析系统 Committed_AS 与进程实际内存使用")
    parser.add_argument('-n', '--top-n', type=int, default=50, help="显示的进程数量 (默认: 50)")
    parser.add_argument('-o', '--output', help="将结果保存到文件")
    parser.add_argument('--no-pss', action='store_true', help="不显示 PSS 排序")
    parser.add_argument('--human', action='store_true', help="使用人类可读的单位 (MB/GB)")
    parser.add_argument('--no-parallel', action='store_true', help="禁用并行读取进程信息")
    parser.add_argument('--workers', type=int, default=8, help="并行线程数 (默认: 8)")
    args = parser.parse_args()

    if os.geteuid() != 0:
        logger.warning("建议以 root 用户运行此脚本以获取完整进程信息")

    analyzer = MemoryAnalyzer(top_n=args.top_n, human_readable=args.human)
    analyzer.committed_as = analyzer.get_committed_as()
    if analyzer.committed_as is None:
        sys.exit(1)

    analyzer.collect_processes(parallel=not args.no_parallel, max_workers=args.workers)
    analyzer.print_summary()
    if not args.no_pss:
        analyzer.print_pss_top()

    if args.output:
        analyzer.save_output(args.output)


if __name__ == "__main__":
    main()