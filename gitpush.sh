#!/bin/bash

git add *
git commit -m "`rdate.py -f "%Y%m%d"`"
git push -u origin master
