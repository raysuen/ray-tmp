#!/bin/bash

# 1. 删除冗余的.DS_Store/._*文件（排除.git目录）
find . \( -name '.DS_Store' -o -name '._*' \) -not -path '*/.git/*' -delete

# 2. 暂存所有修改（包括隐藏文件，替换git add *）
git add .

# 3. 提交本地变更（无变更时脚本不中断）
git commit -m "`/Users/sunpeng/raysuen/bin/rdate.py -f "%Y%m%d"`" || {
    echo "⚠️  无需要提交的本地变更，跳过commit步骤"
}

# 4. 临时暂存未提交的修改（避免rebase时因未暂存变更报错）
git stash push -m "temp_stash_before_pull" 2>/dev/null || true

# 5. 拉取远程master并变基（显式指定策略）
echo "🔄 拉取远程最新代码并执行rebase..."
git pull --rebase origin master

# 6. 检查rebase是否成功（若失败则提示手动解决）
if [ $? -ne 0 ]; then
    echo -e "\n❌ 拉取过程中出现冲突，请先手动解决："
    echo "   1. 编辑冲突文件（删除<<<<<<< / ======= / >>>>>>>标记）"
    echo "   2. 执行：git add <冲突文件名>"
    echo "   3. 执行：git rebase --continue"
    echo "   4. 执行：bash gitpush.sh 重新推送"
    # 恢复stash的修改（若有）
    git stash pop 2>/dev/null || true
    exit 1  # 脚本退出，避免继续执行push
fi

# 7. 恢复临时暂存的修改
git stash pop 2>/dev/null || true

# 8. 推送本地master到远程
echo "🚀 推送代码到远程仓库..."
git push -u origin master

# 9. 推送结果提示
if [ $? -eq 0 ]; then
    echo "✅ 代码推送成功！"
else
    echo "❌ 推送失败，请检查是否还有未解决的冲突或网络问题"
fi
