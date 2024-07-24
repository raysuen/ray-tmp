#!/bin/bash
#by raysuen
#v 1.0

source ~/.bash_profile


######################################################
#The function for verifing pdb is exists. 
######################################################
IsPDBExists(){
	sqlplus -s /nolog<<-RAY
		conn / as sysdba
		set heading off
		set feedback off
		select name from v\$containers where name=upper('$1');
	RAY

}

######################################################
#The function for alter password of oracle's user 
######################################################
AlterUserPassword(){
	if [ $# -eq 3 ];then
		if [ -n "`IsPDBExists $3`" ];then
			sqlplus -s /nolog<<-RAY
				conn / as sysdba
				alter session set container=$3;
				alter user $1 identified by "$2";
			RAY
		else
			echo "The pdb is not exists in oracle."
		fi
	elif [ $# -eq 2 ];then
		sqlplus -s /nolog<<-RAY
			conn / as sysdba
			alter user $1 identified by "$2";
		RAY
	fi

}

help_fun(){
	echo "AlterUserPassword.sh usage:
		-u:		specify oracle user name.
		-p:		specify a password of oracle user
		-pdb:	specify oracle pdb name. 
	example:
		AlterUserPassword.sh -u test -p password
		AlterUserPassword.sh -u test -p password -pdb pdb name
	"
	
}


main(){
	if [ $# -eq 0 ];then
		echo "Please using -h to get helping." 
		exit 0
	fi
	while (($#>=1))   #循环获取脚本参数
	do
    	case `echo $1 | sed s/-//g | tr [a-z] [A-Z]` in
    	    H)        #-h获取帮助
    	        help_fun          #执行帮助函数
    	        exit 0
    	    ;;
    	    U)    #执行oracle用户名称
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify right parameters."
    	        	echo "You can use -h or -H to get help."
    	        	exit 98
    	    	else
    	    		orauser=$1
    	    	fi
    	    	shift
    	    ;;
    	    PDB)    #指定pdb的名称，如果不指定则默认当前数据库为非容器类型数据库 
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify right parameters."
    	        	echo "You can use -h or -H to get help."
    	        	exit 97
    	    	else
    	    		pdbname=$1
    	    	fi
    	    	shift
    	    ;;
    	    P)    #--password 需要修改的oracle用户密码
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify right parameters."
    	        	echo "You can use -h or -H to get help."
    	        	exit 96
    	    	else
    	    		pwd=$1
    	    	fi
    	    	shift

    	    ;;
    	    *)
    	        echo "You must specify right parameters."
    	        echo "You can use -h or -H to get help."
    	        exit 95
    	    ;;
    	esac
	done

	#如果oracle用户被指定，则必须要要执行解锁或是查询用户是否有密码错误登录情况
	if [[ -z $orauser ]] || [[ -z $pwd ]];then
		echo "You must specify right parameters."
		echo "You can use -h or -H to get help."
	    exit 94
	fi
	
	if [[ ${#pdbname} -gt 0 ]] ;then
		AlterUserPassword $orauser $pwd $pdbname
	elif [[ ${#pdbname} -eq 0 ]] ;then
		AlterUserPassword $orauser $pwd
	fi
	
}

###########################################
#
###########################################
main $*
