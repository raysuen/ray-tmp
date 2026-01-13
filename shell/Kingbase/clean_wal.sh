#!/bin/bash
#raysuen
#v3.2 (新增主从复制支持，优化WAL基准选择，处理空格问题)

LANG=C
# 计算符（默认减法，保留最近的WAL文件）
OP=-
# 保留的WAL文件数量（默认保留2个）
NUM=2

# 金仓数据库配置（请根据实际环境填写）
kingbase_bin=/path/to/kingbase/bin  # 金仓bin目录，最后不要加斜线
kingbase_data=/path/to/kingbase/data  # 金仓数据目录，最后不要加斜线
db_user="system"  # 数据库管理员用户
db_name="kingbase"  # 数据库名称

cal_wal(){
    # 十六进制字符串后8位计算器
    # 功能：截取输入十六进制字符串的最后8位进行算术运算，再与前部分拼接
    # 使用方法：cal_wal <十六进制字符串> <操作符> <数值>
    
    if [ $# -ne 3 ]; then
        echo "错误：参数数量不正确" >&2
        echo "正确用法：$0 <十六进制字符串> <操作符(+, -, *, /)> <数值>" >&2
        exit 1
    fi
    
    hex_str="$1"
    op="$2"
    num="$3"
    
    # 验证十六进制格式
    if ! [[ "$hex_str" =~ ^[0-9a-fA-F]+$ ]]; then
        echo "错误：无效的十六进制字符串 '$hex_str'" >&2
        exit 1
    fi
    
    # 验证长度至少8位
    if [ ${#hex_str} -lt 8 ]; then
        echo "错误：十六进制字符串长度必须至少为8位" >&2
        exit 1
    fi
    
    # 验证操作符
    valid_ops=("+" "-" "*" "/")
    if ! [[ " ${valid_ops[@]} " =~ " $op " ]]; then
        echo "错误：无效的操作符 '$op'" >&2
        exit 1
    fi
    
    # 验证数值为正整数
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "错误：数值必须是正整数，输入为 '$num'" >&2
        exit 1
    fi
    
    # 分割前缀和后8位
    total_len=${#hex_str}
    prefix_len=$((total_len - 8))
    prefix="${hex_str:0:prefix_len}"
    last8="${hex_str: -8}"
    
    # 计算后8位
    last8_dec=$((16#$last8))
    case "$op" in
        "+") result_dec=$((last8_dec + num)) ;;
        "-") result_dec=$((last8_dec - num)) ;;
        "*") result_dec=$((last8_dec * num)) ;;
        "/") 
            if [ "$num" -eq 0 ]; then
                echo "错误：除数不能为0" >&2
                exit 1
            fi
            result_dec=$((last8_dec / num)) 
            ;;
    esac
    
    # 防止结果为负数
    if [ "$result_dec" -lt 0 ]; then
        echo "报警：WAL计算结果为负数（$result_dec），退出执行！" >&2
        exit 1
    fi
    
    # 转换为8位大写十六进制
    result_hex=$(printf "%08X" "$result_dec")
    final_result="${prefix}${result_hex}"
    
    # 调试信息输出到stderr（不影响stdout的结果）
    echo "===== 计算过程 =====" >&2
    echo "原始值: $hex_str" >&2
    echo "运算: 后8位($last8) $op $num = $result_hex" >&2
    echo "===== 最终结果 =====" >&2
    
    # 仅输出最终结果到stdout（供变量捕获）
    echo "$final_result"
}

get_walfile(){
    # 获取当前检查点的WAL文件
    wal_file_num=$( ${kingbase_bin}/sys_controldata ${kingbase_data} | awk '/REDO WAL file/{print $NF}' )
    # 去除可能的空格
    wal_file_num=$(echo "$wal_file_num" | xargs)
}

get_min_replay_wal(){
    # 获取从库已应用的最小WAL文件
    # 使用socket连接数据库，直接查询WAL文件名
    wal_list=$( ${kingbase_bin}/ksql -U "$db_user" -d "$db_name" -t -c \
        "SELECT pg_walfile_name(replay_lsn) FROM pg_stat_replication WHERE replay_lsn IS NOT NULL;" 2>/dev/null )
    
    if [ -z "$wal_list" ]; then
        echo ""
        return
    fi
    
    local min_wal=""
    # 遍历并筛选最小WAL（去除空格）
    while IFS= read -r wal; do
        wal_trimmed=$(echo "$wal" | xargs)  # 关键：去除前后空格
        if [ -n "$wal_trimmed" ]; then
            if [ -z "$min_wal" ] || [ "$wal_trimmed" \< "$min_wal" ]; then
                min_wal="$wal_trimmed"
            fi
        fi
    done <<< "$wal_list"
    
    echo "$min_wal"
}

# 主逻辑开始
get_walfile
echo "sys_controldata获取的WAL文件: $wal_file_num"

# 获取从库最小已应用WAL
min_replay_wal=$(get_min_replay_wal)

# 确定基准WAL（取最小值，确保不删除未应用的日志）
if [ -n "$min_replay_wal" ]; then
    echo "从库最小已应用WAL文件: $min_replay_wal"
    if [ "$min_replay_wal" \< "$wal_file_num" ]; then
        base_wal="$min_replay_wal"
        echo "选择从库最小WAL作为基准"
    else
        base_wal="$wal_file_num"
        echo "选择sys_controldata的WAL作为基准"
    fi
else
    echo "未检测到从库，使用sys_controldata的WAL作为基准"
    base_wal="$wal_file_num"
fi

# 计算保留位置并删除旧WAL
final_result=$(cal_wal "$base_wal" "$OP" "$NUM")
echo "#delete wal files: $final_result"
${kingbase_bin}/sys_archivecleanup ${kingbase_data}/sys_wal "$final_result"

exit 0