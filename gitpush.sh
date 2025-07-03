#!/bin/bash

git add *
git commit -m "`/Users/sunpeng/raysuen/bin/rdate.py -f "%Y%m%d"`"
git push -u origin "master"
