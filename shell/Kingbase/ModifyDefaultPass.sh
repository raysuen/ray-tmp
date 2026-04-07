#!/bin/bash
#by raysuen
#v3.8

# 帮助函数
show_help() {
    echo "用法: $0 [-g ['length' ['upper' 'lower' 'digits' 'special']]] [-m ['length' ['upper' 'lower' 'digits' 'special']]] [-h]"
    echo "选项:"
    echo "  -g ['length' ['upper' 'lower' 'digits' 'special']]: 生成密码。可指定密码长度、大写字母最小数量、小写字母最小数量、数字最小数量和特殊字符最小数量，用空格分隔。若不指定，使用默认值。"
    echo "  -g: 不指定任何参数，使用默认的12位密码长度及默认字符数量。"
    echo "  -m ['length' ['upper' 'lower' 'digits' 'special']]: 修改密码。可指定密码长度、大写字母最小数量、小写字母最小数量、数字最小数量和特殊字符最小数量，用空格分隔。若不指定，使用默认值。"
    echo "  -m: 不指定任何参数，使用默认的12位密码长度及默认字符数量。"
    echo "  无参数: 生成默认 12 位长度的密码。"
    echo "  -h: 显示此帮助信息。"
}

# 生成密码函数
generate_password() {
    # 参数解析
    local length=${1:-12}
    local min_upper=${2:-1}   # 默认至少1个大写
    local min_lower=${3:-1}   # 默认至少1个小写
    local min_digits=${4:-1}  # 默认至少1个数字
    local min_special=${5:-1} # 默认至少1个特殊字符

    # 验证参数
    local min_total=$((min_upper + min_lower + min_digits + min_special))
    if [[ ! $length =~ ^[0-9]+$ ]] || [ $length -lt $min_total ] || [ $length -lt 8 ]; then
        echo "错误：密码长度必须≥8且≥各字符类型最小数量之和($min_total)" >&2
        return 1
    fi

    # 定义字符集（排除易混淆字符）
    local upper="ABCDEFGHIJKLMNOPQRSTUVWXYZ"  # 
    local lower="abcdefghijklmnopqrstuvwxyz"   # 
    local digits="1234567890"                # 
    local special='@#()%^&*_+=-~`?!'         # 安全特殊字符

    # 生成满足最小数量要求的字符
    local password=""

    # 生成大写字母
    for ((i=0; i<min_upper; i++)); do
        password+="${upper:$(( RANDOM % ${#upper} )):1}"
    done

    # 生成小写字母
    for ((i=0; i<min_lower; i++)); do
        password+="${lower:$(( RANDOM % ${#lower} )):1}"
    done

    # 生成数字
    for ((i=0; i<min_digits; i++)); do
        password+="${digits:$(( RANDOM % ${#digits} )):1}"
    done

    # 生成特殊字符
    for ((i=0; i<min_special; i++)); do
        password+="${special:$(( RANDOM % ${#special} )):1}"
    done

    # 生成剩余随机字符
    local all_chars="${upper}${lower}${digits}${special}"
    local remaining=$((length - min_upper - min_lower - min_digits - min_special))

    if [ $remaining -gt 0 ]; then
        # 兼容性更好的随机字符串生成
        local rand_chars=$(LC_ALL=C tr -dc "$all_chars" < /dev/urandom | head -c $remaining)
        password+="$rand_chars"
    fi

    # 替代 shuf 的随机打乱方案
    final_password=$(
        # 将字符串拆分为单个字符
        fold -w1 <<< "$password" |
        # 使用 awk 添加随机数前缀
        awk 'BEGIN{srand()} {print rand(), $0}' |
        # 按随机数排序
        sort -k1,1n |
        # 移除随机数前缀
        cut -d' ' -f2- |
        # 合并为一行
        tr -d '\n'
    ) 2>/dev/null
    
    # 输出最终生成的密码
    echo "$final_password"
}

