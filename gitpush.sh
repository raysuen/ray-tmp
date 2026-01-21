#!/bin/bash

# 删除.DS_Store/._*文件（排除.git目录）
find . \( -name '.DS_Store' -o -name '._*' \) -not -path '*/.git/*' -delete
# 暂存所有修改文件
git add *
# 提交（备注为当日日期）
git commit -m "`/Users/sunpeng/raysuen/bin/rdate.py -f "%Y%m%d"`"
# 拉取远程master并变基（解决分支分歧，推荐）
git pull --rebase origin master
# 推送本地master到远程
git push -u origin "master"
