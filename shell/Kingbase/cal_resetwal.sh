#!/bin/bash
#by raysuen
#V2.0

set -euo pipefail

========================= 风险提示函数 =========================
show_risk_warning() {
    echo "============================================================="
    echo "🚨 严重警告："
    echo "1. 此操作会导致数据丢失，仅用于控制文件损坏且无备份的测试场景！"
    echo "2. 生产环境请立即联系金仓技术支持，禁止执行此脚本！"
    echo "3. 执行前必须备份整个数据目录：cp -r 数据目录 备份目录"
    echo "============================================================="
    read -p "确认在测试环境执行？(y/N)：" CONFIRM
    if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
        echo "❌ 脚本终止执行"
        exit 0
    fi
}

# ========================= 前置校验函数 =========================
validate_preconditions() {
    local data_dir="$1"
    
    # 校验数据目录存在
    if [ ! -d "${data_dir}" ]; then
        echo "❌ 错误：数据目录${data_dir}不存在" >&2
        exit 1
    fi

    # 校验数据库已停止
    if pgrep -f "kingbase -D ${data_dir}" &> /dev/null; then
        echo "❌ 错误：数据库未停止，请执行：sys_ctl stop -D ${data_dir}" >&2
        exit 1
    fi

    # 校验关键目录存在
    local key_dirs=("sys_wal" "sys_xact" "sys_multixact/offsets" "sys_multixact/members")
    for dir in "${key_dirs[@]}"; do
        local full_dir="${data_dir}/${dir}"
        if [ ! -d "${full_dir}" ]; then
            echo "❌ 错误：必要目录${full_dir}不存在" >&2
            exit 1
        fi
    done
}

# ========================= 参数计算函数 =========================
# 1. 计算next-wal-file参数
calculate_next_wal() {
    local wal_dir="$1"
    echo "1. 计算next-wal-file参数..." >&2
    
    local last_wal=$(ls -1 "${wal_dir}" | grep -E "^[0-9A-Fa-f]{24}$" | sort | tail -n 1)
    [ -z "${last_wal}" ] && { echo "❌ 错误：未找到有效WAL文件" >&2; exit 1; }

    local wal_prefix=${last_wal:0:16}
    local wal_segment=${last_wal:16:8}
    local segment_dec=$((16#${wal_segment} + 1))
    local new_segment=$(printf "%08X" ${segment_dec})
    echo "${wal_prefix}${new_segment}"
}

# 2. 计算next-transaction-id参数
calculate_next_xid() {
    local xact_dir="$1"
    echo -e "\n2. 计算next-transaction-id参数..." >&2
    
    local max_xact_file=$(ls -1 "${xact_dir}" | grep -E "^[0-9A-Fa-f]{4}$" | sort | tail -n 1)
    [ -z "${max_xact_file}" ] && max_xact_file="0000"

    local max_xact_dec=$((16#${max_xact_file} + 1))
    local next_xid=$((max_xact_dec * 1048576))
    printf "0x%09X" ${next_xid}
}

# 3. 计算multixact-ids参数
calculate_multixact_ids() {
    local offsets_dir="$1"
    echo -e "\n3. 计算multixact-ids参数..." >&2
    
    local max_multi_file=$(ls -1 "${offsets_dir}" | grep -E "^[0-9A-Fa-f]{4}$" | sort | tail -n 1)
    local min_multi_file=$(ls -1 "${offsets_dir}" | grep -E "^[0-9A-Fa-f]{4}$" | sort | head -n 1)
    [ -z "${max_multi_file}" ] && max_multi_file="0000"
    [ -z "${min_multi_file}" ] && min_multi_file="0000"

    local mxid1_dec=$(( (16#${max_multi_file} + 1) * 65536 ))
    local mxid1_hex=$(printf "0x%08X" ${mxid1_dec})
    local mxid2_dec=$((16#${min_multi_file} * 65536))
    mxid2_dec=$(( mxid2_dec == 0 ? 1 : mxid2_dec ))
    local mxid2_hex=$(printf "0x%08X" ${mxid2_dec})
    echo "${mxid1_hex},${mxid2_hex}"
}

# 4. 计算multixact-offset参数
calculate_multixact_offset() {
    local members_dir="$1"
    echo -e "\n4. 计算multixact-offset参数..." >&2
    
    local max_member_file=$(ls -1 "${members_dir}" | grep -E "^[0-9A-Fa-f]{4}$" | sort | tail -n 1)
    [ -z "${max_member_file}" ] && max_member_file="0000"

    local max_member_dec=$((16#${max_member_file} + 1))
    local multi_offset=$((max_member_dec * 52352))
    printf "0x%05X" ${multi_offset}
}

# ========================= 单行命令生成函数 =========================
generate_single_line_cmd() {
    local data_dir="$1"
    local next_wal="$2"
    local next_xid="$3"
    local multixact_ids="$4"
    local multi_offset="$5"

    # 生成单行紧凑命令
    local resetwal_cmd="sys_resetwal -l ${next_wal} -x ${next_xid} -m ${multixact_ids} -O ${multi_offset} -D ${data_dir}"

    # 输出结果
    echo -e "\n============================================================="
    echo "✅ 参数计算完成，完整sys_resetwal命令（可直接复制执行）："
    echo -e "\n${resetwal_cmd}"
    echo -e "\n🚨 执行提示："
    echo "1. 确认参数无误后，添加 -f 参数强制执行：${resetwal_cmd} -f"
    echo "2. 执行后启动数据库，务必检查数据完整性！"
    echo "============================================================="
}

# ========================= 主函数 =========================
main() {
    if [ $# -ne 1 ]; then
        echo "用法：$0 <金仓数据库数据目录绝对路径>"
        echo "示例：$0 /home/kingbase/data" >&2
        exit 1
    fi
    local data_dir="$1"

    # 执行流程
    show_risk_warning
    validate_preconditions "${data_dir}"
    local next_wal=$(calculate_next_wal "${data_dir}/sys_wal")
    local next_xid=$(calculate_next_xid "${data_dir}/sys_xact")
    local multixact_ids=$(calculate_multixact_ids "${data_dir}/sys_multixact/offsets")
    local multi_offset=$(calculate_multixact_offset "${data_dir}/sys_multixact/members")
    generate_single_line_cmd "${data_dir}" "${next_wal}" "${next_xid}" "${multixact_ids}" "${multi_offset}"
}

# 启动主函数
main "$@"