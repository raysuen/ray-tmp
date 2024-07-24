#!/bin/bash
#by raysuen
#v1.0
#exec sql file
#sun scripts by oracle or OS user with permission to execute SQLPLUS


source ~/.bash_profile


c_red="\e[1;31m"
c_end="\e[0m"


ExecSQL(){
	sqlplus -S /nolog<<-RAY
	conn / as sysdba
	@$1
	exit
	RAY
}

help(){
	echo "You must specify a parameter."
	exit 99
}

main(){
	if [[ $# < 1 ]];then
		echo "You must specify a parameter."
		exit 1
	fi
	if [ -f $1 ] ;then
		if [ `egrep -i "alter|truncate|drop|create" $1 | wc -l` -ge >= 1 ];then
			echo -e " ${c_red}WARNING,The script can not be executing DDL.${c_end}"
			exit 2
		fi
		ExecSQL $1
	else
		help
		
	fi

	exit 0	
}

####################################
# script entrance
####################################
main $*



