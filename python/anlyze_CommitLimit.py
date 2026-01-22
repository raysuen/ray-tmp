#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys

def get_meminfo_values():
    """从/proc/meminfo获取内存相关信息"""
    meminfo = {}
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                if ':' in line:
                    key, value = line.split(':', 1)
                    # 提取数值（去掉单位和空格）
                    num_value = value.strip().split()[0]
                    meminfo[key.strip()] = int(num_value)
    except Exception as e:
        print(f"读取/proc/meminfo失败: {e}")
        return None
    return meminfo

def get_overcommit_settings():
    """获取内存过载承诺设置"""
    settings = {}
    try:
        with open('/proc/sys/vm/overcommit_memory', 'r') as f:
            settings['overcommit_memory'] = int(f.read().strip())
        
        with open('/proc/sys/vm/overcommit_ratio', 'r') as f:
            settings['overcommit_ratio'] = int(f.read().strip())
    except Exception as e:
        print(f"读取过载承诺设置失败: {e}")
    
    return settings

def analyze_commit_relationship():
    """分析Committed_AS与CommitLimit的关系"""
    print("=" * 80)
    print("Committed_AS 与 CommitLimit 关系分析")
    print("=" * 80)
    
    # 获取内存信息
    meminfo = get_meminfo_values()
    if not meminfo:
        print("无法获取内存信息")
        return
    
    # 获取过载承诺设置
    settings = get_overcommit_settings()
    
    # 提取关键值
    committed_as = meminfo.get('Committed_AS', 0)
    commit_limit = meminfo.get('CommitLimit', 0)
    mem_total = meminfo.get('MemTotal', 0)
    swap_total = meminfo.get('SwapTotal', 0)
    swap_free = meminfo.get('SwapFree', 0)
    
    # 计算当前使用率
    if commit_limit > 0:
        usage_percent = (committed_as / commit_limit) * 100
    else:
        usage_percent = 0
    
    # 计算实际可用承诺空间
    available_commit = commit_limit - committed_as
    
    # 显示基本信息
    print(f"\n内存基本信息:")
    print(f"  - 物理内存总量: {mem_total:,} KB ({mem_total/1024:,.1f} MB)")
    print(f"  - 交换空间总量: {swap_total:,} KB ({swap_total/1024:,.1f} MB)")
    print(f"  - 可用交换空间: {swap_free:,} KB ({swap_free/1024:,.1f} MB)")
    
    print(f"\n过载承诺设置:")
    overcommit_mode = settings.get('overcommit_memory', 0)
    overcommit_mode_desc = {
        0: "启发式过载 (默认)",
        1: "总是过载",
        2: "禁止过载 (严格限制)"
    }
    print(f"  - overcommit_memory: {overcommit_mode} ({overcommit_mode_desc.get(overcommit_mode, '未知')})")
    print(f"  - overcommit_ratio: {settings.get('overcommit_ratio', 50)}%")
    
    print(f"\n承诺内存分析:")
    print(f"  - Committed_AS (已提交内存): {committed_as:,} KB ({committed_as/1024:,.1f} MB)")
    print(f"  - CommitLimit (提交限制): {commit_limit:,} KB ({commit_limit/1024:,.1f} MB)")
    print(f"  - 当前使用率: {usage_percent:.2f}%")
    print(f"  - 剩余承诺空间: {available_commit:,} KB ({available_commit/1024:,.1f} MB)")
    
    # 计算理论CommitLimit验证公式
    if 'overcommit_ratio' in settings:
        theoretical_limit = swap_total + (mem_total * settings['overcommit_ratio'] / 100)
        print(f"  - 理论计算CommitLimit: {theoretical_limit:,.0f} KB")
        print(f"  - 实际vs理论差异: {commit_limit - theoretical_limit:,.0f} KB")
    
    # 风险评估
    print(f"\n风险评估:")
    
    if overcommit_mode == 0:  # 启发式过载
        if usage_percent > 90:
            print(f"  ⚠️  警告: 承诺内存使用率超过90%，系统可能接近内存过载限制")
        elif usage_percent > 70:
            print(f"  ℹ️  提示: 承诺内存使用率较高({usage_percent:.1f}%)，建议关注")
        else:
            print(f"  ✓ 正常: 承诺内存使用率{usage_percent:.1f}%，处于安全范围")
        
        # 启发式算法的额外检查
        if committed_as > (mem_total + swap_total):
            print(f"  ⚠️  警告: 已提交内存超过物理内存+交换空间总和")
    
    elif overcommit_mode == 2:  # 禁止过载
        if usage_percent >= 100:
            print(f"  🚨 严重: 承诺内存已达限制，新进程可能无法分配内存")
        elif usage_percent > 95:
            print(f"  ⚠️  警告: 承诺内存接近限制({usage_percent:.1f}%)")
        else:
            print(f"  ✓ 正常: 承诺内存使用率{usage_percent:.1f}%")
    
    # 趋势分析
    print(f"\n趋势分析建议:")
    
    if available_commit < (mem_total * 0.1):  # 剩余空间小于物理内存的10%
        print(f"  - 建议: 考虑增加交换空间或调整overcommit_ratio")
    
    if swap_total == 0:
        print(f"  - 警告: 系统没有启用交换空间，内存压力可能较大")
    
    # 计算每个进程的平均承诺
    try:
        pids = [pid for pid in os.listdir('/proc') if pid.isdigit()]
        avg_commit_per_process = committed_as / len(pids) if pids else 0
        print(f"  - 平均每个进程承诺内存: {avg_commit_per_process:,.0f} KB")
    except:
        pass
    
    return {
        'committed_as': committed_as,
        'commit_limit': commit_limit,
        'usage_percent': usage_percent,
        'available_commit': available_commit,
        'overcommit_mode': overcommit_mode,
        'risk_level': 'high' if usage_percent > 90 else 'medium' if usage_percent > 70 else 'low'
    }

