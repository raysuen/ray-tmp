#!/bin/bash
# =============================================================================
# KingbaseES 密码修改脚本 v4.3
# 支持: -U 超级用户 或 将超级用户作为第三个位置参数
# =============================================================================
set -u

super_user="system"   #超级用户，默认为system
default_db="template1"
username=""
newpassword=""
sys_hba_conf=""
sys_ctl_path=""
ksql_path=""
kingbase_port="54321"
data_dir=""
bin_path=""

usage() {
	echo -e "\033[33m用法: $0 <用户名> <新密码>\033[0m"
    echo -e "\033[33m用法: $0 [-U 超级用户] <用户名> <新密码>\033[0m"
	echo -e "\033[33m用法: $0 <用户名> <新密码> [超级用户]\033[0m"
    echo -e "\033[33m示例: \033[0m"
	echo -e "\033[33m       $0 sso 'new_sso_password'\033[0m"
    echo -e "\033[33m       $0 -U superuser sso 'new_sso_password'\033[0m"
	echo -e "\033[33m       $0 sso 'new_sso_password' superuser\033[0m"

    echo -e "\033[33m选项:\033[0m"
    echo -e "\033[33m  -U <用户>  指定执行操作的超级用户（默认: system）\033[0m"
    echo -e "\033[33m  -h         显示本帮助信息\033[0m"
    exit 1
}

error_exit() {
    echo -e "\033[31m[错误] $1\033[0m"
    if [ -f "${sys_hba_conf}.bak" ]; then
        mv -f "${sys_hba_conf}.bak" "${sys_hba_conf}"
        [ -n "${sys_ctl_path}" ] && "${sys_ctl_path}" -D "${data_dir}" reload
    fi
    exit "$2"
}

check_path() {
    local path_type=$1
    local path=$2
    local desc=$3
    if [ "$path_type" = "dir" ] && [ ! -d "$path" ]; then
        echo "错误：$desc路径不存在或不是目录：$path"
        return 1
    elif [ "$path_type" = "file" ] && [ ! -f "$path" ]; then
        echo "错误：$desc文件不存在：$path"
        return 1
    fi
    return 0
}

check_database_data() {
    local pids=$(pgrep -f "kingbase:.*checkpointer" | tr '\n' ' ')
    local pid_count=$(echo "$pids" | wc -w)

    case $pid_count in
        0)
            echo "数据库未启动，请输入Kingbase安装根目录（例如：/home/kingbase/install）："
            read kingbase_home
            check_path "dir" "$kingbase_home" "Kingbase安装根目录" || exit 10
            bin_path="${kingbase_home}/Server/bin"
            check_path "file" "${bin_path}/kingbase" "kingbase可执行文件" || exit 10
            echo "请输入数据目录（例如：/home/kingbase/userdata/data）："
            read data_dir
            check_path "dir" "$data_dir" "数据目录" || exit 10
            check_path "file" "${data_dir}/kingbase.conf" "kingbase.conf配置文件" || exit 10
            ;;
        1)
            local kes_pid=$(echo "$pids" | awk '{print $1}')
            local kingbase_path=$(readlink -f "/proc/${kes_pid}/exe")
            bin_path=$(dirname "$kingbase_path")
            data_dir=$(readlink -f "/proc/${kes_pid}/cwd")
            ;;
        *)
            echo "检测到多个Kingbase实例，请选择要操作的PID："
            for pid in $pids; do
                local exe_path=$(readlink -f "/proc/${pid}/exe")
                local cwd_path=$(readlink -f "/proc/${pid}/cwd")
                echo "PID: $pid"
                echo "  可执行文件: $exe_path"
                echo "  数据目录: $cwd_path"
                echo "-------------------------"
            done
            echo "请输入目标PID："
            read kes_pid
            if ! echo "$pids" | grep -q "\b${kes_pid}\b"; then
                echo "错误：输入的PID无效"
                exit 10
            fi
            local kingbase_path=$(readlink -f "/proc/${kes_pid}/exe")
            bin_path=$(dirname "$kingbase_path")
            data_dir=$(readlink -f "/proc/${kes_pid}/cwd")
            ;;
    esac

    check_path "dir" "$bin_path" "bin目录" || exit 10
    check_path "dir" "$data_dir" "数据目录" || exit 10
    echo -e "\033[32m[检测] 成功获取路径：\033[0m"
    echo -e "  bin目录: $bin_path"
    echo -e "  数据目录: $data_dir"
}

GetPort() {
    data_dir="${data_dir%/}"
    local tmp_sock=$(ls /tmp/.s.KINGBASE.* 2>/dev/null | grep -v "lock" | head -1)
    if [ -n "$tmp_sock" ]; then
        kingbase_port=$(echo "$tmp_sock" | grep -Eo '[0-9]+$')
    fi
    if [ -z "$kingbase_port" ]; then
        local conf_files=("${data_dir}/kingbase.conf")
        conf_files+=$(grep -E "^include" "${data_dir}/kingbase.conf" | sed "s/[';]//g" | awk '{print "'"${data_dir}/"'"$NF}')
        for conf in $(echo "${conf_files[@]}" | tac); do
            if [ -f "$conf" ]; then
                kingbase_port=$(grep -i "^port" "$conf" | awk '{print $3}' | head -1)
                [ -n "$kingbase_port" ] && break
            fi
        done
    fi
    if [ -z "$kingbase_port" ]; then
        echo -e "\033[33m[警告] 未找到数据库端口，使用默认端口${kingbase_port}\033[0m"
    else
        echo -e "\033[32m[检测] 数据库端口: $kingbase_port\033[0m"
    fi
}

