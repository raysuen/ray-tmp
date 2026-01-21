#!/bin/bash

# 删除.DS_Store/._*文件（排除.git目录，避免误删仓库配置）
find . \( -name '.DS_Store' -o -name '._*' \) -not -path '*/.git/*' -delete
# 暂存所有修改文件
git add *
# 提交（备注为当日日期）
git commit -m "`/Users/sunpeng/raysuen/bin/rdate.py -f "%Y%m%d"`"
# 拉取远程master最新代码（关键：同步远程变更）
git pull origin master
# 推送本地master到远程
git push -u origin "master"
