#!/bin/env python3
# _*_coding:utf-8_*_
# Auth by raysuen
#important: run "pip install pycryptodomex" to install pycryptodomex model



from Cryptodome.Cipher import AES
from binascii import b2a_hex, a2b_hex
import sys,re

AES_LENGTH = 16

class prpcrypt():

    def __init__(self, key):
        self.key = key
        self.mode = AES.MODE_ECB
        self.cryptor = AES.new(self.pad_key(self.key).encode(), self.mode)

    # 加密函数，如果text不是16的倍数【加密文本text必须为16的倍数！】，那就补足为16的倍数
    # 加密内容需要长达16位字符，所以进行空格拼接
    def pad(self,text):
        while len(text) % AES_LENGTH != 0:
            text += ' '
        return text

    # 加密密钥需要长达16位字符，所以进行空格拼接
    def pad_key(self,key):
        while len(key) % AES_LENGTH != 0:
            key += ' '
        return key

    def encrypt(self, text):

        # 这里密钥key 长度必须为16（AES-128）、24（AES-192）、或32（AES-256）Bytes 长度.目前AES-128足够用
        # 加密的字符需要转换为bytes
        # print(self.pad(text))
        self.ciphertext = self.cryptor.encrypt(self.pad(text).encode())
        # 因为AES加密时候得到的字符串不一定是ascii字符集的，输出到终端或者保存时候可能存在问题
        # 所以这里统一把加密后的字符串转化为16进制字符串
        return b2a_hex(self.ciphertext)

        # 解密后，去掉补足的空格用strip() 去掉

    def decrypt(self, text):
        plain_text = self.cryptor.decrypt(a2b_hex(text)).decode()
        return plain_text.rstrip(' ')


def func_help():
    pass

if __name__ == '__main__':
    rkey = None
    rstring = None
    encry = 0
    decry = 0
    if len(sys.argv) > 1:
        i = 1
        while i < len(sys.argv):
            if sys.argv[i] == "-h":
                func_help()
                exit(0)
            elif sys.argv[i] == "-k":
                i = i + 1
                if i >= len(sys.argv):   #表示-k后面没有跟随-k的值
                    print("The value of -k must be specified!!!")
                    exit(1)
                elif re.match("^-", sys.argv[i]) != None:  # 判断-k的值，如果-k的下个参数以-开头，表示没有指定-f值
                    print("The value of -k must be specified!!!")
                    exit(1)
                rkey = sys.argv[i]
            elif sys.argv[i] == "-s":
                i = i + 1
                if i >= len(sys.argv):   #表示-k后面没有跟随-k的值
                    print("The value of -s must be specified!!!")
                    exit(2)
                elif re.match("^-", sys.argv[i]) != None:  # 判断-k的值，如果-k的下个参数以-开头，表示没有指定-f值
                    print("The value of -s must be specified!!!")
                    exit(2)
                rstring = sys.argv[i]
            elif sys.argv[i] == "-e":
                encry = 1
            elif sys.argv[i] == "-d":
                decry = 1
            i = i + 1
        if  rkey == None or rstring == None:
            print("Pleas give values for -k or -s.")
            exit(3)
        elif len(rkey) > 0 and len(rstring) > 0:
            pc = prpcrypt(rkey)  # 初始化密钥
            if encry == 1:
                print(pc.encrypt(rstring))

            elif decry == 1:
                print(pc.decrypt(rstring))
            else:
                print("You must use -d or -e.")
                exit(4)
            exit(0)
        else:
            print("Pleas give values for -k or -s.")
            exit(5)
    else:
        print("You can use -h to get help.")
        exit(0)


