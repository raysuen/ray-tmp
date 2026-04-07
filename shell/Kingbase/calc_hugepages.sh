#!/bin/bash
# 
# 脚本名称: calc_hugepages.sh
# 功能描述: 根据 PostgreSQL / KingbaseES 的 shared_buffers 设置，计算所需的大页数量
# 使用方法: ./calc_hugepages.sh [选项]
#
#by raysuen
#v1.5

set -euo pipefail

# 默认值
DEFAULT_PSQL_BIN="/usr/local/pgsql/bin"  # 默认 psql 安装目录，可根据环境修改
PSQL_CMD="psql"                         # 实际使用的 psql 命令（可能是完整路径）
DEFAULT_HUGEPAGE_SIZE_KB=2048           # 2MB
SAFETY_FACTOR=1.1                       # 增加10%余量，覆盖 wal_buffers 等额外共享内存

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
  -s VALUE   直接指定 shared_buffers 值（例如 128MB, 4GB），此时不会连接数据库
  -d DBNAME  数据库名（默认为 postgres）
  -u USER    数据库用户名（默认为当前系统用户）
  -H HOST    数据库主机（默认为 localhost）
  -p PORT    数据库端口（默认为 5432）
  -b PATH    psql 可执行文件的路径（默认先在 PATH 中查找，若找不到则尝试 $DEFAULT_PSQL_BIN/psql）
  -z SIZE    大页大小，单位 KB（默认从 /proc/meminfo 读取，若失败则使用 2048KB）
              支持带单位的值，例如 2048KB, 2MB, 1GB
  -h         显示此帮助信息

说明:
  - 如果未指定 -s，脚本将通过 psql 连接数据库获取 shared_buffers 的值。
  - 计算的大页数量 = ceil( shared_buffers_bytes * SAFETY_FACTOR / hugepage_size_bytes )。
  - 建议将计算值设置为 vm.nr_hugepages，并预留一些余量。

示例:
  # 使用默认连接（Unix socket 或 localhost）获取 shared_buffers 并计算
  $0

  # 指定数据库连接信息
  $0 -H 192.168.1.100 -p 5433 -u postgres -d mydb

  # 手动指定 shared_buffers 值（无需连接数据库）
  $0 -s 4GB

  # 指定 psql 路径（例如使用金仓数据库的 ksql）
  $0 -b /opt/Kingbase/ES/V9/Server/bin/ksql

  # 指定大页大小为 1GB（1048576KB），可以写成 1GB 或 1048576KB
  $0 -s 8GB -z 1GB

  # 组合使用：指定连接、psql 路径，并手动指定 shared_buffers（-s 会忽略连接）
  $0 -s 16GB -b /usr/local/pgsql/bin/psql -H localhost
EOF
    exit 0
}

# 将带单位的内存大小转换为字节（支持 K, M, G, T）
to_bytes() {
    local val="$1"
    val=$(echo "$val" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    local num=${val%[KMGT]?}
    local unit=${val#$num}
    case "$unit" in
        K|KB)   echo $((num * 1024)) ;;
        M|MB)   echo $((num * 1024 * 1024)) ;;
        G|GB)   echo $((num * 1024 * 1024 * 1024)) ;;
        T|TB)   echo $((num * 1024 * 1024 * 1024 * 1024)) ;;
        *)      echo $num ;;
    esac
}

# 将带单位的内存大小转换为 KB（支持 K, M, G, T）
to_kb() {
    local val="$1"
    local bytes=$(to_bytes "$val")
    echo $((bytes / 1024))
}

# 解析命令行参数（使用 getopts）
SHARED_BUFFERS=""
DBNAME="postgres"
USER=""
HOST="localhost"
PORT="5432"
HUGEPAGE_SIZE_KB=""
USE_PSQL=true

while getopts "s:d:u:H:p:b:z:h" opt; do
    case "$opt" in
        s)  SHARED_BUFFERS="$OPTARG"
            USE_PSQL=false
            ;;
        d)  DBNAME="$OPTARG"
            ;;
        u)  USER="$OPTARG"
            ;;
        H)  HOST="$OPTARG"
            ;;
        p)  PORT="$OPTARG"
            ;;
        b)  PSQL_CMD="$OPTARG"
            ;;
        z)  # 支持带单位的值，转换为KB
            HUGEPAGE_SIZE_KB=$(to_kb "$OPTARG")
            ;;
        h)  show_help
            ;;
        \?) echo "无效选项: -$OPTARG" >&2
            show_help
            ;;
    esac
done

