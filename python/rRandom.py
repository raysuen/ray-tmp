#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# @Time : 2025年2月20日 14:19:53
# @Author : raysuen
# @version 1.0

import secrets
import string
import re

LENGTH=14


chars = string.ascii_letters + string.digits + "!@#%^&+<>()"
# password = ''.join(secrets.choice(chars) for _ in range(12))
# print(password)
# print(''.join(secrets.choice(chars) for _ in range(14)))
 
# def check_string(s):
#     # 定义正则规则 
#     pattern = (
#         r'^[A-Za-z0-9]'      # 首字符为字母或数字 
#         r'(?=.*[A-Z])'       # 至少一个大写字母 
#         r'(?=.*[a-z])'       # 至少一个小写字母 
#         r'(?=.*\d)'          # 至少一个数字 
#         r'(?=.*[^A-Za-z0-9])' # 至少一个特殊字符（非字母数字）
#         r'.+$'               # 匹配整个字符串 
#     )
#     return re.match(pattern,  s) is not None 

def check_string(s):
    # 定义正则规则
    pattern = (
        r'^[A-Za-z0-9]'      # 首字符为字母或数字
        r'(?=.*[A-Z])'       # 至少一个大写字母
        r'(?=.*[a-z])'       # 至少一个小写字母
        r'(?=(.*\d){2,})'    # 至少两个数字（修改处）
        r'(?=.*[^A-Za-z0-9])' # 至少一个特殊字符
        r'.{7,}$'            # 总长度至少8个字符（首字符+7）
    )
    return re.fullmatch(pattern, s) is not None



while True:
    tmp_str= ''.join(secrets.choice(chars) for _ in range(LENGTH))
    if check_string(tmp_str):
        print(tmp_str)
        break