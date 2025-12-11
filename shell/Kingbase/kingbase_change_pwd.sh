#!/bin/bash
#by raysuen
#v 4.0 (增加自动路径检测功能)

set -u

# 全局配置
super_user="system"          
default_db="template1" 
username=""
newpassword=""
sys_hba_conf=""
sys_ctl_path=""
ksql_path=""
kingbase_port="54321"  # 默认端口，会被自动检测覆盖
data_dir=""            # 自动获取数据目录
bin_path=""            # 自动获取bin目录

# 用法提示
usage() {
    echo -e "\033[33m用法: $0 <用户名> <新密码>\033[0m"
    echo -e "\033[33m示例: $0 test01 'vbox8269#'\033[0m"
    exit 1
}

# 错误退出+恢复配置
error_exit() {
    echo -e "\033[31m[错误] $1\033[0m"
    if [ -f "${sys_hba_conf}.bak" ]; then
        mv -f "${sys_hba_conf}.bak" "${sys_hba_conf}"
        [ -n "${sys_ctl_path}" ] && "${sys_ctl_path}" -D "${data_dir}" reload
    fi
    exit "$2"
}

# 路径检查工具函数
check_path() {
    local path_type=$1  # "dir"或"file"
    local path=$2
    local desc=$3       # 路径描述（用于错误提示）
    
    if [ "$path_type" = "dir" ] && [ ! -d "$path" ]; then
        echo "错误：$desc路径不存在或不是目录：$path"
        return 1
    elif [ "$path_type" = "file" ] && [ ! -f "$path" ]; then
        echo "错误：$desc文件不存在：$path"
        return 1
    fi
    return 0
}

# 检查数据库状态并获取路径信息
check_database_data() {
    # 获取checkpointer进程PID（Kingbase核心进程）
    local pids=$(pgrep -f "kingbase:.*checkpointer" | tr '\n' ' ')
    local pid_count=$(echo "$pids" | wc -w)

    case $pid_count in
        0)  # 数据库未运行，手动输入路径
            echo "数据库未启动，请输入Kingbase安装根目录（例如：/home/kingbase/install）："
            read kingbase_home
            check_path "dir" "$kingbase_home" "Kingbase安装根目录" || exit 10

            # 推导bin路径并验证
            bin_path="${kingbase_home}/Server/bin"
            check_path "file" "${bin_path}/kingbase" "kingbase可执行文件" || exit 10

            # 手动输入数据目录并验证
            echo "请输入数据目录（例如：/home/kingbase/userdata/data）："
            read data_dir
            check_path "dir" "$data_dir" "数据目录" || exit 10
            check_path "file" "${data_dir}/kingbase.conf" "kingbase.conf配置文件" || exit 10
            ;;

        1)  # 单个进程，自动获取路径
            local kes_pid=$(echo "$pids" | awk '{print $1}')
            # 从进程执行路径获取bin目录
            local kingbase_path=$(readlink -f "/proc/${kes_pid}/exe")
            bin_path=$(dirname "$kingbase_path")
            # 从进程工作目录获取数据目录
            data_dir=$(readlink -f "/proc/${kes_pid}/cwd")
            ;;

        *)  # 多个进程，让用户选择
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
            # 验证用户输入的PID是否有效
            if ! echo "$pids" | grep -q "\b${kes_pid}\b"; then
                echo "错误：输入的PID无效"
                exit 10
            fi
            # 获取路径
            local kingbase_path=$(readlink -f "/proc/${kes_pid}/exe")
            bin_path=$(dirname "$kingbase_path")
            data_dir=$(readlink -f "/proc/${kes_pid}/cwd")
            ;;
    esac

    # 最终验证关键路径
    check_path "dir" "$bin_path" "bin目录" || exit 10
    check_path "dir" "$data_dir" "数据目录" || exit 10
    echo -e "\033[32m[检测] 成功获取路径：\033[0m"
    echo -e "  bin目录: $bin_path"
    echo -e "  数据目录: $data_dir"
}

