#!/bin/bash
#by raysuen
#v1.0

set -o pipefail

# ===================== 配置项 =====================
KINGBASE_DATA_DIR="/path/to/kingbase/data"
TMP_DIR="${KINGBASE_DATA_DIR}/base/syssql_tmp"

# ===================== 颜色定义 =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ===================== 帮助函数 =====================
usage() {
    echo -e "${BLUE}===== 金仓syssql_tmp文件PID统计脚本（fuser稳定版） =====${NC}"
    echo -e "功能：基于fuser遍历syssql_tmp文件，统计每个PID关联文件数（去重）"
    echo -e "\n${BLUE}用法：${NC}"
    echo -e "  $0 [选项] [金仓data目录路径]"
    echo -e "\n${BLUE}选项：${NC}"
    echo -e "  -h, --help        显示本帮助信息并退出"
    echo -e "\n${BLUE}参数说明：${NC}"
    echo -e "  金仓data目录路径  可选，默认使用脚本内配置的 KINGBASE_DATA_DIR"
    echo -e "\n${BLUE}注意事项：${NC}"
    echo -e "  1. 必须root用户执行（fuser需要系统级权限）"
    echo -e "  2. 依赖fuser（默认系统自带，无需额外安装）"
    echo -e "\n${BLUE}示例：${NC}"
    echo -e "  1. 自定义data目录统计：$0 /home/kingbase/data"
    echo -e "  2. 查看帮助：$0 -h"
    exit 0
}

# ===================== 初始化全局变量 =====================
declare -A pid_file_count  # PID => 文件数（去重统计）
declare -A pid_user       # PID => 所属用户名
total_files=0             # 冻结的总文件数
total_files_real=0        # 实际处理的文件数
no_pid_files=0            # 无PID文件数
file_list_tmp=$(mktemp)   # 临时文件存储冻结的文件列表

# ===================== 前置检查与参数解析 =====================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        *)
            KINGBASE_DATA_DIR="$1"
            TMP_DIR="${KINGBASE_DATA_DIR}/base/syssql_tmp"
            shift ;;
    esac
done

# 检查fuser
if ! command -v fuser &> /dev/null; then
    echo -e "${RED}错误：未找到fuser命令，请检查系统环境${NC}"
    rm -f "${file_list_tmp}"
    exit 1
fi

# 检查目录
if [ ! -d "${TMP_DIR}" ]; then
    echo -e "${RED}错误：目录不存在 → ${TMP_DIR}${NC}"
    rm -f "${file_list_tmp}"
    exit 1
fi

# ===================== 冻结文件列表 =====================
echo -e "${BLUE}🔍 冻结文件列表（避免遍历过程中文件数变化）...${NC}"
find "${TMP_DIR}" -maxdepth 1 -type f > "${file_list_tmp}"
total_files=$(wc -l < "${file_list_tmp}")
echo -e "${BLUE}✅ 冻结完成，本次统计文件总数：${total_files}${NC}"
echo -e "${GREEN}===== 开始检索PID/USER关联关系（fuser稳定版） =====${NC}"

# ===================== 核心逻辑：稳定提取PID+用户名 =====================
while read -r tmp_file; do
    [ -z "${tmp_file}" ] && continue
    [ ! -f "${tmp_file}" ] && continue
    total_files_real=$((total_files_real + 1))

    # 进度提示
    if [ $((total_files_real % 10)) -eq 0 ]; then  # 17个文件，每10个提示更友好
        echo -e "${BLUE}📊 已处理 ${total_files_real}/${total_files} 个文件${NC}"
    fi

    # ===== 修复：稳定提取PID（不用-v，直接取fuser默认输出） =====
    # fuser默认输出：仅返回PID，多个PID用空格分隔，取第一个即可
    pid=$(fuser "${tmp_file}" 2>/dev/null | awk '{print $1}' | tr -d ' ' || true)
    
    # 校验PID是否有效（数字）
    if [[ -z "${pid}" || ! "${pid}" =~ ^[0-9]+$ ]]; then
        no_pid_files=$((no_pid_files + 1))
        continue
    fi

    # ===== 修复：稳定获取用户名（双重兜底） =====
    # 方式1：从PID获取用户名（优先）
    user=$(ps -p "${pid}" -o user= 2>/dev/null | tr -d ' ')
    # 方式2：兜底：从文件属主获取用户名
    if [[ -z "${user}" || "${user}" = "" ]]; then
        user=$(ls -l "${tmp_file}" | awk '{print $3}')
    fi
    # 最终兜底：显示kingbase（已知文件属主）
    user=${user:-kingbase}

    # ===== 去重统计 =====
    pid_file_count["${pid}"]=$(( ${pid_file_count["${pid}"]:-0} + 1 ))
    [ -z "${pid_user["${pid}"]}" ] && pid_user["${pid}"]="${user}"
done < "${file_list_tmp}"

# ===================== 输出文件明细（前10条） =====================
echo -e "\n${BLUE}===== 文件-PID关联明细（前10条，共${total_files_real}条） =====${NC}"
echo -e "PID\t\tUSER\t\t文件路径"
echo "------------------------------------------------------------"
head -10 "${file_list_tmp}" | while read -r tmp_file; do
    [ -z "${tmp_file}" ] || [ ! -f "${tmp_file}" ] && continue
    
    # 明细提取PID/USER（和核心逻辑一致）
    pid=$(fuser "${tmp_file}" 2>/dev/null | awk '{print $1}' | tr -d ' ' || echo "无")
    if [[ "${pid}" = "无" || ! "${pid}" =~ ^[0-9]+$ ]]; then
        user="无"
    else
        user=$(ps -p "${pid}" -o user= 2>/dev/null | tr -d ' ')
        user=${user:-$(ls -l "${tmp_file}" | awk '{print $3}')}
        user=${user:-kingbase}
    fi
    echo -e "${YELLOW}${pid}\t\t${user}\t\t${tmp_file}${NC}"
done

# ===================== 按PID去重统计（核心需求） =====================
echo -e "\n${BLUE}===== 按PID统计（去重汇总） =====${NC}"
echo -e "PID\t\tUSER\t\t使用文件数"
echo "------------------------------------------------------------"

# 输出有PID的统计结果
if [ ${#pid_file_count[@]} -gt 0 ]; then
    for pid in "${!pid_file_count[@]}"; do
        echo -e "${GREEN}${pid}\t\t${pid_user["${pid}"]}\t\t${pid_file_count["${pid}"]}${NC}"
    done
else
    echo -e "${YELLOW}（无活跃进程关联的PID）${NC}"
fi

# 输出无关联PID的统计（合并去重）
echo -e "${YELLOW}无关联PID\t无\t\t${no_pid_files}${NC}"

# ===================== 最终汇总 =====================
echo -e "\n${GREEN}===== 检索完成 =====${NC}"
echo -e "📊 最终统计汇总："
echo -e "  - 冻结文件总数（遍历前）：${total_files}"
echo -e "  - 实际处理文件数（未被删除）：${total_files_real}"
echo -e "  - 去重后PID总数（含无关联）：$(( ${#pid_file_count[@]} + 1 ))"
echo -e "  - 有PID关联文件数：$(( total_files_real - no_pid_files ))"
echo -e "  - 无PID关联文件数：${no_pid_files}"

# ===================== 清理临时文件 =====================
rm -f "${file_list_tmp}"