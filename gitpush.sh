#!/bin/bash

find . -name '.DS_Store' -o -name '._*' | grep -v '.git' | xargs rm -rf 2>/dev/null
git add *
git commit -m "`/Users/sunpeng/raysuen/bin/rdate.py -f "%Y%m%d"`"
git push -u origin "master"
