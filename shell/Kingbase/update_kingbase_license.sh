#!/bin/bash
#by raysuen
#v2.0
# =============================================================================
# 脚本名称: update_kingbase_license.sh
# 功能描述: 自动替换人大金仓(KingbaseES)的license.dat文件，可选重载配置
# 使用方法:
#   ./update_kingbase_license.sh [选项] <新授权文件路径>
#   ./update_kingbase_license.sh -b /path/to/bin -l /path/to/license.dat
# 选项:
#   -b, --bindir <目录>   手动指定Kingbase的bin目录（指定后跳过重载）
#   -l, --license <文件>  手动指定新授权文件（可替代位置参数）
#   -h, --help           显示帮助信息
# 注意事项: 支持root执行（自动切换至kingbase用户重载配置）
# =============================================================================

set -uo pipefail

# ---------------------------- 全局变量 ----------------------------
MANUAL_BIN_DIR=""
NEW_LICENSE=""
BIN_DIR=""
DATA_DIR=""
KINGBASE_INSTALL=""

# ---------------------------- 函数定义 ----------------------------

show_help() {
    cat << EOF
用法: $0 [选项] [新授权文件路径]

选项:
  -b, --bindir <目录>    手动指定 Kingbase 的 bin 目录（指定后跳过重载配置）
  -l, --license <文件>   手动指定新授权文件（可替代位置参数）
  -h, --help            显示此帮助信息

示例:
  $0 /home/kingbase/new_license.dat
  $0 -b /opt/Kingbase/ES/V8/Server/bin -l /tmp/license.dat

注意:
  若同时提供位置参数和 -l 选项，以 -l 为准。
  若未从进程获取到bin目录且未指定-b，则脚本仅输出查找结果并退出，不执行替换。
  若使用了 -b 手动指定 bin 目录，则不会执行配置重载。
EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--bindir)
                MANUAL_BIN_DIR="$2"
                shift 2
                ;;
            -l|--license)
                NEW_LICENSE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            -*)
                echo "未知选项: $1"
                show_help
                ;;
            *)
                if [ -z "$NEW_LICENSE" ]; then
                    NEW_LICENSE="$1"
                else
                    echo "警告: 已通过 -l 指定授权文件，忽略多余位置参数: $1"
                fi
                shift
                ;;
        esac
    done

    if [ -z "$NEW_LICENSE" ]; then
        echo "错误: 未指定新授权文件。请使用位置参数或 -l 选项。"
        show_help
    fi
}

validate_license_file() {
    if [ ! -f "$NEW_LICENSE" ] || [ -L "$NEW_LICENSE" ]; then
        echo "错误: $NEW_LICENSE 不存在、不是普通文件或是软链接，退出。"
        exit 1
    fi
    if [ ! -r "$NEW_LICENSE" ]; then
        echo "错误: 对新授权文件 $NEW_LICENSE 没有读取权限，无法替换。"
        exit 1
    fi
}

acquire_bin_directory() {
    if [ -n "$MANUAL_BIN_DIR" ]; then
        echo "使用手动指定的 bin 目录: $MANUAL_BIN_DIR"
        BIN_DIR="$MANUAL_BIN_DIR"
        if [ ! -d "$BIN_DIR" ]; then
            echo "错误: 指定的 bin 目录不存在: $BIN_DIR"
            exit 1
        fi
        return 0
    fi

    local bin_cmd
    bin_cmd=$(ps -ef | grep 'bin/kingbase' | grep -v grep | awk '{print $(NF-2)}' | head -1)
    if [ -n "$bin_cmd" ]; then
        BIN_DIR=$(dirname "$bin_cmd")
        echo "从进程检测到 kingbase 的 bin 目录: $BIN_DIR"
        return 0
    fi

    echo "警告: 未找到正在运行的 kingbase 进程。"
    diagnostic_mode
    exit 0
}

