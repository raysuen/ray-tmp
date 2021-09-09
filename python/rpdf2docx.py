#!/usr/bin/env python
# _*_coding:utf-8_*_
# Auth by raysuen



from pdf2docx import Converter
import os,sys,re

def func_help():
    print("""
        NAME:
            rpdf2docx    --convert pdf file to docx file 
            before excution:
                You ensure having install pdf2docx for python.
                if the pdf2docx not install,excuting:
                    pip3 install pdf2docx
        SYNOPSIS:
            pdf2word    [-p] pdf file  [-w docx file]
        DESCRIPTION:
            -p      specify a path for pdf file.Also not spceify -p.By default,the first parameter is pdf file.
            -w      specify a output doc file path.You can also not use the -w to specify path.
                    You can use the path and name of the PDF file instead of specifying the output path.   
        EXSAMPLE:
            python3 rpdf2docx -p /path/test.pdf -w /path/test-docx.docx
            python3 rpdf2docx -p /path/test.pdf
            python3 rpdf2docx  /path/test.pdf /path/test-docx.docx
            python3 rpdf2docx /path/test.pdf
        """)

def WordFileExist(wordfile):
    if os.path.isfile(wordfile):
        while True:
            print("%s is exist."%wordfile)
            try:
                existAction = input("You can enter Y to repalce file. and enter N to exit converting. [Y/N] :")
                if len(existAction) >= 2:
                    print("please enter Y or N.")
                    continue
                elif existAction.upper() == "Y":
                    break
                elif existAction.upper() == "N":
                    exit(0)
                else:
                    print("please enter Y or N.")
                    continue
            except Exception as e:
                print("please enter Y or N.")
                continue



def Pdf2WordConvert(PdfFile,DocFile):
    try:
        cv = Converter(PdfFile)
        cv.convert(DocFile, start=0, end=None)
        cv.close()
    except RuntimeError :
        print("Please enter a correct PDF file path")


if __name__ == '__main__':
    pdffile = None
    wordfile = None
    if len(sys.argv) > 1:
        i = 1
        while i < len(sys.argv):
            if sys.argv[i] == "-h":
                func_help()
                exit(0)
            elif sys.argv[i] == "-p":
                i = i + 1
                if i >= len(sys.argv):  # 表示-p后面没有跟随-p的值
                    print("The value of -p must be specified!!!")
                    exit(1)
                elif re.match("^-", sys.argv[i]) != None:  # 判断-p的值，如果-p的下个参数以-开头，表示没有指定-p值
                    print("The value of -p must be specified!!!")
                    exit(1)
                pdffile = sys.argv[i]
            elif sys.argv[i] == "-w":
                i = i + 1
                if i >= len(sys.argv):  # 表示-w后面没有跟随-w的值
                    print("The value of -w must be specified!!!")
                    exit(2)
                elif re.match("^-", sys.argv[i]) != None:  # 判断-w的值，如果-w的下个参数以-开头，表示没有指定-w值
                    print("The value of -w must be specified!!!")
                    exit(2)
                wordfile = sys.argv[i]
            elif (re.match("^-", sys.argv[i]) == None) and i == 1:   #第一个参数不以-开头，默认为输入的pdf文件
                pdffile = sys.argv[i]
            elif (re.match("^-", sys.argv[i]) == None) and i == 2:   #第二个参数不以-开头，默认为输出的docx文件
                wordfile = sys.argv[i]
            i = i + 1
    else:
        print("You can use -h to get help.")
        exit(0)

    if not os.path.isfile(pdffile):
        print(not os.path.isfile(pdffile))
        print("%s is not exist。"%pdffile)
        exit(3)

    if wordfile == None:
        wordfile = pdffile.split(".")[0]+".docx"


    WordFileExist(wordfile)
    Pdf2WordConvert(pdffile,wordfile)



