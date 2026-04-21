#!/bin/bash
# =============================================================================
# by raysuen
# v4.2
# =============================================================================

# ----------------------------- 全局变量 ---------------------------------
# 数据库密码（若含特殊字符，请用单引号包裹）
db_pwd=''

# 数据库连接用户名（默认 system，可通过 -u 参数覆盖）
DB_USER="system"

# 备份文件根目录（可按需修改）
BACKUP_BASE_DIR="/kingbase/dump/back"

# 备份文件保留天数（可按需修改）
RETENTION_DAYS=30

back_dir="${BACKUP_BASE_DIR}/$(date +%Y%m%d)"
rm_dir="${BACKUP_BASE_DIR}/$(date -d "-${RETENTION_DAYS} day" +%Y%m%d 2>/dev/null || date -v-${RETENTION_DAYS}d +%Y%m%d 2>/dev/null || echo "")"
hostinf="127.0.0.1"
specified_dbs=""
specified_schema=""
compress=0
kingbase_bin=""
db_port=""
LOG_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info()  { echo "[INFO] $LOG_TIMESTAMP - $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $LOG_TIMESTAMP - $*" >&2; }

# ----------------------------- 帮助信息 ---------------------------------
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
  -d 数据库列表   指定要备份的数据库（逗号分隔）
  -s schema名     指定schema（需配合-d）
  -u 用户名       指定连接数据库的用户名（默认：system）
  -z              启用gzip压缩
  -b 路径         指定kingbase二进制目录
  -p 端口         指定数据库端口
  -h              显示本帮助

配置说明:
  - 默认连接用户：system（可通过 -u 修改）
  - 备份根目录：${BACKUP_BASE_DIR}（可修改脚本顶部 BACKUP_BASE_DIR 变量）
  - 备份文件默认保留 ${RETENTION_DAYS} 天（可修改 RETENTION_DAYS 变量）

示例:
  $0                                                                                  # 全量备份所有用户库（用户 system）
  $0 -d db1,db2,db3                                                         #备份指定的多个数据库
  $0 -b /opt/Kingbase/ES/V8/Server/bin -p 54321 -z       #指定数据库端口和二进制路径（适用于自定义安装）
  $0 -u kingbase -d mydb -s public -z                              # 使用 kingbase 用户备份指定库的 public schema
  $0 -b /opt/kingbase/bin -p 54321                                  # 手动指定路径和端口
EOF
}

# ----------------------------- 参数解析 ---------------------------------
parse_args() {
    while getopts "d:s:u:zb:p:h" opt; do
        case $opt in
            d) specified_dbs="$OPTARG" ;;
            s) specified_schema="$OPTARG" ;;
            u) DB_USER="$OPTARG" ;;
            z) compress=1 ;;
            b) kingbase_bin="$OPTARG" ;;
            p) db_port="$OPTARG" ;;
            h) show_help; exit 0 ;;
            *) exit 1 ;;
        esac
    done

    if [[ -n "$specified_schema" && -z "$specified_dbs" ]]; then
        log_error "使用 -s 指定 schema 时必须同时用 -d 指定数据库"
        exit 1
    fi
}

# ----------------------------- 密码设置 ---------------------------------
setup_password() {
    if [[ -n "$db_pwd" ]]; then
        export PGPASSWORD="$db_pwd"
        export KINGBASE_PASSWORD="$db_pwd"
        log_info "密码环境变量已设置"
    else
        log_error "未在脚本中设置 db_pwd 变量，且未发现外部 PGPASSWORD 环境变量"
        log_error "请在脚本顶部修改变量 db_pwd 或执行 export PGPASSWORD='你的密码'"
        exit 1
    fi
}

# ----------------------------- 环境检测 ---------------------------------
detect_environment() {
    local checkpointer_pids
    checkpointer_pids=$(pgrep -f "kingbase:.*checkpointer" 2>/dev/null || true)

    if [[ -z "$checkpointer_pids" ]]; then
        log_error "未检测到运行中的 KingbaseES 实例"
        exit 1
    fi

    local KESPID=$(echo "$checkpointer_pids" | head -1)
    log_info "检测到 KingbaseES 进程 PID: $KESPID"

    if [[ -f "/proc/$KESPID/exe" ]]; then
        kingbase_bin_detected=$(dirname "$(readlink -f "/proc/$KESPID/exe")")
        log_info "自动检测二进制路径: $kingbase_bin_detected"
    else
        log_error "无法获取二进制路径，请使用 -b 参数指定"
        exit 1
    fi

    [[ -z "$kingbase_bin" ]] && kingbase_bin="$kingbase_bin_detected"

    if [[ -z "$db_port" ]]; then
        local socket_file
        socket_file=$(find /tmp -name ".s.KINGBASE.*" -type s 2>/dev/null | head -1) || true
        if [[ -n "$socket_file" ]]; then
            db_port=$(basename "$socket_file" | grep -Eo '[0-9]+$' || echo "")
            [[ -n "$db_port" ]] && log_info "通过 Unix socket 检测到端口: $db_port"
        fi
        if [[ -z "$db_port" ]]; then
            db_port=54321
            log_info "使用默认端口: $db_port"
        fi
    fi
}

