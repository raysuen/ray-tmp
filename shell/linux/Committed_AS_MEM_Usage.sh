#!/bin/bash
# 脚本功能：排查系统所有用户、所有进程的Committed_AS占用（无进程类型限制）
# 适配CentOS/RHEL系统，输出所有进程的承诺内存/物理内存/完整命令

# 临时关闭bc的小数位数警告，避免输出干扰
export BC_LINE_LENGTH=0

# ===================== 1. 系统Commit内存总览 =====================
echo -e "\033[32m========== 系统Commit内存总览 ==========\033[0m"
grep -E 'Committed_AS|CommitLimit|MemTotal|SwapTotal|MemAvailable' /proc/meminfo
echo -e "\n\033[32m========== 所有进程Committed_AS占用（按承诺内存降序） ==========\033[0m"
echo "注：输出所有有有效VmCommit的进程，字段说明："
echo "    用户：进程所属用户 | PID：进程ID | 完整命令：进程启动参数 | 承诺内存：贡献到Committed_AS的内存 | 实际物理内存：当前占用的物理内存"
echo "---------------------------------------------------------------------------------------------------------"

# ===================== 2. 所有进程的核心内存信息（按VmCommit降序） =====================
for pid in $(ps -eo pid --no-headers); do
    # 提取核心字段（容错：屏蔽无效PID的报错）
    proc_user=$(ps -p $pid -o user= 2>/dev/null)          # 进程所属用户
    proc_cmd=$(ps -p $pid -o cmd= 2>/dev/null | sed 's/^[ \t]*//g')  # 完整命令行（去开头空格）
    vm_commit=$(grep -w VmCommit /proc/$pid/status 2>/dev/null | awk '{print $2}')  # 承诺内存(KB)
    vm_rss=$(grep -w VmRSS /proc/$pid/status 2>/dev/null | awk '{print $2}')        # 实际物理内存(KB)

    # 仅输出有效数据（VmCommit>0、有用户、有命令）
    if [ -n "$vm_commit" ] && [ "$vm_commit" -gt 0 ] && [ -n "$proc_user" ] && [ -n "$proc_cmd" ]; then
        # 单位转换：KB → GB（保留2位小数，容错空值）
        vm_commit_gb=$(echo "scale=2; $vm_commit/1024/1024" | bc 2>/dev/null) || vm_commit_gb="0.00"
        vm_rss_gb=$(echo "scale=2; $vm_rss/1024/1024" | bc 2>/dev/null) || vm_rss_gb="0.00"
        
        # 统一空值为0.00
        vm_commit_gb=${vm_commit_gb:-0.00}
        vm_rss_gb=${vm_rss_gb:-0.00}

        # 输出格式（颜色标记高内存进程：承诺内存>1GB标红）
        if (( $(echo "$vm_commit_gb > 1.00" | bc -l) )); then
            echo -e "\033[31m用户: $proc_user | PID: $pid | 完整命令: $proc_cmd | 承诺内存: $vm_commit_gb GB | 实际物理内存: $vm_rss_gb GB\033[0m"
        else
            echo "用户: $proc_user | PID: $pid | 完整命令: $proc_cmd | 承诺内存: $vm_commit_gb GB | 实际物理内存: $vm_rss_gb GB"
        fi
    fi
done | sort -k10 -nr  # 按承诺内存（第10列）降序排列（无任何进程类型限制）

# ===================== 3. 所有进程的详细内存信息（可选，按需开启） =====================
echo -e "\n\033[32m========== 所有进程的详细内存参数（VmSize/VmRSS/VmCommit） ==========\033[0m"
echo "提示：若无需详细信息，可注释此段；如需查看，执行 'bash test.sh | less' 分页浏览"
for pid in $(ps -eo pid --no-headers | head -50); do  # 限制前50个进程（避免输出过长）
    proc_user=$(ps -p $pid -o user= 2>/dev/null)
    proc_cmd=$(ps -p $pid -o cmd= 2>/dev/null | sed 's/^[ \t]*//g' | cut -c 1-80)  # 命令行截断为80字符
    if [ -n "$proc_user" ] && [ -n "$proc_cmd" ]; then
        echo -e "\n\033[34m用户: $proc_user | PID: $pid | 命令行: $proc_cmd\033[0m"
        echo "----------------------------------------"
        grep -E 'VmSize|VmRSS|VmCommit|VmData' /proc/$pid/status 2>/dev/null
    fi
done

# ===================== 4. 辅助提示 =====================
echo -e "\n\033[32m========== 排查完成 ==========\033[0m"
