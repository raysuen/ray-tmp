#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
from pathlib import Path

def get_committed_as():
    """从/proc/meminfo获取Committed_AS值"""
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                if line.startswith('Committed_AS'):
                    # 提取数值，转换为KB
                    value = line.split(':')[1].strip().split()[0]
                    return int(value)  # 单位是KB
    except Exception as e:
        print(f"读取/proc/meminfo失败: {e}")
    return None

def get_process_memory_info(pid):
    """获取单个进程的内存信息"""
    try:
        # 读取进程状态
        status_path = f'/proc/{pid}/status'
        if not os.path.exists(status_path):
            return None
        
        info = {'pid': pid}
        
        with open(status_path, 'r') as f:
            for line in f:
                if line.startswith('Name:'):
                    info['name'] = line.split(':')[1].strip()
                elif line.startswith('VmSize:'):
                    # 虚拟内存大小，单位是KB
                    info['vm_size'] = int(line.split(':')[1].strip().split()[0])
                elif line.startswith('VmRSS:'):
                    # 物理内存大小，单位是KB
                    info['vm_rss'] = int(line.split(':')[1].strip().split()[0])
                elif line.startswith('VmSwap:'):
                    # 交换内存大小，单位是KB
                    info['vm_swap'] = int(line.split(':')[1].strip().split()[0])
        
        # 读取smaps_rollup获取更准确的内存使用（如果可用）
        smaps_path = f'/proc/{pid}/smaps_rollup'
        if os.path.exists(smaps_path):
            with open(smaps_path, 'r') as f:
                content = f.read()
                # 尝试查找RSS
                rss_match = re.search(r'Rss:\s+(\d+)\s+kB', content)
                if rss_match:
                    info['rss'] = int(rss_match.group(1))
                # 尝试查找Swap
                swap_match = re.search(r'Swap:\s+(\d+)\s+kB', content)
                if swap_match:
                    info['swap'] = int(swap_match.group(1))
                # 尝试查找Pss（按比例共享内存）
                pss_match = re.search(r'Pss:\s+(\d+)\s+kB', content)
                if pss_match:
                    info['pss'] = int(pss_match.group(1))
        
        return info
    except (PermissionError, FileNotFoundError, ProcessLookupError):
        # 进程可能已经结束或无权限访问
        return None
    except Exception as e:
        print(f"读取进程 {pid} 信息失败: {e}")
        return None

def get_all_processes():
    """获取所有进程的PID列表"""
    pids = []
    try:
        for entry in os.listdir('/proc'):
            if entry.isdigit():
                pids.append(int(entry))
    except Exception as e:
        print(f"读取/proc目录失败: {e}")
    return pids

def analyze_memory_usage():
    """分析内存使用情况"""
    print("=" * 80)
    print("系统已提交内存(Committed_AS)及进程内存使用分析")
    print("=" * 80)
    
    # 获取系统Committed_AS
    committed_as = get_committed_as()
    if committed_as is not None:
        print(f"系统总Committed_AS: {committed_as:,} KB ({committed_as/1024:,.2f} MB, {committed_as/1024/1024:,.2f} GB)")
    else:
        print("无法获取Committed_AS")
    
    print("\n" + "=" * 80)
    print("各进程内存使用情况:")
    print("=" * 80)
    
    # 获取所有进程
    pids = get_all_processes()
    print(f"发现 {len(pids)} 个进程")
    
    # 收集进程信息
    processes = []
    for pid in pids:
        info = get_process_memory_info(pid)
        if info:
            processes.append(info)
    
    # 按内存使用量排序
    processes.sort(key=lambda x: x.get('vm_rss', 0) + x.get('vm_swap', 0), reverse=True)
    
    # 打印表头
    print(f"\n{'PID':<8} {'进程名':<25} {'VMSize(KB)':>12} {'VMRSS(KB)':>12} {'VMSwap(KB)':>12} {'总计(KB)':>12} {'占比%':>8}")
    print("-" * 90)
    
    # 计算所有进程总内存
    total_memory = 0
    process_details = []
    
    for proc in processes:
        vm_size = proc.get('vm_size', 0)
        vm_rss = proc.get('vm_rss', 0)
        vm_swap = proc.get('vm_swap', 0)
        total = vm_rss + vm_swap
        
        total_memory += total
        
        # 存储详细信息用于后续计算占比
        proc['total'] = total
        process_details.append(proc)
    
    # 计算并显示每个进程的详细信息
    top_consumers = 0
    for proc in process_details[:50]:  # 只显示前50个进程
        pid = proc['pid']
        name = proc.get('name', 'Unknown')[:25]
        vm_size = proc.get('vm_size', 0)
        vm_rss = proc.get('vm_rss', 0)
        vm_swap = proc.get('vm_swap', 0)
        total = proc['total']
        
        # 计算占比
        if committed_as and committed_as > 0:
            percentage = (total / committed_as) * 100
        else:
            percentage = 0
        
        print(f"{pid:<8} {name:<25} {vm_size:>12,} {vm_rss:>12,} {vm_swap:>12,} {total:>12,} {percentage:>7.2f}%")
        
        top_consumers += total
    
    # 显示摘要信息
    print("\n" + "=" * 80)
    print("内存使用摘要:")
    print("-" * 80)
    
    if committed_as and total_memory > 0:
        print(f"前50个进程占用内存: {top_consumers:,} KB ({top_consumers/committed_as*100:.1f}% of Committed_AS)")
        print(f"所有进程总内存(RSS+Swap): {total_memory:,} KB")
        print(f"Committed_AS与进程总内存差值: {committed_as - total_memory:,} KB")
        
        # 差值可能包括内核内存、缓存等
        if committed_as > total_memory:
            print("注意: 差值可能包括内核内存、slab缓存、页缓存等")
    
    # 如果可用，显示按PSS排序的信息（更准确）
    print("\n" + "=" * 80)
    print("按PSS(按比例共享内存)排序的前20个进程:")
    print("=" * 80)
    
    # 筛选有PSS信息的进程
    pss_processes = [p for p in processes if 'pss' in p]
    if pss_processes:
        pss_processes.sort(key=lambda x: x.get('pss', 0), reverse=True)
        
        print(f"\n{'PID':<8} {'进程名':<25} {'PSS(KB)':>12} {'RSS(KB)':>12} {'差值(KB)':>12}")
        print("-" * 70)
        
        for proc in pss_processes[:20]:
            pid = proc['pid']
            name = proc.get('name', 'Unknown')[:25]
            pss = proc.get('pss', 0)
            rss = proc.get('rss', proc.get('vm_rss', 0))
            diff = rss - pss
            
            print(f"{pid:<8} {name:<25} {pss:>12,} {rss:>12,} {diff:>12,}")

if __name__ == "__main__":
    # 检查是否以root运行（需要root权限访问所有进程信息）
    if os.geteuid() != 0:
        print("警告: 建议以root用户运行此脚本以获取完整进程信息")
        print("部分进程信息可能无法访问\n")
    
    analyze_memory_usage()
    
    # 可选：保存结果到文件
    save_to_file = input("\n是否保存结果到文件? (y/N): ").lower()
    if save_to_file == 'y':
        import datetime
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"memory_analysis_{timestamp}.txt"
        
        # 重定向输出到文件
        with open(filename, 'w') as f:
            sys.stdout = f
            analyze_memory_usage()
            sys.stdout = sys.__stdout__
        
        print(f"结果已保存到: {filename}")