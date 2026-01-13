#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# @Time : 2025年7月3日 09:22:57
# @Author : raysuen
# @version 1.0

import os
import pwd
import re
import argparse
from collections import defaultdict

def get_process_memory_info():
    """获取所有进程的内存使用信息"""
    processes = {}
    
    # 遍历/proc目录下的所有进程ID
    for pid in [pid for pid in os.listdir('/proc') if pid.isdigit()]:
        try:
            # 获取进程状态信息
            with open(f'/proc/{pid}/status', 'r') as status_file:
                status = status_file.read()
            
            # 解析内存信息 (VmRSS: 实际使用的物理内存)
            vm_rss_match = re.search(r'VmRSS:\s+(\d+)\s+kB', status)
            vm_size_match = re.search(r'VmSize:\s+(\d+)\s+kB', status)
            
            # 解析用户ID
            uid_match = re.search(r'Uid:\s+(\d+)', status)
            
            if vm_rss_match and uid_match:
                # 获取进程命令行
                try:
                    with open(f'/proc/{pid}/cmdline', 'rb') as cmd_file:
                        cmdline = cmd_file.read().decode('utf-8', errors='replace').replace('\x00', ' ')
                        if not cmdline.strip():
                            with open(f'/proc/{pid}/comm', 'r') as comm_file:
                                cmdline = comm_file.read().strip()
                except IOError:
                    cmdline = "N/A"
                
                # 获取进程所有者用户名
                try:
                    uid = int(uid_match.group(1))
                    username = pwd.getpwuid(uid).pw_name
                except KeyError:
                    username = f"uid:{uid}"
                
                # 获取进程启动时间
                try:
                    stat_data = open(f'/proc/{pid}/stat', 'r').read().split()
                    start_time = int(stat_data[21])
                except IOError:
                    start_time = 0
                
                # 获取进程状态
                state = status.split('\n')[0].split(':')[1].strip()
                
                processes[pid] = {
                    'pid': pid,
                    'rss_kb': int(vm_rss_match.group(1)),
                    'vms_kb': int(vm_size_match.group(1)) if vm_size_match else 0,
                    'username': username,
                    'command': cmdline,
                    'state': state,
                    'start_time': start_time
                }
        
        except (IOError, PermissionError):
            # 跳过无法访问的进程
            continue
    
    return processes

def format_memory(kb):
    """格式化内存大小为易读的单位"""
    units = ['KB', 'MB', 'GB', 'TB']
    size = float(kb)
    for unit in units:
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TB"

def print_process_table(processes, sort_by='rss', reverse=True, group=False):
    """打印进程信息表格"""
    # 表头
    header = f"{'PID':>8} {'USER':<12} {'MEM':>8} {'VIRT':>8} {'STATE':<5} COMMAND"
    print(header)
    print('=' * (8 + 1 + 12 + 1 + 8 + 1 + 8 + 1 + 5 + 1 + 50))
    
    # 分组统计
    if group:
        grouped = defaultdict(lambda: {'count': 0, 'rss': 0, 'vms': 0})
        for proc in processes.values():
            key = (proc['username'], proc['command'])
            grouped[key]['count'] += 1
            grouped[key]['rss'] += proc['rss_kb']
            grouped[key]['vms'] += proc['vms_kb']
        
        # 创建分组列表
        group_list = []
        for (user, cmd), data in grouped.items():
            group_list.append({
                'user': user,
                'command': cmd,
                'count': data['count'],
                'rss': data['rss'],
                'vms': data['vms']
            })
        
        # 排序分组
        if sort_by == 'rss':
            group_list.sort(key=lambda x: x['rss'], reverse=reverse)
        elif sort_by == 'vms':
            group_list.sort(key=lambda x: x['vms'], reverse=reverse)
        elif sort_by == 'count':
            group_list.sort(key=lambda x: x['count'], reverse=reverse)
        
        # 打印分组信息
        for group in group_list:
            print(f"{group['count']:>8} {group['user']:<12} "
                  f"{format_memory(group['rss']):>8} "
                  f"{format_memory(group['vms']):>8} "
                  f"{'':<5} {group['command']}")
        
        return
    
    # 排序进程
    if sort_by == 'rss':
        sorted_procs = sorted(processes.values(), key=lambda p: p['rss_kb'], reverse=reverse)
    elif sort_by == 'vms':
        sorted_procs = sorted(processes.values(), key=lambda p: p['vms_kb'], reverse=reverse)
    elif sort_by == 'pid':
        sorted_procs = sorted(processes.values(), key=lambda p: int(p['pid']), reverse=reverse)
    elif sort_by == 'time':
        sorted_procs = sorted(processes.values(), key=lambda p: p['start_time'], reverse=reverse)
    else:
        sorted_procs = list(processes.values())
    
    # 打印进程信息
    for proc in sorted_procs:
        print(f"{proc['pid']:>8} {proc['username']:<12} "
              f"{format_memory(proc['rss_kb']):>8} "
              f"{format_memory(proc['vms_kb']):>8} "
              f"{proc['state']:<5} {proc['command']}")

def main():
    # 设置命令行参数
    parser = argparse.ArgumentParser(
        description='Linux进程内存监控工具',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('-s', '--sort', choices=['rss', 'vms', 'pid', 'time'], 
                        default='rss', help='排序字段')
    parser.add_argument('-r', '--reverse', action='store_true', 
                        help='反向排序（默认按内存降序）')
    parser.add_argument('-g', '--group', action='store_true', 
                        help='按用户名和命令分组统计')
    parser.add_argument('-u', '--user', 
                        help='过滤特定用户的进程')
    parser.add_argument('-p', '--pid', 
                        help='过滤特定PID的进程')
    parser.add_argument('-c', '--command', 
                        help='过滤包含特定字符串的命令')
    
    args = parser.parse_args()
    
    # 获取进程信息
    processes = get_process_memory_info()
    
    # 应用过滤器
    if args.user:
        processes = {pid: proc for pid, proc in processes.items() 
                     if proc['username'] == args.user}
    
    if args.pid:
        processes = {pid: proc for pid, proc in processes.items() 
                     if pid == args.pid}
    
    if args.command:
        processes = {pid: proc for pid, proc in processes.items() 
                     if args.command.lower() in proc['command'].lower()}
    
    # 打印进程表
    print_process_table(
        processes, 
        sort_by=args.sort, 
        reverse=args.reverse if args.reverse else (args.sort in ['rss', 'vms']),
        group=args.group
    )

if __name__ == "__main__":
    main()
    
# """
# #用户名过滤
#     python3 process_memory.py -u root
# #按命令过滤
#     python3 process_memory.py -c firefox
# #按虚拟内存排序
#     python3 process_memory.py -s vms
# #分组统计
#     python3 process_memory.py -g
# """