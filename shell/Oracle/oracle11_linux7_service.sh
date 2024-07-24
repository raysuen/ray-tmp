#!/bin/bash
#by raysuen
#v01


####################################################
# load environment variable                        #
####################################################
[ -f ~/.bash_profile ]&& source ~/.bash_profile


####################################################
# definition the owner of oracle                   #
####################################################
ORA_OWNR=oracle

####################################################
#obtain the path of script                         #
####################################################
ScriptsPath=$(cd `dirname $0i`;pwd)

####################################################
# startup, shutdown, restart                       #
####################################################


case "$1" in
start)
# Oracle listener and instance startup
	su - $ORA_OWNR -c "lsnrctl stat > /dev/null"
	if [ $? -ne 0 ];then
		su - $ORA_OWNR -c "lsnrctl start > /dev/null"
		echo "Oracle Listener start Succesful!"
	else
		echo "Oracle Listener have started!"
	fi

	if [ `ps -ef | grep ora_ | grep -v grep | wc -l` -gt 5 ];then
		echo "Oracle Instance have started!!"
	
	else
		su - $ORA_OWNR -c "dbstart > /dev/null"
		if [ `ps -ef | grep ora_ | grep -v grep | wc -l` -gt 5 ];then
			echo "Oracle Start Succesful!"
			exit 0
		elif [ `ps -ef | grep ora_ | grep -v grep | wc -l` -eq 0 ];then
			echo "Oracle Start Failed"
			exit 1
		fi
	fi
;;
stop)
# Oracle listener and instance shutdown
	su - $ORA_OWNR -c "lsnrctl stat > /dev/null"
	if [ $? -ne 0 ];then
		su - $ORA_OWNR -c "lsnrctl stop > /dev/null"
		echo "Oracle Listener stop Succesful!"
	else
		echo "Oracle Listener have stopped!"
	fi
	
	if [ `ps -ef | grep ora_ | grep -v grep | wc -l` -eq 0 ];then
		echo "Oracle Instance have stopped!!"
	elif [ `ps -ef | grep ora_ | grep -v grep | wc -l` -gt 5 ];then
		su - $ORA_OWNR -c "dbshut > /dev/null"
		if [ `ps -ef | grep ora_ | grep -v grep | wc -l` -eq 0 ];then
			echo "Oracle Stop Succesful!"
			exit 0
		elif [ `ps -ef | grep ora_ | grep -v grep | wc -l` -gt 5 ];then
			echo "Oracle Stop Failed"
			exit 1
		fi
	fi
;;
restart)
	/bin/bash ${ScriptsPath}/$0 stop
	/bin/bash ${ScriptsPath}/$0 start
;;
*)
	echo $"Usage: `basename $0` {start|stop|reload}"
	exit 1
esac
exit 0