# 1. 获取 shared_buffers 的值（字节）
if [ "$USE_PSQL" = true ]; then
    # 确定实际使用的 psql 命令
    if [ "$PSQL_CMD" = "psql" ]; then
        # 未通过 -b 指定，先尝试 PATH 中的 psql
        if ! command -v "psql" &> /dev/null; then
            # PATH 中没有 psql，尝试默认 bin 目录
            if [ -x "$DEFAULT_PSQL_BIN/psql" ]; then
                PSQL_CMD="$DEFAULT_PSQL_BIN/psql"
                echo "提示: 使用默认 bin 目录中的 psql: $PSQL_CMD" >&2
            else
                echo "错误: 未找到 psql 命令。请确保 PostgreSQL 客户端已安装，或使用 -s 手动指定 shared_buffers 值。" >&2
                echo "      如果 psql 安装在非标准路径，请使用 -b 选项指定其完整路径。" >&2
                exit 1
            fi
        fi
    else
        # 用户通过 -b 指定了路径，检查是否存在
        if ! command -v "$PSQL_CMD" &> /dev/null; then
            echo "错误: 未找到指定的 psql 命令: $PSQL_CMD" >&2
            exit 1
        fi
    fi
    
    # 构建 psql 连接参数
    PSQL_OPTS=""
    [ -n "$DBNAME" ] && PSQL_OPTS="$PSQL_OPTS -d $DBNAME"
    [ -n "$USER" ] && PSQL_OPTS="$PSQL_OPTS -U $USER"
    [ -n "$HOST" ] && PSQL_OPTS="$PSQL_OPTS -h $HOST"
    [ -n "$PORT" ] && PSQL_OPTS="$PSQL_OPTS -p $PORT"
    
    # 获取 shared_buffers 的原始字符串（例如 '128MB'）
    SHARED_BUFFERS_RAW=$($PSQL_CMD $PSQL_OPTS -t -c "SHOW shared_buffers;" 2>/dev/null | xargs)
    if [ -z "$SHARED_BUFFERS_RAW" ]; then
        echo "错误: 无法连接到数据库，请检查连接参数或使用 -s 手动指定值。" >&2
        exit 1
    fi
    SHARED_BUFFERS="$SHARED_BUFFERS_RAW"
fi

if [ -z "$SHARED_BUFFERS" ]; then
    echo "错误: 未能获取 shared_buffers 值。" >&2
    exit 1
fi

# 转换 shared_buffers 为字节
SHARED_BUFFERS_BYTES=$(to_bytes "$SHARED_BUFFERS")
if ! [[ "$SHARED_BUFFERS_BYTES" =~ ^[0-9]+$ ]]; then
    echo "错误: shared_buffers 值 '$SHARED_BUFFERS' 无法转换为数字。" >&2
    exit 1
fi

# 2. 获取系统的大页大小（KB）
if [ -z "$HUGEPAGE_SIZE_KB" ]; then
    # 从 /proc/meminfo 读取 Hugepagesize
    if [ -f /proc/meminfo ]; then
        HUGEPAGE_SIZE_KB=$(grep -i "Hugepagesize:" /proc/meminfo | awk '{print $2}')
    fi
    if [ -z "$HUGEPAGE_SIZE_KB" ] || ! [[ "$HUGEPAGE_SIZE_KB" =~ ^[0-9]+$ ]]; then
        HUGEPAGE_SIZE_KB=$DEFAULT_HUGEPAGE_SIZE_KB
        echo "提示: 无法从 /proc/meminfo 获取大页大小，使用默认值 ${HUGEPAGE_SIZE_KB}KB" >&2
    fi
fi

# 确保 HUGEPAGE_SIZE_KB 是整数
if ! [[ "$HUGEPAGE_SIZE_KB" =~ ^[0-9]+$ ]]; then
    echo "错误: 大页大小 '$HUGEPAGE_SIZE_KB' 不是有效的数字。" >&2
    exit 1
fi

# 转为字节
HUGEPAGE_SIZE_BYTES=$((HUGEPAGE_SIZE_KB * 1024))

# 3. 计算所需大页数量
# 加上安全余量，向上取整
NEED_BYTES=$(echo "$SHARED_BUFFERS_BYTES * $SAFETY_FACTOR" | bc | awk '{print int($0)}')
HUGEPAGES_NEEDED=$(( (NEED_BYTES + HUGEPAGE_SIZE_BYTES - 1) / HUGEPAGE_SIZE_BYTES ))

# 4. 输出结果
echo "========================================="
echo "          HugePages 计算报告"
echo "========================================="
echo "shared_buffers 配置值:   $SHARED_BUFFERS"
echo "shared_buffers 字节数:   $SHARED_BUFFERS_BYTES"
echo "大页大小:                ${HUGEPAGE_SIZE_KB}KB ($HUGEPAGE_SIZE_BYTES 字节)"
echo "安全系数:                $SAFETY_FACTOR (覆盖额外共享内存)"
echo "预估所需大页数量:        $HUGEPAGES_NEEDED"
echo "========================================="
echo "建议在 /etc/sysctl.conf 中设置:"
echo "  vm.nr_hugepages = $HUGEPAGES_NEEDED"
echo "然后执行 sysctl -p 使其生效。"
echo "注意: 预留后请重启数据库服务。"