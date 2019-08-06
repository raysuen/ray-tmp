#!/usr/bin/env python
# _*_coding:utf-8_*_
# Auth by raysuen
#v01

import ftplib,socket
import re,sys,os

HostDict={
    "Host":None,
    "User":None,
    "Passwd":None,
    "Action":None,
    "RemotePath":None,
    "LocalPath":None
}

def FtpConnect(host, username, passwd):
    try:
        ftp = ftplib.FTP(host)
    except (socket.error, socket.gaierror) as e:
        print('Error, cannot reach ' + host)
        return
    else:
        print('Connect To Host Success...')

    try:
        ftp.login(username, passwd)
    except ftplib.error_perm:
        print('Username or Passwd Error')
        ftp.quit()
        return
    else:
        print('Login Success...')
    return ftp


def CheckFileExist(localpath):
    if os.path.exists(localpath) == False:
        print("No such file or directory:%s"%localpath)
        exit(30)

def FtpDownload(ftp, remotepath, localpath):

	try:
		ftp.retrbinary('RETR %s' %remotepath, open(localpath, 'wb').write)
	except ftplib.error_perm:
		print('File Error')
		os.unlink(localpath)
	else:
		print('Download Success...')
	ftp.quit()


def FtpUpload(ftp, localpath, remotepath):
    CheckFileExist(localpath)
    try:
        ftp.storbinary('STOR %s' % remotepath, open(localpath, 'rb'))
    except ftplib.error_perm as e:
        print(e)
        print('File Error')
        # os.unlink(localpath)
    else:
        print('Upload Success...')
    ftp.quit()


def check_ip(ipAddr):
  compile_ip=re.compile('^(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|[1-9])\.(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|\d)\.(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|\d)\.(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|\d)$')
  if compile_ip.match(ipAddr):
    return True
  else:
    return False


def help_func():
    print("""
        NAME:
            r  --display date and time
        SYNOPSIS:
            rdate [-f] [time format] [-c] [colculation format] [-d] [input_time] [input_time_format]
        DESCRIPTION:
    """)

def GetParameters():
    num = 1
    exitnum = 0
    # 获取参数
    if len(sys.argv) > 1:  # 判断是否有参数输入
        while num < len(sys.argv):
            if sys.argv[num] == "-h":
                help_func()  # 执行帮助函数
                exitnum = 0
                exit(exitnum)
            elif sys.argv[num] == "-d":  #指定ping命令的IP
                num += 1  # 下标向右移动一位
                if num >= len(sys.argv):  # 判断是否存在当前下标的参数
                    exitnum = 90
                    print("The parameter must be specified a value,-d.")
                    exit(exitnum)
                elif re.match("^-", sys.argv[num]) == None:  # 判断当前参数是否为-开头，None为非-开头
                    if check_ip(sys.argv[num]) == True:
                        HostDict["Host"] = sys.argv[num]
                        num += 1
                    else:
                        print("Please specify a valid value for -d.")
                        exitnum = 89
                        exit(exitnum)
                else:
                    print("Please specify a valid value for -d.")
                    exitnum = 88
                    exit(exitnum)
            elif sys.argv[num] == "-u":  #指定登录远端的用户名
                num += 1  # 下标向右移动一位
                if num >= len(sys.argv):  # 判断是否存在当前下标的参数
                    exitnum = 93
                    print("The parameter must be specified a value,-u.")
                    exit(exitnum)
                elif re.match("^-", sys.argv[num]) == None:  # 判断当前参数是否为-开头，None为非-开头

                    HostDict["User"] = sys.argv[num]
                    num += 1
                else:
                    print("Please specify a valid value for -u.")
                    exitnum = 91
                    exit(exitnum)
            elif sys.argv[num] == "-p":  #指定远端登录的用户的密码
                num += 1  # 下标向右移动一位
                if num >= len(sys.argv):  # 判断是否存在当前下标的参数
                    exitnum = 90
                    print("The parameter must be specified a value,-p.")
                    exit(exitnum)
                elif re.match("^-", sys.argv[num]) == None:  # 判断当前参数是否为-开头，None为非-开头

                    HostDict["Passwd"] = sys.argv[num]
                    num += 1
                else:
                    print("Please specify a valid value for -p.")
                    exitnum = 88
                    exit(exitnum)
            elif sys.argv[num] == "-a":  #指定远端登录的用户的密码
                num += 1  # 下标向右移动一位
                if num >= len(sys.argv):  # 判断是否存在当前下标的参数
                    exitnum = 79
                    print("The parameter must be specified a value,-a.")
                    exit(exitnum)
                elif re.match("^-", sys.argv[num]) == None:  # 判断当前参数是否为-开头，None为非-开头

                    HostDict["Action"] = sys.argv[num]
                    num += 1
                else:
                    print("Please specify a valid value for -a.")
                    exitnum = 78
                    exit(exitnum)
            elif sys.argv[num] == "-l":  #指定远端登录的用户的密码
                num += 1  # 下标向右移动一位
                if num >= len(sys.argv):  # 判断是否存在当前下标的参数
                    exitnum = 77
                    print("The parameter must be specified a value,-l.")
                    exit(exitnum)
                elif re.match("^-", sys.argv[num]) == None:  # 判断当前参数是否为-开头，None为非-开头

                    HostDict["LocalPath"] = sys.argv[num]
                    num += 1
                else:
                    print("Please specify a valid value for -l.")
                    exitnum = 76
                    exit(exitnum)
            elif sys.argv[num] == "-r":  #指定远端登录的用户的密码
                num += 1  # 下标向右移动一位
                if num >= len(sys.argv):  # 判断是否存在当前下标的参数
                    exitnum = 77
                    print("The parameter must be specified a value,-r.")
                    exit(exitnum)
                elif re.match("^-", sys.argv[num]) == None:  # 判断当前参数是否为-开头，None为非-开头

                    HostDict["RemotePath"] = sys.argv[num]
                    num += 1
                else:
                    print("Please specify a valid value for -r.")
                    exitnum = 76
                    exit(exitnum)




if __name__ == '__main__':
    GetParameters()
    if HostDict["Host"]==None or HostDict["User"]==None or HostDict["Passwd"]==None:
        print("Please enter valid parameters.")
        exit(20)
    ftp = FtpConnect(HostDict["Host"], HostDict["User"], HostDict["Passwd"])
    if HostDict["Action"].lower()=="test":
        ftp.quit()
    elif HostDict["Action"].lower()=="put":
        if HostDict["Action"]==None:
            print("You have to specified a action for -a.")
            exit(51)
        FtpUpload(ftp,HostDict["LocalPath"],HostDict["RemotePath"])
    elif HostDict["Action"].lower()=="get":
        if HostDict["Action"]==None:
            print("You have to specified a action for -a.")
            exit(51)
        FtpDownload(ftp,HostDict["RemotePath"],HostDict["LocalPath"])

    exit(0)