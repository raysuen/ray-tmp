#!/bin/bash
#by raysuen
#v 1.0

source ~/.bash_profile

##############################################
#显示锁定会话信息
##############################################
ShowLockObjectInfo(){
	sqlplus -s /nolog<<-RAY
		conn / as sysdba
		Set linesize 350
		Col inst_id for 99
		Col locked_mode for a15
		Col username for a25
		Col osuser for a20
		col SCHEMANAME for a25
		col PROCESS for a8
		Col MACHINE for a20
		col TERMINAL for a20
		Col MODULE for a25
		Col SERVICE_NAME for a20
		Col pdb_name for a15
		select l.inst_id,decode(l.locked_mode, 0, 'None', 
                             1, 'Null (NULL)', 
                             2, 'Row-S (SS)', 
                             3, 'Row-X (SX)', 
                             4, 'Share (S)', 
                             5, 'S/Row-X (SSX)', 
                             6, 'Exclusive (X)', 
                             l.locked_mode) locked_mode,s.sid,s.serial#,s.username,s.schemaname,s.osuser,s.process,s.machine,s.port,s.terminal,s.module,s.service_name,c.name as "pdb_name"
		from gV\$LOCKED_OBJECT l,gv\$session s,gv\$containers c 
    	where l.SESSION_ID=s.sid(+) and c.con_id=l.con_id;
	RAY

}

##############################################
#判断会话是否存在
##############################################
IsSessionExists(){
	sqlplus -s /nolog<<-RAY
		conn / as sysdba
		set heading off
		set feedback off
		select count(1) from gv\$session where sid=$1 and  SERIAL#=$2;
	RAY
}

##############################################
#杀死会话
##############################################
UnlockSession(){
	if [ $# -eq 3 ];then
		sqlplus -s /nolog<<-RAY
			conn / as sysdba
			alter system kill session '$1,$2,@$3' immediate;
		RAY
	elif [ $# -eq 2 ];then
		sqlplus -s /nolog<<-RAY
			conn / as sysdba
			alter system kill session '$1,$2' immediate;
		RAY
	fi
	

}

##############################################
#帮助函数
##############################################
help_fun(){
	echo "UnlockObjectSession.sh usage:
		-s:		show locked infomation.
		-k:		mean to kill session.
		-se:	specify session id.
		-sr:	specify serial id. 
		-i		specify instance id.
	example:
		UnlockObjectSession.sh -s
		UnlockObjectSession.sh -k -se 111 -sr 1234
		UnlockObjectSession.sh -k -se 111 -sr 1234 -i 1
	"
	
}

##############################################
#主函数
##############################################
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
    	    S)    #显示被锁定的对象，以及锁定的信息
    	    	shift
    	    	if [ $# -gt 0 ];then
    	    		echo "You must specify right parameters."
    	        	echo "You can use -h or -H to get help."
    	        	exit 98
    	    	else
    	    		isShow=1
    	    	fi
    	    	shift
    	    ;;
    	    K)    #指定要kill session
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify right parameters."
    	        	echo "You can use -h or -H to get help."
    	        	exit 97
    	    	else
    	    		isKill=1
    	    	fi
    	    	#shift
    	    ;;
    	    SE)    #指定session id
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify right parameters."
    	        	echo "You can use -h or -H to get help."
    	        	exit 96
    	    	else
    	    		if [[ `grep '^[[:digit:]]*$' <<< "$1"` ]];then
    	    			sessionid=$1
    	    		else
    	    			echo "You must specify right parameters."
    	        		echo "You can use -h or -H to get help."
    	        		exit 91
    	    		fi
    	    	fi
    	    	shift

    	    ;;
    	    SR)    #指定serial number
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify right parameters."
    	        	echo "You can use -h or -H to get help."
    	        	exit 95
    	    	else
    	    		if [[ `grep '^[[:digit:]]*$' <<< "$1"` ]];then
    	    			serialnum=$1
    	    		else
    	    			echo "You must specify right parameters."
    	        		echo "You can use -h or -H to get help."
    	        		exit 90
    	    		fi
    	    	fi
    	    	shift
    	    ;;
			I)    #指定实例号
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify right parameters."
    	        	echo "You can use -h or -H to get help."
    	        	exit 88
    	    	else
    	    		if [[ `grep '^[[:digit:]]*$' <<< "$1"` ]];then
    	    			instid=$1
    	    		else
    	    			echo "You must specify right parameters."
    	        		echo "You can use -h or -H to get help."
    	        		exit 87
    	    		fi
    	    	fi
    	    	shift
    	    ;;
    	    *)
    	        echo "You must specify right parameters."
    	        echo "You can use -h or -H to get help."
    	        exit 94
    	    ;;
    	esac
	done

	#如果-s和-k同时被指定，则返回报错
	if [[ -n $isShow ]] && [[ -n $isKill ]];then
		echo "You only use -k or -s"
		echo "You can use -h or -H to get help."
	    exit 93
	elif [[ $isShow -eq 1 ]];then        #判断是否需要显示锁定信息
		ShowLockObjectInfo               #执行显示锁定对象函数
	elif [[ $isKill -eq 1 ]] && [[ -n $sessionid ]] && [[ -n $serialnum ]];then   #判断是否要杀死会话，并是否指定会话ID和serial ID
# 		echo "session_id:"${sessionid}",serial:"$serialnum
		if [[ `IsSessionExists ${sessionid} ${serialnum}` -gt 0 ]];then            #判断输入的会话ID和serial id是否存在
			UnlockSession ${sessionid} ${serialnum}
		elif [[ `IsSessionExists ${sessionid} ${serialnum}` -gt 0 ]] && [[ -n ${instid} ]];then #判断输入的会话ID、serial id和实例ID是否存在
			UnlockSession ${sessionid} ${serialnum} ${instid}
		else
			echo "The session not exists."
			exit 89
		fi
		#UnlockSession ${sessionid} ${serialnum}
	else
		echo "You can use -h or -H to get help."
		echo 92
	fi
	
}

main $*