diagnostic_mode() {
    echo ""
    echo "=============================================================="
    echo "诊断模式：无法从进程获取 bin 目录，且未手动指定 -b。"
    echo "仅输出查找结果，不执行替换或重载操作。"
    echo "=============================================================="

    echo ""
    echo "查找所有 sys_ctl 可执行文件及其 bin 目录："
    local sysctl_paths
    sysctl_paths=$(find / -name sys_ctl -type f -executable 2>/dev/null)
    if [ -n "$sysctl_paths" ]; then
        local count=1
        echo "$sysctl_paths" | while IFS= read -r path; do
            local bin_dir
            bin_dir=$(dirname "$path")
            echo "  [$count] sys_ctl: $path"
            echo "      bin目录: $bin_dir"
            ((count++))
        done
    else
        echo "  未找到 sys_ctl 可执行文件。"
    fi

    echo ""
    echo "查找所有 kingbase.conf 文件所在目录："
    local conf_paths
    conf_paths=$(find / -name kingbase.conf -type f 2>/dev/null)
    if [ -n "$conf_paths" ]; then
        local count=1
        echo "$conf_paths" | while IFS= read -r conf; do
            local conf_dir
            conf_dir=$(dirname "$conf")
            echo "  [$count] kingbase.conf: $conf"
            echo "      所在目录: $conf_dir"
            ((count++))
        done
    else
        echo "  未找到 kingbase.conf 文件。"
    fi

    echo ""
    echo "=============================================================="
    echo "若要手动指定正确的 Kingbase 实例，请使用类似以下命令："
    echo "  $0 -b \"<bin目录>\" $NEW_LICENSE"
    local example_bin=""
    example_bin=$(find / -name sys_ctl -type f -executable 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
    if [ -n "$example_bin" ]; then
        echo "例如："
        echo "  $0 -b \"$example_bin\" $NEW_LICENSE"
    else
        echo "  $0 -b /path/to/bin $NEW_LICENSE"
    fi
    echo "=============================================================="
}

determine_kingbase_install() {
    if [[ "$BIN_DIR" == *"/KESRealPro/"* ]]; then
        KINGBASE_INSTALL=$(echo "$BIN_DIR" | sed -E 's|(.*)/KESRealPro/.*|\1|')
        echo "路径包含 KESRealPro，Kingbase_install 设置为: $KINGBASE_INSTALL (KESRealPro 的上级目录)"
    else
        KINGBASE_INSTALL=$(dirname "$(dirname "$BIN_DIR")")
        echo "路径不包含 KESRealPro，Kingbase_install 设置为 bin 的上两级目录: $KINGBASE_INSTALL"
    fi

    if [ ! -d "$KINGBASE_INSTALL" ]; then
        echo "错误: Kingbase_install 目录 '$KINGBASE_INSTALL' 不存在。"
        exit 1
    fi
}

replace_license_files() {
    local license_files
    license_files=$(find "$KINGBASE_INSTALL" -name "license.dat" -type f 2>/dev/null)

    if [ -z "$license_files" ]; then
        echo "警告: 在 $KINGBASE_INSTALL 下未找到任何 license.dat 文件。"
        return 0
    fi

    echo "找到以下 license.dat 文件:"
    echo "$license_files"

    local new_md5
    new_md5=$(md5sum "$NEW_LICENSE" | awk '{print $1}')
    local replaced_count=0

    for lic in $license_files; do
        echo "----------------------------------------"
        echo "处理文件: $lic"

        if [ -L "$lic" ]; then
            echo "跳过软链接: $lic"
            continue
        fi

        local backup_file="${lic}.bak.$(date +%Y%m%d%H%M%S)"
        echo "正在备份原文件至: $backup_file"
        if cp -p "$lic" "$backup_file" 2>/dev/null; then
            echo "✔ 备份成功"
        else
            echo "⚠ 警告: 备份失败，将继续替换操作（原文件可能无法恢复）"
        fi

        local old_md5
        old_md5=$(md5sum "$lic" | awk '{print $1}')
        echo "原文件 MD5: $old_md5"

        if cp -f "$NEW_LICENSE" "$lic"; then
            local replaced_md5
            replaced_md5=$(md5sum "$lic" | awk '{print $1}')
            echo "替换后文件 MD5: $replaced_md5"

            if [ "$new_md5" != "$replaced_md5" ]; then
                echo "✘ 错误: 替换后 MD5 不一致！"
                exit 1
            fi
            echo "✔ 替换成功，MD5 校验通过。"

            fix_ownership "$lic"
            ((replaced_count++))
        else
            echo "✘ 错误: 无法复制文件到 $lic"
            exit 1
        fi
    done

    if [ $replaced_count -eq 0 ]; then
        echo "未替换任何 license.dat 文件，可能全部为软链接。"
    else
        echo "共成功替换 $replaced_count 个 license.dat 文件。"
    fi
}

fix_ownership() {
    local target_file="$1"
    local current_owner
    current_owner=$(stat -c "%U:%G" "$target_file" 2>/dev/null || echo "unknown:unknown")
    echo "当前文件属主属组: $current_owner"

    if [ "$current_owner" != "kingbase:kingbase" ]; then
        if [ "$(id -u)" -eq 0 ]; then
            echo "当前用户为 root，正在修改属主为 kingbase:kingbase ..."
            if chown kingbase:kingbase "$target_file"; then
                echo "✔ 属主已修改为 kingbase:kingbase"
            else
                echo "✘ 错误: 无法修改文件属主，请检查。"
                exit 1
            fi
        else
            echo "⚠ 警告: 当前用户非 root，无法修改文件属主。"
            echo "  请手动执行: sudo chown kingbase:kingbase $target_file"
        fi
    else
        echo "✔ 文件属主已是 kingbase:kingbase，无需修改。"
    fi
}

acquire_data_directory() {
    echo "尝试自动获取数据目录..."
    DATA_DIR=$(ps -ef | grep 'bin/kingbase' | grep -v grep | sed -n 's/.*-D \([^ ]*\).*/\1/p' | head -1)

    if [ -z "$DATA_DIR" ]; then
        local kingbase_pid
        kingbase_pid=$(pgrep -f 'bin/kingbase' | head -1)
        if [ -n "$kingbase_pid" ]; then
            DATA_DIR=$(ps e -p "$kingbase_pid" 2>/dev/null | tr ' ' '\n' | grep '^PGDATA=' | cut -d= -f2-)
        fi
    fi

    if [ -z "$DATA_DIR" ] && [ -f "$BIN_DIR/../data/kingbase.conf" ]; then
        DATA_DIR=$(grep -E "^\s*data_directory\s*=" "$BIN_DIR/../data/kingbase.conf" | sed -E "s/^\s*data_directory\s*=\s*'([^']+)'.*/\1/")
    fi

    if [ -n "$DATA_DIR" ] && [ -d "$DATA_DIR" ]; then
        echo "数据目录确定为: $DATA_DIR"
    else
        echo "警告: 未能确定有效的数据目录。"
        DATA_DIR=""
    fi
}

reload_configuration() {
    local sys_ctl="$BIN_DIR/sys_ctl"
    if [ ! -x "$sys_ctl" ]; then
        echo "错误: sys_ctl 命令不存在或不可执行: $sys_ctl"
        exit 1
    fi

    echo "检查 sys_ctl 支持的重载选项..."
    local reload_cmd
    if "$sys_ctl" --help 2>&1 | grep -q 'reload_license'; then
        reload_cmd="reload_license"
        echo "sys_ctl 支持 reload_license，将使用 $reload_cmd"
    else
        reload_cmd="reload"
        echo "sys_ctl 不支持 reload_license，将使用 $reload_cmd"
    fi

    local reload_command="$sys_ctl -D $DATA_DIR $reload_cmd"

    if [ "$(id -u)" -eq 0 ]; then
        echo "检测到当前用户为 root，将切换至 kingbase 用户执行重载命令..."
        if id kingbase &>/dev/null; then
            if su - kingbase -c "$reload_command"; then
                echo "✔ 配置重载成功。"
            else
                echo "✘ 配置重载失败，请检查数据库日志或手动执行："
                echo "   su - kingbase -c \"$reload_command\""
                exit 1
            fi
        else
            echo "✘ 错误: 系统中不存在 kingbase 用户，无法切换执行重载命令。"
            exit 1
        fi
    else
        echo "执行重载配置: $reload_command"
        if $reload_command; then
            echo "✔ 配置重载成功。"
        else
            echo "✘ 配置重载失败，请检查数据库日志。"
            exit 1
        fi
    fi
}

# ---------------------------- 主流程 ----------------------------
main() {
    parse_arguments "$@"
    validate_license_file
    acquire_bin_directory
    determine_kingbase_install
    replace_license_files
    acquire_data_directory

    if [ -n "$MANUAL_BIN_DIR" ]; then
        echo "检测到手动指定了 bin 目录 (-b)，根据规则跳过配置重载步骤。"
    else
        if [ -n "$DATA_DIR" ]; then
            reload_configuration
        else
            echo "跳过重载步骤（数据目录无效）。"
        fi
    fi

    echo "所有操作完成。"
}

main "$@"