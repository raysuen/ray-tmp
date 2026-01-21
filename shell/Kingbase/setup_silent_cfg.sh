#!/bin/bash
# 金仓数据库silent.cfg自动配置脚本（最终完整版）
# 功能：指定挂载点复制silent.cfg + 大小写兼容 + 显示所有核心配置 + 输出静默安装命令
# by raysuen
# v1.0

# 定义默认值
DEFAULT_MOUNT_POINT="/mnt"
DEFAULT_TARGET_DIR="$HOME"
DEFAULT_LICENSE_PATH="license_r6_180.dat"
DEFAULT_INSTALL_DIR="/opt/Kingbase/ES/V8"
DEFAULT_DATA_DIR="${DEFAULT_INSTALL_DIR}/data"
DEFAULT_DB_PORT="54321"
DEFAULT_DB_USER="system"
DEFAULT_DB_PASS="kingbase@123"
DEFAULT_ENCODING="UTF8"
DEFAULT_DB_MODE="mysql"
DEFAULT_CASE_SENSITIVE="NO"
DEFAULT_BLOCK_SIZE="8k"
DEFAULT_ENCRYPT_METHOD="sm4"
DEFAULT_AUTH_METHOD="scram-sha-256"

# 初始化变量
MOUNT_POINT=""
INSTALL_DIR=""
DATA_DIR=""
DB_PORT=""
DB_USER=""
DB_PASS=""
LICENSE_PATH=""
ENCODING=""
DB_MODE=""
CASE_SENSITIVE=""
BLOCK_SIZE=""
ENCRYPT_METHOD=""
AUTH_METHOD=""

# 帮助信息
show_help() {
    echo "用法：$0 [选项]"
    echo "  自动复制挂载点下的silent.cfg并自定义配置内容（含静默安装命令提示）"
    echo ""
    echo "必选选项："
    echo "  -m <路径>       指定挂载点（如/mnt，默认：${DEFAULT_MOUNT_POINT}）"
    echo ""
    echo "可选配置项（不指定则使用默认值，大小写不敏感）："
    echo "  -lp <路径>      许可证文件路径（默认：${DEFAULT_LICENSE_PATH}）"
    echo "  -id <路径>      安装目录（默认：${DEFAULT_INSTALL_DIR}）"
    echo "  -dd <路径>      数据目录（默认：安装目录/data）"
    echo "  -p <端口>       数据库端口（1-65535，默认：${DEFAULT_DB_PORT}）"
    echo "  -u <用户名>     数据库管理员用户名（默认：${DEFAULT_DB_USER}）"
    echo "  -pw <密码>      数据库管理员密码（默认：${DEFAULT_DB_PASS}）"
    echo "  -e <编码>       数据库编码（UTF8/GBK/GB18030，默认：${DEFAULT_ENCODING}）"
    echo "  -dm <模式>      兼容模式（ORACLE/PG/MySQL，默认：${DEFAULT_DB_MODE}）"
    echo "  -cs <YES/NO>    大小写敏感（默认：${DEFAULT_CASE_SENSITIVE}）"
    echo "  -bs <大小>      块大小（8k/16k/32k，默认：${DEFAULT_BLOCK_SIZE}）"
    echo "  -em <方法>      加密方式（sm4/rc4/wstsdk_cd，默认：${DEFAULT_ENCRYPT_METHOD}）"
    echo "  -am <方法>      认证方式（scram-sha-256/scram-sm3等，默认：${DEFAULT_AUTH_METHOD}）"
    echo "  -h              显示帮助信息"
    echo ""
    echo "示例："
    echo "  $0 -m /mnt -id /opt/zhongfa/kingbase/ES/V8 -p 54321 -pw q61iHrUmCJ<pve> -dm mysql -cs NO"
}

# 解析短参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m) MOUNT_POINT="$2"; shift 2 ;;
        -lp) LICENSE_PATH="$2"; shift 2 ;;
        -id) INSTALL_DIR="$2"; shift 2 ;;
        -dd) DATA_DIR="$2"; shift 2 ;;
        -p) DB_PORT="$2"; shift 2 ;;
        -u) DB_USER="$2"; shift 2 ;;
        -pw) DB_PASS="$2"; shift 2 ;;
        -e) ENCODING="$2"; shift 2 ;;
        -dm) DB_MODE="$2"; shift 2 ;;
        -cs) CASE_SENSITIVE="$2"; shift 2 ;;
        -bs) BLOCK_SIZE="$2"; shift 2 ;;
        -em) ENCRYPT_METHOD="$2"; shift 2 ;;
        -am) AUTH_METHOD="$2"; shift 2 ;;
        -h) show_help; exit 0 ;;
        *) echo "错误：未知参数 $1"; show_help; exit 1 ;;
    esac
done

