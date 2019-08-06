#!/usr/bin/env python
# _*_coding:utf-8_*_
# Auth by raysuen


import os

for line in os.listdir('/private/tmp/'):
    if line.find("com.apple.launchd") != -1:
        # print(line)
        for line2 in os.listdir("""/private/tmp/%s"""%line):
            if line2.find("xquartz") != -1:
                print("""export DISPLAY=/private/tmp/%s/%s"""%(line,line2))