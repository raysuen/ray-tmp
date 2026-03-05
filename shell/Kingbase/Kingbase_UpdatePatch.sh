#!/bin/bash
#by raysuen
# 脚本用途：Kingbase数据库备份+补丁升级（选项参数版）
# 版本：v1.2
# 日期：2026-03-05

# ====================== 1. 初始化默认变量 ======================
# 默认search_path（用户不指定-s则用此值）
search_path="/home/kingbase"
# 补丁包默认为空（用户不指定-p则不解压补丁）
patch_package=""

# ====================== 2. 帮助函数定义 ======================
function print_help() {
    echo "==================================== Kingbase备份&补丁升级脚本 ===================================="
    echo "用途：停止状态下的Kingbase数据库全量备份 + 可选补丁包解压升级"
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
    echo "  2. 使用默认search_path仅备份"
    echo "     $0"
    echo "  3. 自定义search_path仅备份"
    echo "     $0 -s /opt/Kingbase/ES/V8"
    echo "  4. 默认search_path + 解压补丁包"
    echo "     $0 -p /tmp/kingbase_v8r6_patch.tar.gz"
    echo "  5. 自定义search_path + 解压补丁包"
    echo "     $0 -s /opt/Kingbase/ES/V8 -p /tmp/kingbase_v8r6_patch.tar.gz"
    echo "=================================================================================================="
}

# ====================== 3. 解析命令行选项参数 ======================
# 用getopts解析-s/-p/-h选项（:表示选项需要参数）
while getopts "s:p:h" opt; do
    case $opt in
        s)
            # 用户指定-s，覆盖默认search_path
            search_path="$OPTARG"
            ;;
        p)
            # 用户指定-p，设置补丁包路径
            patch_package="$OPTARG"
            ;;
        h)
            # 打印帮助并退出
            print_help
            exit 0
            ;;
        \?)
            # 无效选项
            echo "错误：无效的选项 -$OPTARG！"
            print_help
            exit 1
            ;;
        :)
            # 选项缺少参数（如只写-s不跟路径）
            echo "错误：选项 -$OPTARG 需要传入参数！"
            print_help
            exit 1
            ;;
    esac
done

# ====================== 4. 校验search_path（默认/用户指定） ======================
# 校验search_path是否为存在的目录
if [ ! -d "${search_path}" ]; then
    echo "错误：search_path【${search_path}】不是有效目录（不存在）！"
    print_help
    exit 1
fi

# 校验当前用户对search_path的读权限
if [ ! -r "${search_path}" ]; then
    echo "错误：当前用户对search_path【${search_path}】无读取权限！"
    exit 1
fi
echo "✅ search_path校验通过：${search_path}"

# ====================== 5. 校验patch_package（若指定-p） ======================
if [ -n "${patch_package}" ]; then
    # 5.1 校验补丁包是否存在
    if [ ! -f "${patch_package}" ]; then
        echo "错误：补丁包【${patch_package}】不存在！"
        exit 1
    fi

    # 5.2 校验补丁包读权限
    if [ ! -r "${patch_package}" ]; then
        echo "错误：当前用户对补丁包【${patch_package}】无读取权限！"
        exit 1
    fi

    # 5.3 校验是否为有效tar包
    if ! tar -tf "${patch_package}" >/dev/null 2>&1; then
        echo "错误：补丁包【${patch_package}】不是有效tar格式包！"
        exit 1
    fi

    # 5.4 提前定位解压目录，校验写权限
    sys_ctl_path=$(find "${search_path}" -iname "sys_ctl" 2>/dev/null | grep -Ev "kbbr_repo|archive" | head -1)
    if [ -z "${sys_ctl_path}" ]; then
        echo "错误：在【${search_path}】下未找到sys_ctl工具，无法确定解压目录！"
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
    echo "错误：kingbase数据库正在运行，请先停止数据库后再执行脚本！"
    exit 1
fi
echo "✅ Kingbase进程检查通过：数据库已停止"

# ====================== 7. 定位Kingbase安装目录 ======================
sys_ctl_path=$(find "${search_path}" -iname "sys_ctl" 2>/dev/null | grep -Ev "kbbr_repo|archive" | head -1)
if [ -z "${sys_ctl_path}" ]; then
    echo "错误：在【${search_path}】下未找到sys_ctl工具，请检查路径！"
    exit 1
fi
kingbase_back=$(dirname $(dirname ${sys_ctl_path}))
echo "✅ 已定位Kingbase安装目录：${kingbase_back}"

# ====================== 8. 备份打包 ======================
cd ${kingbase_back} || { echo "错误：无法进入目录${kingbase_back}"; exit 1; }

# 获取版本号
kingbase_version=$(/bin/bash -c "./bin/kingbase -V" | awk '{print $NF}' | sed 's/[^0-9a-zA-Z\.]//g')
if [ -z "${kingbase_version}" ]; then
    echo "错误：无法获取Kingbase版本号！"
    exit 1
fi

# 打包（排除自身zip包）
zip -r "db_${kingbase_version}.zip" * -x "db_${kingbase_version}.zip"
if [ ! -f "db_${kingbase_version}.zip" ]; then
    echo "错误：备份包db_${kingbase_version}.zip生成失败！"
    exit 1
fi
echo "✅ 备份包生成成功：${kingbase_back}/db_${kingbase_version}.zip"

# ====================== 9. 补丁解压（若指定-p） ======================
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