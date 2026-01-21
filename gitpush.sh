#!/bin/bash

# 步骤1：删除冗余的.DS_Store/._*文件（排除.git目录）
find . \( -name '.DS_Store' -o -name '._*' \) -not -path '*/.git/*' -delete

# 步骤2：暂存所有修改（包括刚删除冗余文件后的变更）
git add .  # 替换git add *，避免漏检隐藏文件/目录

# 步骤3：提交本地变更（备注为当日日期）
git commit -m "`/Users/sunpeng/raysuen/bin/rdate.py -f "%Y%m%d"`" || true  
# 加|| true：若没有可提交的变更（比如仅删除冗余文件无代码改动），脚本不中断

# 步骤4：临时暂存工作区未提交的修改（解决"unstaged changes"报错）
git stash push -m "temp_stash_before_pull" 2>/dev/null || true  

# 步骤5：拉取远程master并变基（显式指定策略，解决分支分歧）
git pull --rebase origin master

# 步骤6：恢复临时暂存的修改
git stash pop 2>/dev/null || true  

# 步骤7：推送本地master到远程
git push -u origin master