escape_password() {
    local raw_pwd="$1"
    escaped_pwd=$(echo "$raw_pwd" | sed -e "s/'/''/g")
    echo "$escaped_pwd"
}

force_modify_sys_hba() {
    echo -e "\033[32m[配置] 强制修改sys_hba.conf...\033[0m"
    sys_hba_conf="${data_dir}/sys_hba.conf"
    check_path "file" "$sys_hba_conf" "sys_hba.conf配置文件" || error_exit "sys_hba.conf不存在" 5
    cp -f "${sys_hba_conf}" "${sys_hba_conf}.bak" || error_exit "备份sys_hba.conf失败" 6
    sed -i '/^local/d' "${sys_hba_conf}"
    echo "local   all             all                                     trust" >> "${sys_hba_conf}"
    "${sys_ctl_path}" -D "${data_dir}" reload || error_exit "重载配置失败" 6
    local check_result=$(egrep "^local" "${sys_hba_conf}")
    if [[ ! ${check_result} =~ "trust" ]]; then
        error_exit "sys_hba.conf修改失败！" 6
    fi
    echo -e "\033[32m[配置] sys_hba.conf已改为trust：${check_result}\033[0m"
}

change_password() {
    local escaped_pwd=$(escape_password "${newpassword}")
    local user_exists

    user_exists=$("${ksql_path}" -U "${super_user}" -d "${default_db}" -p "${kingbase_port}" -t -c "SELECT 1 FROM pg_roles WHERE rolname='${username}';" 2>/dev/null)
    if [ -z "${user_exists}" ]; then
        if [[ "${username}" == "sso" || "${username}" == "sao" ]]; then
            error_exit "用户 ${username} 是系统内置三权用户，但当前不存在！请检查数据库状态。" 11
        fi
        echo -e "\033[32m[创建] 用户${username}不存在，创建中...\033[0m"
        "${ksql_path}" -U "${super_user}" -d "${default_db}" -p "${kingbase_port}" -c "CREATE USER ${username} WITH PASSWORD '${escaped_pwd}';" || error_exit "创建用户失败！" 11
        return 0
    fi

    local sql_cmd=""
    if [[ "${username}" == "sso" ]]; then
        echo -e "\033[33m[提示] 检测到三权用户 sso，将先执行 SET ROLE sso\033[0m"
        sql_cmd="SET ROLE sso; ALTER USER sso WITH PASSWORD '${escaped_pwd}';"
    elif [[ "${username}" == "sao" ]]; then
        echo -e "\033[33m[提示] 检测到三权用户 sao，将先执行 SET ROLE sao\033[0m"
        sql_cmd="SET ROLE sao; ALTER USER sao WITH PASSWORD '${escaped_pwd}';"
    else
        sql_cmd="ALTER USER ${username} WITH PASSWORD '${escaped_pwd}';"
    fi

    echo -e "\033[32m[修改] 正在修改${username}密码...\033[0m"
    "${ksql_path}" -U "${super_user}" -d "${default_db}" -p "${kingbase_port}" -c "${sql_cmd}" || error_exit "修改密码失败！" 7
    echo -e "\033[32m[成功] ${username}密码修改成功！\033[0m"
}

restore_sys_hba() {
    echo -e "\033[32m[恢复] 恢复sys_hba.conf原有配置...\033[0m"
    if [ -f "${sys_hba_conf}.bak" ]; then
        mv -f "${sys_hba_conf}.bak" "${sys_hba_conf}"
        "${sys_ctl_path}" -D "${data_dir}" reload || error_exit "恢复配置重载失败" 8
        echo -e "\033[32m[恢复] sys_hba.conf已恢复：$(egrep "^local" "${sys_hba_conf}")\033[0m"
    fi
}

# ------------------ 解析参数（兼容两种方式）------------------
main() {
    # 先解析 -U 选项
    while getopts "U:h" opt; do
        case $opt in
            U)
                super_user="$OPTARG"
                ;;
            h)
                usage
                ;;
            *)
                usage
                ;;
        esac
    done
    shift $((OPTIND - 1))

    # 根据剩余参数个数判断
    if [ $# -eq 3 ]; then
        # 三个参数：用户名 密码 超级用户
        username="$1"
        newpassword="$2"
        super_user="$3"
    elif [ $# -eq 2 ]; then
        # 两个参数：用户名 密码
        username="$1"
        newpassword="$2"
        # super_user 保持默认值或 -U 设置的值
    else
        usage
    fi

    # 执行原有流程
    check_database_data
    GetPort
    
    ksql_path="${bin_path}/ksql"
    sys_ctl_path="${bin_path}/sys_ctl"
    
    check_path "file" "$ksql_path" "ksql工具" || error_exit "ksql工具不存在" 9
    check_path "file" "$sys_ctl_path" "sys_ctl工具" || error_exit "sys_ctl工具不存在" 9
    
    force_modify_sys_hba
    change_password
    restore_sys_hba
    
    echo -e "\033[32m====================================\033[0m"
    echo -e "\033[32m[完成] 操作成功！验证登录命令：\033[0m"
    echo -e "  ${ksql_path} -U ${username} -d ${default_db} -p ${kingbase_port}"
    echo -e "\033[32m====================================\033[0m"
}

main "$@"