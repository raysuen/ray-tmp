#!/bin/bash
#by raysuen
#v 3.3

set -u

# 全局配置
super_user="system"          
default_db="template1" 
username=""
newpassword=""
sys_hba_conf=""
sys_ctl_path=""
ksql_path=""
kingbase_port="54321"
data_dir="/home/kingbase/userdata/data" 
bin_path="/home/kingbase/install/kingbase/bin"

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
        "${sys_ctl_path}" -D "${data_dir}" reload
    fi
    exit "$2"
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
    cp -f "${sys_hba_conf}" "${sys_hba_conf}.bak"
    sed -i '/^local/d' "${sys_hba_conf}"
    echo "local   all             all                                     trust" >> "${sys_hba_conf}"
    "${sys_ctl_path}" -D "${data_dir}" reload
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
    local user_exists=$("${ksql_path}" -U "${super_user}" -d "${default_db}" -t -c "SELECT 1 FROM pg_roles WHERE rolname='${username}';" 2>/dev/null)
    if [ -z "${user_exists}" ]; then
        echo -e "\033[32m[创建] 用户${username}不存在，创建中...\033[0m"
        "${ksql_path}" -U "${super_user}" -d "${default_db}" -c "CREATE USER ${username} WITH PASSWORD '${escaped_pwd}';" || error_exit "创建用户失败！" 11
    fi
    # 修改密码（使用原生密码，仅转义单引号）
    echo -e "\033[32m[修改] 正在修改${username}密码...\033[0m"
    "${ksql_path}" -U "${super_user}" -d "${default_db}" -c "ALTER USER ${username} WITH PASSWORD '${escaped_pwd}';" || error_exit "修改密码失败！" 7
    echo -e "\033[32m[成功] ${username}密码修改成功！\033[0m"
}

# 恢复sys_hba.conf
restore_sys_hba() {
    echo -e "\033[32m[恢复] 恢复sys_hba.conf原有配置...\033[0m"
    if [ -f "${sys_hba_conf}.bak" ]; then
        mv -f "${sys_hba_conf}.bak" "${sys_hba_conf}"
        "${sys_ctl_path}" -D "${data_dir}" reload
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
    ksql_path="${bin_path}/ksql"
    sys_ctl_path="${bin_path}/sys_ctl"
    force_modify_sys_hba
    change_password
    restore_sys_hba
    echo -e "\033[32m====================================\033[0m"
    echo -e "\033[32m[完成] 操作成功！验证登录命令：\033[0m"
    echo -e "  ${ksql_path} -U ${username} -d ${default_db}"
    echo -e "\033[32m====================================\033[0m"
}

main "$@"