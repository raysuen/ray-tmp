#!/bin/bash

set -euo pipefail  # 严格模式：命令失败立即退出

# 标记是否有stash内容
has_stashed=0

# ===================== 第一步：先清理无用文件（避免暂存这些文件） =====================
echo "🧹 提前清理.DS_Store/._*文件（排除.git目录）..."
find . \( -name '.DS_Store' -o -name '._*' \) -not -path '*/.git/*' -delete 2>/dev/null
echo "✅ 无用文件提前清理完成。"

git checkout master
# ===================== 增强版：检测所有未处理的修改（含未追踪文件） =====================
echo "🔍 检测本地所有未提交/未追踪的修改..."
# 检查是否有：已追踪文件的修改（暂存/未暂存） + 未追踪的新文件
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "ℹ️  检测到本地有未处理的修改/未追踪文件，开始暂存（包含未追踪文件）..."
    # -u：stash包含未追踪文件；-a：还包含被忽略的文件（可选，根据需求）
    git stash push -u -m "auto-stash-$(date +%Y%m%d%H%M%S)"
    has_stashed=1
    echo "✅ 本地所有修改（含未追踪文件）已暂存。"
else
    echo "✅ 本地无未处理的修改，无需暂存。"
fi

# ===================== 拉取远程代码（失败则恢复stash并退出） =====================
echo "🔄 拉取远程master分支最新内容..."
if ! git pull --rebase origin master; then
    echo "❌ 拉取远程代码失败！请检查冲突/网络/权限后重试。"
    # 恢复stash（若有）
    if [ $has_stashed -eq 1 ]; then
        echo "🔙 恢复之前暂存的本地修改..."
        git stash pop || echo "⚠️  暂存内容无匹配项，可忽略。"
    fi
    exit 1
fi
echo "✅ 远程代码拉取完成。"

# ===================== 恢复暂存的修改（含未追踪文件，优化冲突处理） =====================
if [ $has_stashed -eq 1 ]; then
    echo "🔙 恢复本地暂存的修改（含未追踪文件）..."
    # 先尝试普通pop，若失败则强制恢复（覆盖已存在的未追踪文件）
    if ! git stash pop; then
        echo "⚠️  常规恢复失败，尝试强制恢复（覆盖重复的未追踪文件）..."
        # 手动应用stash的修改，忽略未追踪文件的重复
        git stash apply --index || {
            echo "❌ 强制恢复也失败！请手动执行 git stash apply 解决冲突，再删除stash（git stash drop）"
            exit 1
        }
        # 恢复后删除该stash（避免残留）
        git stash drop
        echo "✅ 本地修改已强制恢复（覆盖重复文件）。"
    else
        echo "✅ 本地修改已恢复。"
    fi
fi

# ===================== 提交推送 =====================
echo "📤 提交并推送本地内容..."
git add .  # 添加所有修改（含隐藏文件，忽略.gitignore）
# 无修改则跳过commit
git commit -m "$(/Users/sunpeng/raysuen/bin/rdate.py -f "%Y%m%d")" || {
    echo "ℹ️  无需要提交的修改，跳过commit。"
}
git push -u origin master
echo "✅ 内容已推送到远程master分支！"

echo "🎉 同步流程完成！"

