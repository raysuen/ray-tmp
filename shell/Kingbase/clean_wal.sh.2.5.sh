#!/bin/bash
#raysuen
#v2.5



LANG=C
#计算符
OP=-
#被减数
NUM=2

#金仓bin目录,最后不需要写斜线(/)
kingbase_bin=
#金仓wal目录
kingbase_data=

cal_wal(){
    # 十六进制字符串后8位计算器
    # 功能：截取输入十六进制字符串的最后8位进行算术运算，再与前部分拼接
    # 使用方法：示例：cal_wal <十六进制字符串> <操作符> <数值>
    # 支持操作符：+ (加), - (减), * (乘), / (除)
    # 示例：cal_wal "000000010000000D000000F4" "-" "5"
    
    # 检查参数数量
    if [ $# -ne 3 ]; then
        echo "错误：参数数量不正确"
        echo "正确用法：$0 <十六进制字符串> <操作符(+, -, *, /)> <数值>"
        echo "示例：$0 000000F4 + 10"
        exit 1
    fi
    
    # 解析参数
    hex_str="$1"
    op="$2"
    num="$3"
    
    # 验证十六进制字符串格式
    if ! [[ "$hex_str" =~ ^[0-9a-fA-F]+$ ]]; then
        echo "错误：无效的十六进制字符串"
        echo "提示：仅允许包含 0-9、a-f、A-F"
        exit 1
    fi
    
    # 验证字符串长度至少为8位
    if [ ${#hex_str} -lt 8 ]; then
        echo "错误：十六进制字符串长度必须至少为8位"
        exit 1
    fi
    
    # 验证操作符
    valid_ops=("+" "-" "*" "/")
    if ! [[ " ${valid_ops[@]} " =~ " $op " ]]; then
        echo "错误：无效的操作符 '$op'"
        echo "支持的操作符：${valid_ops[*]}"
        exit 1
    fi
    
    # 验证数值为正整数
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "错误：数值必须是正整数，您输入的是 '$num'"
        exit 1
    fi
    
    # 分割字符串为前缀和后8位
    total_len=${#hex_str}
    prefix_len=$((total_len - 8))
    prefix="${hex_str:0:prefix_len}"
    last8="${hex_str: -8}"
    
    # 转换后8位为十进制并计算
    last8_dec=$((16#$last8))
    case "$op" in
        "+") result_dec=$((last8_dec + num)) ;;
        "-") result_dec=$((last8_dec - num)) ;;
        "*") result_dec=$((last8_dec * num)) ;;
        "/") 
            if [ "$num" -eq 0 ]; then
                echo "错误：除数不能为0"
                exit 1
            fi
            result_dec=$((last8_dec / num))  # 整数除法
            ;;
    esac
    
    # 新增：判断计算结果是否小于0，若是则报警退出
    if [ "$result_dec" -lt 0 ]; then
        echo "报警：WAL计算结果为负数（$result_dec），不符合预期，退出执行！"
        exit 1
    fi
    
    # 处理计算结果，转换为8位十六进制（补全前导零）
    # 处理计算结果，转换为8位大写十六进制（核心修改：%X 生成大写）
    result_hex=$(printf "%08X" "$result_dec")
    
    # 拼接最终结果
    final_result="${prefix}${result_hex}"
    
    # 显示计算过程和结果
    echo "===== 计算过程 ====="
    echo "===== 最终结果 ====="
    echo "$final_result"

}

get_walfile(){
    wal_file_num=`${kingbase_bin}/sys_controldata ${kingbase_data} | awk '/REDO WAL file/{print $NF}'`
}

#获取当前最后checkpoint的wal文件位置
get_walfile

#通过计算获取结果，默认是减2
cal_wal ${wal_file_num} $OP $NUM

#删除wal日志
echo "#delete wal files"
${kingbase_bin}/sys_archivecleanup ${kingbase_data}/sys_wal ${final_result}

exit 0