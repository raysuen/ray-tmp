#!/bin/bash
#by raysuen
# 脚本用途：Kingbase数据库备份+补丁升级（选项参数版，打包排除自身和archive目录）
# 版本：v1.3
# 日期：2026-03-05

# ====================== 1. 初始化默认变量 ======================
search_path="/home/kingbase"  # 默认search_path
patch_package=""              # 补丁包默认为空

# ====================== 2. 帮助函数定义 ======================
function print_help() {
    echo "==================================== Kingbase备份&补丁升级脚本 ===================================="
    echo "用途：停止状态下的Kingbase数据库全量备份（排除archive目录） + 可选补丁包解压升级"
    echo "使用格式：$0 [选项]"
    echo ""
    echo "选项说明："
    echo "  -h/--help          打印此帮助信息并退出"
    echo "  -s <path>          指定Kingbase查找根目录（可选，默认：/home/kingbase）"
    echo "  -p <package>       指定补丁包完整路径（可选，支持.tar/.tar.gz/.bz2等tar格式）"
    echo ""
    echo "使用示例："
    echo "  1. 打印帮助信息"
    echo "     $0 -h"
    echo "  2. 使用默认search_path仅备份（排除archive）"
    echo "     $0"
    echo "  3. 自定义search_path + 解压补丁包"
    echo "     $0 -s /opt/Kingbase/ES/V8 -p /tmp/kingbase_v8r6_patch.tar.gz"
    echo "=================================================================================================="
}

# ====================== 3. 解析命令行选项参数 ======================
while getopts "s:p:h" opt; do
    case $opt in
        s)
            search_path="$OPTARG"
            ;;
        p)
            patch_package="$OPTARG"
            ;;
        h)
            print_help
            exit 0
            ;;
        \?)
            echo "错误：无效的选项 -$OPTARG！"
            print_help
            exit 1
            ;;
        :)
            echo "错误：选项 -$OPTARG 需要传入参数！"
            print_help
            exit 1
            ;;
    esac
done

# ====================== 4. 校验search_path ======================
if [ ! -d "${search_path}" ]; then
    echo "错误：search_path【${search_path}】不是有效目录！"
    print_help
    exit 1
fi
if [ ! -r "${search_path}" ]; then
    echo "错误：当前用户对search_path【${search_path}】无读取权限！"
    exit 1
fi
echo "✅ search_path校验通过：${search_path}"

# ====================== 5. 校验patch_package（若指定） ======================
if [ -n "${patch_package}" ]; then
    if [ ! -f "${patch_package}" ]; then
        echo "错误：补丁包【${patch_package}】不存在！"
        exit 1
    fi
    if [ ! -r "${patch_package}" ]; then
        echo "错误：当前用户对补丁包【${patch_package}】无读取权限！"
        exit 1
    fi
    if ! tar -tf "${patch_package}" >/dev/null 2>&1; then
        echo "错误：补丁包【${patch_package}】不是有效tar格式包！"
        exit 1
    fi
    # 提前定位解压目录并校验写权限
    sys_ctl_path=$(find "${search_path}" -iname "sys_ctl" 2>/dev/null | grep -Ev "kbbr_repo|archive" | head -1)
    if [ -z "${sys_ctl_path}" ]; then
        echo "错误：在【${search_path}】下未找到sys_ctl工具！"
        exit 1
    fi
    kingbase_back=$(dirname $(dirname ${sys_ctl_path}))
    if [ ! -w "${kingbase_back}" ]; then
        echo "错误：当前用户对解压目录【${kingbase_back}】无写入权限！"
        exit 1
    fi
    echo "✅ 补丁包校验通过：${patch_package}"
fi

# ====================== 6. 数据库进程检查 ======================
isrunning=$(ps -ef | grep "bin/kingbase" 2>/dev/null | egrep -v "grep|$$" | wc -l)
if [ $isrunning -ge 1 ]; then
    echo "错误：kingbase数据库正在运行，请先停止！"
    exit 1
fi
echo "✅ Kingbase进程检查通过：已停止"

# ====================== 7. 定位Kingbase安装目录 ======================
sys_ctl_path=$(find "${search_path}" -iname "sys_ctl" 2>/dev/null | grep -Ev "kbbr_repo|archive" | head -1)
if [ -z "${sys_ctl_path}" ]; then
    echo "错误：在【${search_path}】下未找到sys_ctl工具！"
    exit 1
fi
kingbase_back=$(dirname $(dirname ${sys_ctl_path}))
echo "✅ 已定位Kingbase安装目录：${kingbase_back}"

# ====================== 8. 打包（核心修改：排除自身和archive目录） ======================
cd ${kingbase_back} || { echo "错误：无法进入目录${kingbase_back}"; exit 1; }

# 获取版本号
kingbase_version=$(/bin/bash -c "./bin/kingbase -V" | awk '{print $NF}' | sed 's/[^0-9a-zA-Z\.]//g')
if [ -z "${kingbase_version}" ]; then
    echo "错误：无法获取Kingbase版本号！"
    exit 1
fi

# 打包命令：排除自身zip包 + 所有archive目录
backup_zip="db_${kingbase_version}.zip"
zip -r "${backup_zip}" * -x "${backup_zip}" "archive/" "*/archive/*"

# 校验打包结果
if [ ! -f "${backup_zip}" ]; then
    echo "错误：备份包【${backup_zip}】生成失败！"
    exit 1
fi
echo "✅ 备份包生成成功（已排除自身和archive目录）：${kingbase_back}/${backup_zip}"

# ====================== 9. 补丁解压（若指定） ======================
if [ -n "${patch_package}" ]; then
    echo "📦 开始解压补丁包：${patch_package}"
    tar -xvf "${patch_package}" -C ${kingbase_back} --overwrite
    echo "✅ 补丁包解压完成！"
fi

# ====================== 10. 版本验证 ======================
echo "🔍 当前Kingbase版本信息："
./bin/kingbase -V

echo "==================================== 脚本执行完成 ==================================="
exit 0