# 修改密码函数
ModifyPassword() {
    local length=${1:-12}
    local min_upper=${2:-1}
    local min_lower=${3:-1}
    local min_digits=${4:-2}
    local min_special=${5:-2}

    userpass=$(generate_password $length $min_upper $min_lower $min_digits $min_special)
    date_tmp=$(date +"%Y%m%d%H%M")
    kingbase_path=$(ps -ef | grep "bin/kingbase" | grep -v grep | awk '{print $8}')
    bin_path=${kingbase_path%/*}
    export KINGBASE_PORT=$(ps -ef | grep "bin/kingbase" | egrep -v "grep" | awk '{print "netstat -lantup 2> /dev/null | egrep "$2" |egrep tcp | egrep -v \"tcp6\" | awk -F'\''[ :]+'\'' '\''{print $5}'\''"}' | bash)
    [ -f /home/kingbase/.encpwd ] && cp /home/kingbase/.encpwd /home/kingbase/.encpwd_${date_tmp}
    ${bin_path}/sys_encpwd -H \* -P \* -D \* -U sso -W "12345678ab"
    ${bin_path}/sys_encpwd -H \* -P \* -D \* -U sao -W "12345678ab"
    ${bin_path}/ksql -U sso -d test -c "alter user sso password '${userpass}';"
    sso_res=$?
    ${bin_path}/ksql -U sao -d test -c "alter user sao password '${userpass}';"
    sao_res=$?
    if [ -f /home/kingbase/.encpwd_${date_tmp} ]; then
        rm -f /home/kingbase/.encpwd && cp /home/kingbase/.encpwd_${date_tmp} /home/kingbase/.encpwd
    else
        rm -f /home/kingbase/.encpwd
    fi
    if [ $sso_res -eq 0 ] && [ $sao_res -eq 0 ]; then
        echo -e "sso and sao passwords have been changed to \e[1;31m\""${userpass}"\"\e[0m"
    fi
}

# 解析命令行参数
if [ $# -eq 0 ]; then
    generate_password 12
    exit 0  # 无参数生成密码后直接退出
else
    while getopts ":g:m:h" opt; do
        case $opt in
            g)
                if [ -z "$OPTARG" ]; then
                    generate_password 12
                else
                    args=($OPTARG)
                    if [ ${#args[@]} -eq 1 ]; then
                        length=${args[0]}
                        generate_password $length
                    elif [ ${#args[@]} -eq 5 ]; then
                        length=${args[0]}
                        min_upper=${args[1]}
                        min_lower=${args[2]}
                        min_digits=${args[3]}
                        min_special=${args[4]}
                        generate_password $length $min_upper $min_lower $min_digits $min_special
                    else
                        echo "无效的 -g 参数格式。" >&2
                        show_help
                        exit 1
                    fi
                fi
                ;;
            m)
                if [ -z "$OPTARG" ]; then
                    ModifyPassword 12
                else
                    args=($OPTARG)
                    if [ ${#args[@]} -eq 1 ]; then
                        length=${args[0]}
                        ModifyPassword $length
                    elif [ ${#args[@]} -eq 5 ]; then
                        length=${args[0]}
                        min_upper=${args[1]}
                        min_lower=${args[2]}
                        min_digits=${args[3]}
                        min_special=${args[4]}
                        ModifyPassword $length $min_upper $min_lower $min_digits $min_special
                    else
                        echo "无效的 -m 参数格式。" >&2
                        show_help
                        exit 1
                    fi
                fi
                ;;
            h)
                show_help
                exit 0
                ;;
            \?)
                echo "无效的选项: -$OPTARG" >&2
                show_help
                exit 1
                ;;
            :)
                if [ "$OPTARG" = "g" ]; then
                    generate_password 12
                elif [ "$OPTARG" = "m" ]; then
                    ModifyPassword 12
                else
                    echo "选项 -$OPTARG 需要参数。" >&2
                    show_help
                    exit 1
                fi
                ;;
        esac
    done
fi

# 仅当「有参数但无有效选项」时触发帮助
if [ $OPTIND -eq 1 ] && [ $# -ne 0 ]; then
    echo "未提供有效选项。" >&2
    show_help
    exit 1
fi