# 补全默认值
MOUNT_POINT=${MOUNT_POINT:-$DEFAULT_MOUNT_POINT}
LICENSE_PATH=${LICENSE_PATH:-$DEFAULT_LICENSE_PATH}
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}
DATA_DIR=${DATA_DIR:-${INSTALL_DIR}/data}
DB_PORT=${DB_PORT:-$DEFAULT_DB_PORT}
DB_USER=${DB_USER:-$DEFAULT_DB_USER}
DB_PASS=${DB_PASS:-$DEFAULT_DB_PASS}
ENCODING=${ENCODING:-$DEFAULT_ENCODING}
DB_MODE=${DB_MODE:-$DEFAULT_DB_MODE}
CASE_SENSITIVE=${CASE_SENSITIVE:-$DEFAULT_CASE_SENSITIVE}
BLOCK_SIZE=${BLOCK_SIZE:-$DEFAULT_BLOCK_SIZE}
ENCRYPT_METHOD=${ENCRYPT_METHOD:-$DEFAULT_ENCRYPT_METHOD}
AUTH_METHOD=${AUTH_METHOD:-$DEFAULT_AUTH_METHOD}

# 定义源/目标文件
SRC_SILENT_CFG="${MOUNT_POINT}/setup/silent.cfg"
DEST_SILENT_CFG="${DEFAULT_TARGET_DIR}/silent.cfg"

# 1. 校验挂载点和源文件
echo "===== 开始校验源文件 ====="
if [ ! -d "${MOUNT_POINT}" ]; then
    echo "错误：挂载点 ${MOUNT_POINT} 不存在！"
    exit 1
fi
if [ ! -f "${SRC_SILENT_CFG}" ]; then
    echo "错误：源文件 ${SRC_SILENT_CFG} 不存在！"
    exit 1
fi
echo "✅ 源文件校验通过：${SRC_SILENT_CFG}"

# 2. 复制文件
echo -e "\n===== 复制silent.cfg到目标目录 ====="
cp -f "${SRC_SILENT_CFG}" "${DEST_SILENT_CFG}"
if [ $? -ne 0 ]; then
    echo "错误：复制文件失败！请检查权限。"
    exit 1
fi
chmod 600 "${DEST_SILENT_CFG}"
echo "✅ 已复制到：${DEST_SILENT_CFG}"

# 3. 合法性检查（大小写不敏感，local仅在函数内）
check_validate() {
    # 端口校验
    if ! [[ "${DB_PORT}" =~ ^[0-9]+$ ]] || [ "${DB_PORT}" -lt 1 ] || [ "${DB_PORT}" -gt 65535 ]; then
        echo "错误：数据库端口 ${DB_PORT} 无效（必须是1-65535的数字）"
        exit 1
    fi

    # 编码校验（转大写后匹配）
    local ENCODING_UPPER=$(echo "${ENCODING}" | tr '[:lower:]' '[:upper:]')
    if ! [[ "${ENCODING_UPPER}" =~ ^(UTF8|GBK|GB18030)$ ]]; then
        echo "错误：编码 ${ENCODING} 无效（仅支持UTF8/GBK/GB18030）"
        exit 1
    fi

    # 兼容模式校验（转大写后匹配）
    local DB_MODE_UPPER=$(echo "${DB_MODE}" | tr '[:lower:]' '[:upper:]')
    if ! [[ "${DB_MODE_UPPER}" =~ ^(ORACLE|PG|MYSQL)$ ]]; then
        echo "错误：兼容模式 ${DB_MODE} 无效（仅支持ORACLE/PG/MySQL）"
        exit 1
    fi

    # 大小写敏感校验（转大写后匹配）
    local CASE_SENSITIVE_UPPER=$(echo "${CASE_SENSITIVE}" | tr '[:lower:]' '[:upper:]')
    if ! [[ "${CASE_SENSITIVE_UPPER}" =~ ^(YES|NO)$ ]]; then
        echo "错误：大小写敏感 ${CASE_SENSITIVE} 无效（仅支持YES/NO）"
        exit 1
    fi

    # 块大小校验（转小写后匹配）
    local BLOCK_SIZE_LOWER=$(echo "${BLOCK_SIZE}" | tr '[:upper:]' '[:lower:]')
    if ! [[ "${BLOCK_SIZE_LOWER}" =~ ^(8k|16k|32k)$ ]]; then
        echo "错误：块大小 ${BLOCK_SIZE} 无效（仅支持8k/16k/32k）"
        exit 1
    fi

    # 加密方式校验（转小写后匹配）
    local ENCRYPT_METHOD_LOWER=$(echo "${ENCRYPT_METHOD}" | tr '[:upper:]' '[:lower:]')
    if ! [[ "${ENCRYPT_METHOD_LOWER}" =~ ^(sm4|rc4|wstsdk_cd)$ ]]; then
        echo "错误：加密方式 ${ENCRYPT_METHOD} 无效（仅支持sm4/rc4/wstsdk_cd）"
        exit 1
    fi
}

# 执行合法性检查
echo -e "\n===== 校验配置参数合法性 ====="
check_validate
echo "✅ 配置参数全部合法"

