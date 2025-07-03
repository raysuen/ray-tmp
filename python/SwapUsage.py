#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# @Time :  2025年6月25日
# @Author : raysuen
# @version 1.0
# @Blog ：http://blog.itpub.net/28572479/

import os
import re
import sys
from collections import defaultdict

def get_process_swap():
    """获取所有进程的Swap使用情况"""
    process_swap = defaultdict(int)
    pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]
    
    for pid in pids:
        try:
            # 获取进程命令
            with open(f'/proc/{pid}/cmdline', 'r') as f:
                cmd = f.read().replace('\x00', ' ').strip()
                if not cmd:  # 内核线程
                    with open(f'/proc/{pid}/comm', 'r') as cf:
                        cmd = f'[{cf.read().strip()}]'
            
            # 计算Swap使用量
            swap_total = 0
            smaps_path = f'/proc/{pid}/smaps'
            if os.path.exists(smaps_path):
                with open(smaps_path, 'r') as f:
                    for line in f:
                        if line.startswith('Swap:'):
                            swap_kb = int(line.split()[1])
                            swap_total += swap_kb
            
            # 只记录使用Swap的进程
            if swap_total > 0:
                process_swap[pid] = {
                    'cmd': cmd,
                    'swap_kb': swap_total,
                    'swap_mb': swap_total / 1024
                }
                
        except (FileNotFoundError, ProcessLookupError):
            # 进程已终止，跳过
            continue
        except Exception as e:
            print(f"Error processing PID {pid}: {str(e)}", file=sys.stderr)
    
    return process_swap

def format_output(process_swap):
    """格式化输出结果"""
    # 按Swap使用量排序
    sorted_processes = sorted(
        process_swap.items(),
        key=lambda x: x[1]['swap_kb'],
        reverse=True
    )
    
    # 打印表头
    print(f"{'PID':<8} {'SWAP(kB)':>10} {'SWAP(MB)':>10} {'COMMAND':<60}")
    print("-" * 90)
    
    # 打印每个进程的信息
    for pid, info in sorted_processes:
        print(f"{pid:<8} {info['swap_kb']:>10} {info['swap_mb']:>10.1f} {info['cmd'][:60]:<60}")
    
    # 打印统计信息
    total_swap_kb = sum(info['swap_kb'] for info in process_swap.values())
    total_swap_mb = total_swap_kb / 1024
    print("\n" + "=" * 90)
    print(f"TOTAL SWAP USAGE: {total_swap_kb} kB ({total_swap_mb:.1f} MB)")
    print(f"PROCESSES USING SWAP: {len(process_swap)}")

if __name__ == "__main__":
    # 检查权限
    if os.geteuid() != 0:
        print("WARNING: Some process information may be unavailable without root privileges", file=sys.stderr)
    
    process_swap = get_process_swap()
    
    if not process_swap:
        print("No processes are currently using Swap memory.")
        sys.exit(0)
    
    format_output(process_swap)


