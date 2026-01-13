#!/bin/bash

find . \( -name '.DS_Store' -o -name '._*' \) -not -path '*/.git/*' -delete
git add .
git commit -m "`/Users/sunpeng/raysuen/bin/rdate.py -f "%Y%m%d"`"
git push -u origin "master"