# 4. 替换配置内容（规范格式转换）
echo -e "\n===== 替换silent.cfg配置内容 ====="
ESCAPED_DB_PASS=$(echo "${DB_PASS}" | sed -e 's/[\/&<>]/\\&/g')

# 转换为规范格式
ENCODING_FINAL=$(echo "${ENCODING}" | tr '[:lower:]' '[:upper:]')
DB_MODE_FINAL=$(echo "${DB_MODE}" | tr '[:lower:]' '[:upper:]' | sed 's/MYSQL/MySQL/')
CASE_SENSITIVE_FINAL=$(echo "${CASE_SENSITIVE}" | tr '[:lower:]' '[:upper:]')
BLOCK_SIZE_FINAL=$(echo "${BLOCK_SIZE}" | tr '[:upper:]' '[:lower:]')
ENCRYPT_METHOD_FINAL=$(echo "${ENCRYPT_METHOD}" | tr '[:upper:]' '[:lower:]')
AUTH_METHOD_FINAL=$(echo "${AUTH_METHOD}" | tr '[:lower:]' '[:upper:]')

# 逐行替换配置项
sed -i "s|^KB_LICENSE_PATH=.*|KB_LICENSE_PATH=${LICENSE_PATH}|g" "${DEST_SILENT_CFG}"
sed -i "s|^USER_INSTALL_DIR=.*|USER_INSTALL_DIR=${INSTALL_DIR}|g" "${DEST_SILENT_CFG}"
sed -i "s|^USER_SELECTED_DATA_FOLDER=.*|USER_SELECTED_DATA_FOLDER=${DATA_DIR}|g" "${DEST_SILENT_CFG}"
sed -i "s|^DB_PORT=.*|DB_PORT=${DB_PORT}|g" "${DEST_SILENT_CFG}"
sed -i "s|^DB_USER=.*|DB_USER=${DB_USER}|g" "${DEST_SILENT_CFG}"
sed -i "s|^DB_PASS=.*|DB_PASS=${ESCAPED_DB_PASS}|g" "${DEST_SILENT_CFG}"
sed -i "s|^DB_PASS2=.*|DB_PASS2=${ESCAPED_DB_PASS}|g" "${DEST_SILENT_CFG}"
sed -i "s|^ENCODING_PARAM=.*|ENCODING_PARAM=${ENCODING_FINAL}|g" "${DEST_SILENT_CFG}"
sed -i "s|^DATABASE_MODE_PARAM=.*|DATABASE_MODE_PARAM=${DB_MODE_FINAL}|g" "${DEST_SILENT_CFG}"
sed -i "s|^CASE_SENSITIVE_PARAM=.*|CASE_SENSITIVE_PARAM=${CASE_SENSITIVE_FINAL}|g" "${DEST_SILENT_CFG}"
sed -i "s|^BLOCK_SIZE_PARAM=.*|BLOCK_SIZE_PARAM=${BLOCK_SIZE_FINAL}|g" "${DEST_SILENT_CFG}"
sed -i "s|^ENCRYPT_METHOD_PARAM=.*|ENCRYPT_METHOD_PARAM=${ENCRYPT_METHOD_FINAL}|g" "${DEST_SILENT_CFG}"
sed -i "s|^AUTHENTICATION_METHOD_PARAM=.*|AUTHENTICATION_METHOD_PARAM=${AUTH_METHOD_FINAL}|g" "${DEST_SILENT_CFG}"

# 5. 输出完成信息（含静默安装命令）
echo -e "\n===== 配置完成 ====="
echo "📌 挂载点：${MOUNT_POINT}"
echo "📌 目标文件：${DEST_SILENT_CFG}"
echo "📌 核心配置（完整）："
echo "   - 许可证路径：${LICENSE_PATH}"
echo "   - 安装目录：${INSTALL_DIR}"
echo "   - 数据目录：${DATA_DIR}"
echo "   - 数据库端口：${DB_PORT}"
echo "   - 数据库用户：${DB_USER}"
echo "   - 兼容模式：${DB_MODE_FINAL}"
echo "   - 字符编码：${ENCODING_FINAL}"
echo "   - 大小写敏感：${CASE_SENSITIVE_FINAL}"
echo "   - 块大小：${BLOCK_SIZE_FINAL}"
echo "   - 加密方式：${ENCRYPT_METHOD_FINAL}"
echo "   - 认证方式：${AUTH_METHOD_FINAL}"

# 核心新增：输出金仓数据库静默安装命令（动态拼接路径）
echo -e "\n📌 金仓数据库静默安装命令（直接复制执行）："
INSTALL_CMD="sh ${MOUNT_POINT}/setup.sh -i silent -f ${DEST_SILENT_CFG}"
echo "=============================================="
echo "${INSTALL_CMD}"
echo "=============================================="

echo -e "\n✅ silent.cfg配置完成！可复制上方命令执行静默安装。"