def get_process_commit_breakdown(limit=20):
    """获取进程级别的承诺内存分解"""
    print(f"\n{'='*80}")
    print(f"进程级别承诺内存分析 (前{limit}个进程)")
    print(f"{'='*80}")
    
    try:
        processes = []
        
        for pid in os.listdir('/proc'):
            if not pid.isdigit():
                continue
            
            status_file = f'/proc/{pid}/status'
            if not os.path.exists(status_file):
                continue
            
            try:
                with open(status_file, 'r') as f:
                    content = f.read()
                    
                    # 提取进程名和VmSize
                    name_line = next(line for line in content.split('\n') if line.startswith('Name:'))
                    vmsize_line = next((line for line in content.split('\n') if line.startswith('VmSize:')), None)
                    
                    if vmsize_line:
                        name = name_line.split(':')[1].strip()
                        vmsize = int(vmsize_line.split(':')[1].strip().split()[0])
                        processes.append({
                            'pid': pid,
                            'name': name,
                            'vmsize': vmsize
                        })
            except:
                continue
        
        # 按VmSize排序
        processes.sort(key=lambda x: x['vmsize'], reverse=True)
        
        # 计算总承诺
        total_vmsize = sum(p['vmsize'] for p in processes)
        
        print(f"\n{'PID':<8} {'进程名':<25} {'VmSize(KB)':>15} {'占比':>8}")
        print(f"{'-'*60}")
        
        for i, proc in enumerate(processes[:limit]):
            if i >= limit:
                break
            
            pid = proc['pid']
            name = proc['name'][:25]
            vmsize = proc['vmsize']
            percent = (vmsize / total_vmsize * 100) if total_vmsize > 0 else 0
            
            print(f"{pid:<8} {name:<25} {vmsize:>15,} {percent:>7.2f}%")
        
        print(f"\n总计 {len(processes)} 个进程，总VmSize: {total_vmsize:,} KB")
        
        # 显示系统Committed_AS与进程总VmSize的关系
        meminfo = get_meminfo_values()
        if meminfo:
            committed_as = meminfo.get('Committed_AS', 0)
            diff = committed_as - total_vmsize
            
            print(f"\n系统Committed_AS: {committed_as:,} KB")
            print(f"进程总VmSize: {total_vmsize:,} KB")
            print(f"差值: {diff:,} KB (包含内核内存、共享内存、缓存等)")
            
    except Exception as e:
        print(f"分析进程内存失败: {e}")

def monitor_commit_trend(interval=5, count=10):
    """监控Committed_AS趋势"""
    print(f"\n{'='*80}")
    print(f"Committed_AS趋势监控 (每{interval}秒采样，共{count}次)")
    print(f"{'='*80}")
    
    import time
    
    readings = []
    
    for i in range(count):
        meminfo = get_meminfo_values()
        if meminfo and 'Committed_AS' in meminfo:
            committed_as = meminfo['Committed_AS']
            commit_limit = meminfo.get('CommitLimit', 0)
            usage_percent = (committed_as / commit_limit * 100) if commit_limit > 0 else 0
            
            readings.append({
                'time': time.strftime('%H:%M:%S'),
                'committed_as': committed_as,
                'usage_percent': usage_percent
            })
            
            print(f"[{time.strftime('%H:%M:%S')}] Committed_AS: {committed_as:,} KB ({usage_percent:.1f}%)")
        
        if i < count - 1:
            time.sleep(interval)
    
    # 简单趋势分析
    if len(readings) >= 2:
        first = readings[0]['committed_as']
        last = readings[-1]['committed_as']
        change = last - first
        change_percent = (change / first * 100) if first > 0 else 0
        
        print(f"\n趋势分析:")
        print(f"  开始: {first:,} KB")
        print(f"  结束: {last:,} KB")
        print(f"  变化: {change:+,} KB ({change_percent:+.2f}%)")
        
        if change > 0:
            print(f"  趋势: 上升 (可能内存泄漏)")
        elif change < 0:
            print(f"  趋势: 下降")
        else:
            print(f"  趋势: 稳定")

if __name__ == "__main__":
    # 检查是否以root运行
    if os.geteuid() != 0:
        print("注意: 非root用户运行，部分进程信息可能无法访问")
    
    # 主分析
    result = analyze_commit_relationship()
    
    # 进程分解分析
    get_process_commit_breakdown(limit=15)
    
    # 询问是否进行趋势监控
    choice = input("\n是否进行趋势监控? (y/N): ").lower()
    if choice == 'y':
        try:
            interval = int(input("采样间隔(秒，默认5): ") or "5")
            count = int(input("采样次数(默认10): ") or "10")
            monitor_commit_trend(interval, count)
        except ValueError:
            print("输入无效，跳过趋势监控")
    
    print(f"\n{'='*80}")
    print("分析完成")
    print("=" * 80)