# 获取数据库端口
GetPort() {
    # 处理数据目录末尾斜杠
    data_dir="${data_dir%/}"

    # 尝试从临时文件获取端口（/tmp/.s.KINGBASE.端口号）
    local tmp_sock=$(ls /tmp/.s.KINGBASE.* 2>/dev/null | grep -v "lock" | head -1)
    if [ -n "$tmp_sock" ]; then
        kingbase_port=$(echo "$tmp_sock" | grep -Eo '[0-9]+$')
    fi

    # 临时文件获取失败则从配置文件读取
    if [ -z "$kingbase_port" ]; then
        # 解析kingbase.conf及包含的配置文件
        local conf_files=("${data_dir}/kingbase.conf")
        # 读取主配置中的include文件
        conf_files+=$(grep -E "^include" "${data_dir}/kingbase.conf" | sed "s/[';]//g" | awk '{print "'"${data_dir}/"'"$NF}')
        
        # 从配置文件中查找port参数（倒序优先读最后生效的配置）
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

# 修复：仅转义单引号（SQL中唯一需要转义的字符）
escape_password() {
    local raw_pwd="$1"
    # 仅将单引号转义为两个单引号（Kingbase SQL标准）
    escaped_pwd=$(echo "$raw_pwd" | sed -e "s/'/''/g")
    echo "$escaped_pwd"
}

# 强制修改sys_hba.conf为trust
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

# 核心密码修改逻辑
change_password() {
    # 仅转义单引号（无过度转义）
    local escaped_pwd=$(escape_password "${newpassword}")
    # 检查用户是否存在
    local user_exists=$("${ksql_path}" -U "${super_user}" -d "${default_db}" -p "${kingbase_port}" -t -c "SELECT 1 FROM pg_roles WHERE rolname='${username}';" 2>/dev/null)
    if [ -z "${user_exists}" ]; then
        echo -e "\033[32m[创建] 用户${username}不存在，创建中...\033[0m"
        "${ksql_path}" -U "${super_user}" -d "${default_db}" -p "${kingbase_port}" -c "CREATE USER ${username} WITH PASSWORD '${escaped_pwd}';" || error_exit "创建用户失败！" 11
    fi
    # 修改密码（使用原生密码，仅转义单引号）
    echo -e "\033[32m[修改] 正在修改${username}密码...\033[0m"
    "${ksql_path}" -U "${super_user}" -d "${default_db}" -p "${kingbase_port}" -c "ALTER USER ${username} WITH PASSWORD '${escaped_pwd}';" || error_exit "修改密码失败！" 7
    echo -e "\033[32m[成功] ${username}密码修改成功！\033[0m"
}

# 恢复sys_hba.conf
restore_sys_hba() {
    echo -e "\033[32m[恢复] 恢复sys_hba.conf原有配置...\033[0m"
    if [ -f "${sys_hba_conf}.bak" ]; then
        mv -f "${sys_hba_conf}.bak" "${sys_hba_conf}"
        "${sys_ctl_path}" -D "${data_dir}" reload || error_exit "恢复配置重载失败" 8
        echo -e "\033[32m[恢复] sys_hba.conf已恢复：$(egrep "^local" "${sys_hba_conf}")\033[0m"
    fi
}

# 主流程
main() {
    if [ $# -ne 2 ]; then
        usage
    fi
    username="$1"
    newpassword="$2"
    
    # 自动获取数据库路径
    check_database_data
    # 自动获取端口（可选，用于ksql连接）
    GetPort
    
    # 设置工具路径
    ksql_path="${bin_path}/ksql"
    sys_ctl_path="${bin_path}/sys_ctl"
    
    # 验证工具存在性
    check_path "file" "$ksql_path" "ksql工具" || error_exit "ksql工具不存在" 9
    check_path "file" "$sys_ctl_path" "sys_ctl工具" || error_exit "sys_ctl工具不存在" 9
    
    # 执行密码修改流程
    force_modify_sys_hba
    change_password
    restore_sys_hba
    
    echo -e "\033[32m====================================\033[0m"
    echo -e "\033[32m[完成] 操作成功！验证登录命令：\033[0m"
    echo -e "  ${ksql_path} -U ${username} -d ${default_db} -p ${kingbase_port}"
    echo -e "\033[32m====================================\033[0m"
}

main "$@"