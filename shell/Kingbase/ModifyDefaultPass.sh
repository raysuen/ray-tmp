#!/bin/bash
#v1.2

#set -e
BuildPassword(){
	while true
	do
		userpass=`openssl rand -base64 12`
		if [ `echo ${userpass} | egrep -o [[:digit:]] | wc -l` -ge 2 ] && [ `echo ${userpass} | egrep -o [[:alpha:]] | wc -l` -ge 2 ] && [ `echo ${userpass} | egrep -o [[:punct:]] | wc -l` -ge 2 ];then
			break
		fi
	done
}

ModifyPassword(){
	BuildPassword
	date_tmp=`date +"%Y%m%d%H%M"`
	kingbase_path=`ps -ef | grep "bin/kingbase" | grep -v grep | awk '{print $8}'`
	bin_path=${kingbase_path%/*}
	export KINGBASE_PORT=`ps -ef | grep "bin/kingbase" |egrep -v "grep" | awk '{print "netstat -lantup 2> /dev/null | egrep "$2" |egrep tcp | egrep -v \"tcp6\" | awk -F'\''[ :]+'\'' '\''{print $5}'\''"}' | bash`
# 	export KINGBASE_PASSWORD="12345678ab"
	[ -f /home/kingbase/.encpwd ]&& cp /home/kingbase/.encpwd /home/kingbase/.encpwd_${date_tmp}
	${bin_path}/sys_encpwd -H \* -P \* -D \* -U sso -W "12345678ab"
	${bin_path}/sys_encpwd -H \* -P \* -D \* -U sao -W "12345678ab"
	${bin_path}/ksql -U sso -d test -c "alter user sso password '${userpass}';"
	sso_res=`echo $?`
	${bin_path}/ksql -U sao -d test -c "alter user sao password '${userpass}';"
	sao_res=`echo $?`
# 	unset KINGBASE_PASSWORD
	if [ -f /home/kingbase/.encpwd_${date_tmp} ];then
		rm -f /home/kingbase/.encpwd && cp /home/kingbase/.encpwd_${date_tmp} /home/kingbase/.encpwd
	else
		rm -f /home/kingbase/.encpwd
	fi
	if [ ${sso_res} -eq 0 ] && [ ${sso_res} -eq 0 ];then
		echo -e "sso and sao passwords have been changed to \e[1;31m\""${userpass}"\"\e[0m"
	fi
}

ModifyPassword
