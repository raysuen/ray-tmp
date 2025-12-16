#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# @Time :  2025年5月14日
# @Author : raysuen
# @version 1.0

import socket
import sys

def check_port(host, port, timeout=10):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (socket.timeout, ConnectionRefusedError):
        return False

def is_valid_ip(ip_str):
    try:
        # 尝试解析为 IPv4
        socket.inet_pton(socket.AF_INET, ip_str)
        return True
    except socket.error:
        try:
            # 尝试解析为 IPv6
            socket.inet_pton(socket.AF_INET6, ip_str)
            return True
        except socket.error:
            return False

def print_info(host,port=22):
    if check_port(host,port):
        print("✅ 端口开放")
    else:
        print("❌ 端口关闭")

def func_help():
    print("Example: rTelnet IP port")
    
# # 示例


if __name__ == '__main__':
    try:
        host = None
        port = None
        if len(sys.argv) > 1:
            i = 1
            while i < len(sys.argv):
                if sys.argv[i] == "-h":
                    func_help()
                    exit(0)
                elif i == 1 and is_valid_ip(sys.argv[i]):
                    host = sys.argv[i]
                elif i == 2:
                    try:
                        port = int(sys.argv[i])
                    except Exception as e:
                        print("Port must be integer!")
                        exit(1)
                i = i + 1
        
        else:
            print("You can use -h to get help.")
            exit(0)
            
        if host == None:
            print("You must enter a right IP.")
            exit(1)
        
        if port == None:
            print_info(host)
        else:
            print_info(host,port)
    except KeyboardInterrupt:
        exit(10)
    