# ----------------------------- 测试连接 ---------------------------------
test_connection() {
    log_info "测试数据库连接（用户: $DB_USER，主机: $hostinf:$db_port）..."
    if ! "$kingbase_bin/ksql" -U "$DB_USER" -h "$hostinf" -p "$db_port" -d template1 -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "数据库连接失败！请检查："
        log_error "  - 服务是否运行"
        log_error "  - 密码是否正确（当前使用脚本内 db_pwd 变量）"
        log_error "  - 用户 '$DB_USER' 是否有权限访问"
        log_error "  - 防火墙设置"
        exit 1
    fi
    log_info "数据库连接测试成功"
}

# ----------------------------- 获取数据库列表 ---------------------------
get_db_list() {
    local all_dbs
    if ! all_dbs=$("$kingbase_bin/ksql" -U "$DB_USER" -h "$hostinf" -p "$db_port" -d template1 -Atc "SELECT datname FROM sys_catalog.sys_database;"); then
        log_error "无法获取数据库列表"
        exit 1
    fi

    if [[ -n "$specified_dbs" ]]; then
        IFS=',' read -ra db_array <<< "$specified_dbs"
        local valid_dbs=""
        for db in "${db_array[@]}"; do
            if echo "$all_dbs" | grep -qxF "$db"; then
                valid_dbs="$valid_dbs $db"
            else
                log_info "指定的数据库 '$db' 不存在，已跳过"
            fi
        done
        if [[ -z "$valid_dbs" ]]; then
            log_error "没有有效的数据库可备份"
            exit 1
        fi
        DATABASES="$valid_dbs"
    else
        DATABASES=$("$kingbase_bin/ksql" -U "$DB_USER" -h "$hostinf" -p "$db_port" -d template1 -Atc \
            "SELECT datname FROM sys_catalog.sys_database WHERE datname NOT IN ('test','template1','template0','security','kingbase');")
        if [[ -z "$DATABASES" ]]; then
            log_error "未找到任何用户数据库"
            exit 1
        fi
    fi
    log_info "待备份数据库列表: ${DATABASES//$'\n'/ }"
}

# ----------------------------- 执行备份 ---------------------------------
perform_backup() {
    mkdir -p "$back_dir" || { log_error "无法创建备份目录 $back_dir"; exit 1; }

    for db in $DATABASES; do
        log_info "开始备份数据库: $db ${specified_schema:+（schema: $specified_schema）}"

        local encoding
        encoding=$("$kingbase_bin/ksql" -U "$DB_USER" -h "$hostinf" -p "$db_port" -d "$db" -Atc "SHOW server_encoding;" 2>/dev/null | tr -d '[:space:]')
        [[ -z "$encoding" ]] && encoding="UTF8"

        local output_file="${back_dir}/${db}${specified_schema:+.${specified_schema}}.dump"
        local dump_cmd=("$kingbase_bin/sys_dump" -U "$DB_USER" -h "$hostinf" -p "$db_port" -Fc -d "$db" -E "$encoding")
        [[ -n "$specified_schema" ]] && dump_cmd+=(-n "$specified_schema")
        dump_cmd+=(-f "$output_file")

        if "${dump_cmd[@]}"; then
            log_info "备份成功: $output_file"
            if [[ $compress -eq 1 ]]; then
                if gzip -f "$output_file"; then
                    log_info "压缩成功: ${output_file}.gz"
                else
                    log_error "压缩失败"
                fi
            fi
        else
            log_error "备份失败: $db"
        fi
    done
}

# ----------------------------- 清理过期备份 -----------------------------
cleanup_old_backups() {
    local cutoff_date
    cutoff_date=$(date -d "-${RETENTION_DAYS} day" +%Y%m%d 2>/dev/null || date -v-${RETENTION_DAYS}d +%Y%m%d 2>/dev/null)
    [[ -z "$cutoff_date" ]] && { log_error "无法计算过期日期，跳过清理"; return; }

    local old_dir="${BACKUP_BASE_DIR}/$cutoff_date"
    if [[ -d "$old_dir" ]]; then
        local resolved=$(readlink -f "$old_dir" 2>/dev/null || realpath "$old_dir" 2>/dev/null || echo "$old_dir")
        # 安全检查：确保待删除目录确实在备份根目录下
        if [[ "$resolved" != "${BACKUP_BASE_DIR}/"* ]]; then
            log_error "安全保护：拒绝删除非备份目录 $resolved"
            return
        fi
        log_info "清理过期备份（保留 ${RETENTION_DAYS} 天）: $resolved"
        rm -rf "$resolved" && log_info "清理完成"
    else
        log_info "没有需要清理的过期备份（${old_dir}）"
    fi
}

# ----------------------------- 主流程 -----------------------------------
main() {
    parse_args "$@"
    setup_password
    [[ -z "$kingbase_bin" || -z "$db_port" ]] && detect_environment
    log_info "使用二进制: $kingbase_bin, 端口: $db_port, 用户: $DB_USER"
    log_info "备份根目录: $BACKUP_BASE_DIR，保留 ${RETENTION_DAYS} 天"
    test_connection
    get_db_list
    perform_backup
    cleanup_old_backups
    log_info "所有备份任务执行完毕"
}

main "$@"