#!/bin/bash
# author by ray
# v2

#定义获取内容的函数
getContent(){
	content=`echo " "$1 | tr [a-z] [A-Z]`  #把小写字母替换成大写
	content2=`echo $1 | tr [a-z] [A-Z]`
	for num in `awk "/${content}/{print NR}" $2`
	do
		#不扫描注释的行
		`sed -n "${num}p" $2 | grep -q "^--"`
		if [ $? -eq 0 ]
		then
			continue
		fi
	#	`sed -n "${num}p" $2 | grep -Po '(?<=TH_VEHICLE_ALARM)[\.\" ]|TH_VEHICLE_ALARM$' | grep -q -E '\"|.'`
		`sed -n "${num}p" $2 | egrep -o "${content2}[\.\" ]|${content2}$" | grep -q -E '\"|.|\ '`
		if [ $? -ne 0 ]
		then
			continue
		fi
		#获取结束的行号
		endraw=$num
		while true
		do
	  		`sed -n "${endraw}p" $2 | grep -q ";$"`
	  		if [ $? -eq 0 ]
	  		then
	  			break
	  		else
	  			endraw=$[$endraw+1]
	  		fi
		done
		#获取开始的行号
		beginraw=$[$num-1]
		while true
		do
	  		`sed -n "${beginraw}p" $2 | grep -q ";$"`
	  		if [ $? -eq 0 ]
	  		then
	  			beginraw=$[$beginraw+1]
	  			break
	  		else
	  			[ $beginraw -le 0 ] && beginraw=1; break || beginraw=$[$beginraw-1]
	  			#beginraw=$[$beginraw-1]
	  		fi
		done
		#打印内容或者重定向到指定的文件名称
		#sed -n "${beginraw},${endraw}p" $2 >> $3
		sed -n "${beginraw},${endraw}p" $2
	done
}

#脚本的入口，调用函数获取内容
if [ -e $1 ];then  #判断第一个参数是否为文件
	for line in `cat $1`
	do
		getContent ${line} $2
	done
else
	getContent $1 $2
fi


#sed -r 's/(TABLESPACE)[ ]+[a-zA-Z_]+/\1 ray/'   修改表空间名称，在Linux系统执行