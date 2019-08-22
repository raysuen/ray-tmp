#!/bin/bash
# by ray
# 2016-06-06

. ~/.bash_profile

gglog=/tmp/.ggslog.log
statuslog=/home/oracle/shell/check_ogg_extractstatus.log

cd /u01/ogg


while true
do
	echo "info all"|./ggsci > ${gglog}
	array=(`grep EXTRACT ${gglog} | awk '$2!~/RUNNING/{print $3}'`)
	if [[ ${#array[@]} -gt 0 ]];then
		echo "####################################################"  >> ${statuslog}
		echo "`date +%Y%m%d_%H%M%S`" >> ${statuslog}
		cat ${gglog} >> ${statuslog}
		echo "stop EXTXNYPT"|./ggsci
		echo "alter EXTRACT EXTXNYPT,begin now"|./ggsci
		echo "start EXTXNYPT"|./ggsci
		sh /home/oracle/shell/mail_pl.sh "sunpeng@transilink.com" 'OGG进程重启' 'OGG进程重启'
	else
		echo "####################################################"  >>${statuslog}
		echo "`date +%Y%m%d_%H%M%S`" >> ${statuslog}
		echo "EXTRACT is running!!" >> ${statuslog}
	fi
	sleep 2m
done

