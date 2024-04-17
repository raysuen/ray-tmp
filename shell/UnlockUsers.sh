#!/bin/bash
#auth by raysuen
#v2.1


. ~/.bash_profile


SCRIPTVERSION='2.1'


#container类型解锁用户
UnlockUserInfo(){
	if [ $# -eq 2 ];then
		sqlplus -s /nolog<<-RAY
		conn / as sysdba
		alter session set container=$1;
		set linesize 300 pages 1000
		col userid for a20
		col userhost for a20
		col COMMENT\$TEXT for a150
 		with s1 as (
 			select rownum id,USERID,a.RETURNCODE,a.USERHOST,a.scn,a.COMMENT\$TEXT 
  			from SYS.AUD$ a
  			WHERE USERID = upper('$2') 
  				and a.RETURNCODE=1017
 			),
 		s2 as (
 			SELECT rownum id, to_char(A.TIMESTAMP,'yyyy-mm-dd hh24:mi:ss') TIMESTAMP,USERNAME, A.RETURNCODE,a.USERHOST
   			FROM DBA_AUDIT_SESSION A
  			WHERE A.USERNAME = upper('$2') 
      		and A.RETURNCODE=1017
 			)
 		select s2.TIMESTAMP,s1.userid,s1.RETURNCODE,s1.USERHOST,s1.COMMENT\$TEXT from s1,s2 
     		where s1.userid=s2.username 
         	and s1.RETURNCODE=s2.RETURNCODE
         	and s1.id=s2.id
         	and s1.USERHOST=s2.USERHOST;
		RAY
	elif [ $# -eq 1 ];then
		sqlplus -s /nolog<<-RAY
		conn / as sysdba
		set linesize 300 pages 1000
		col userid for a20
		col userhost for a20
		col COMMENT\$TEXT for a150
 		with s1 as (
 			select rownum id,USERID,a.RETURNCODE,a.USERHOST,a.scn,a.COMMENT\$TEXT 
  			from SYS.AUD$ a
  			WHERE USERID = upper('$2') 
  				and a.RETURNCODE=1017
 			),
 		s2 as (
 			SELECT rownum id, to_char(A.TIMESTAMP,'yyyy-mm-dd hh24:mi:ss') TIMESTAMP,USERNAME, A.RETURNCODE,a.USERHOST
   			FROM DBA_AUDIT_SESSION A
  			WHERE A.USERNAME = upper('$2') 
      		and A.RETURNCODE=1017
 			)
 		select s2.TIMESTAMP,s1.userid,s1.RETURNCODE,s1.USERHOST,s1.COMMENT\$TEXT from s1,s2 
     		where s1.userid=s2.username 
         	and s1.RETURNCODE=s2.RETURNCODE
         	and s1.id=s2.id
         	and s1.USERHOST=s2.USERHOST;
		RAY
	fi
}

UnLockUser(){
	if [ $# -eq 2 ];then
		sqlplus -s /nolog<<-RAY
		conn / as sysdba
		alter session set container=$1;
		alter user $2 account unlock;
		RAY
	elif [ $# -eq 1 ];then
		sqlplus -s /nolog<<-RAY
		conn / as sysdba
		alter user $1 account unlock;
		RAY
	fi
}

<<EOF
ShowLockUsers(){
	sqlplus -s /nolog<<-RAY
	conn / as sysdba
	set linesize 300
	col username for a30
	col pdbname for a20
	SELECT USERNAME, to_char(LOCK_DATE,'yyyy-mm-dd hh24:mi:ss') LOCK_DATE,p.name pdbname
  		FROM CDB_USERS cu,v\$pdbs p
 		WHERE ACCOUNT_STATUS = 'LOCKED(TIMED)' and p.con_id=cu.con_id;
RAY
}
EOF

ShowLockUsers(){
	sqlplus -s /nolog<<-RAY
	conn / as sysdba
	set serveroutput on
	set linesize 300
	col username for a30
	col pdbname for a20
	declare
		iscdb varchar2(5);
		execsql varchar2(1000);
		cursor ncursor is SELECT username, to_char(LOCK_DATE,'yyyy-mm-dd hh24:mi:ss') LOCK_DATE FROM DBA_USERS cu WHERE ACCOUNT_STATUS = 'LOCKED(TIMED)';
		cursor ccursor is SELECT USERNAME, to_char(LOCK_DATE,'yyyy-mm-dd hh24:mi:ss') LOCK_DATE,p.name pdbname FROM CDB_USERS cu,v\$pdbs p WHERE ACCOUNT_STATUS = 'LOCKED(TIMED)' and p.con_id=cu.con_id;
	begin
		dbms_output.put_line(' ');
		select cdb into iscdb from v\$database;
		if iscdb = 'NO' then
			dbms_output.put_line(rpad('USERNAME',40)||lpad('LOCK_DATE',20));
			dbms_output.put_line(lpad('_',60,'_'));
			for res in ncursor
			loop			
				dbms_output.put_line(RPAD(res.username,40)||rpad(res.LOCK_DATE,20));
			end loop;
		elsif iscdb = 'YES' then
			dbms_output.put_line(rpad('USERNAME',40)||lpad('LOCK_DATE',20)||lpad('PDBNAME',15));
			dbms_output.put_line(lpad('_',80,'_'));
			for res in ccursor
			loop			
				dbms_output.put_line(RPAD(res.username,40)||rpad(res.LOCK_DATE,20)||lpad(res.pdbname,10));
			end loop;
		end if;
	end;
	/
RAY
}

ShowVersion(){
	echo "version : "${SCRIPTVERSION}
}


help_fun(){
	echo "UnlockUsers.sh usage:
		-s：		Show locked user infomation.
		-u:		specify oracle user name.
		-p:		specify oracle pdb name.
		-ul:		unlock oracle user.
		-sul:		specify to show failed logon infomation of oracle user.  
	example:
		UnlockUsers.sh -s
		UnlockUsers.sh -u test -ul
		UnlockUsers.sh -u test -ul -sul
		UnlockUsers.sh -u test -p pdb name -ul
		UnlockUsers.sh -u test -p pdb name -sul
		UnlockUsers.sh -u test -p pdb name -ul -sul
	"
	
}

##################################################################
#脚本的执行入口，获取参数
##################################################################
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
    	    S)          #-s 显示锁定的用户信息
    	        shift
    	        if [ $# -eq 0 ];then
    	        	ShowLockUsers
    	        	exit 0
    	        # elif [ $# -eq 1 ];then
#     	        	Umount_NTFS $1
    	        	exit 0
    	        else
    	        	echo "You must specify a right parameter."
    	        	echo "You can use -h or -H to get help."
    	        	exit 99
    	        fi
    	    ;;
    	    U)    #执行oracle用户名称
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify a right parameter."
    	        	echo "You can use -h or -H to get help."
    	        	exit 98
    	    	else
    	    		orauser=$1
    	    	fi
    	    	shift
    	    ;;
    	    P)    #指定pdb的名称，如果不指定则默认当前数据库为非容器类型数据库 
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify a right parameter."
    	        	echo "You can use -h or -H to get help."
    	        	exit 97
    	    	else
    	    		pdbname=$1
    	    	fi
    	    	shift
    	    ;;
    	    UL)    #--Unlock 指定动作为解锁oracle用户
    	    	unOraLock=1
    	    	shift

    	    ;;
    	    SUL)   #--ShowUserLockInfomation 显示锁定用户是否有密码错误登录
    	    	showUserInfo=1
    	    	shift

    	    ;;
			V)   #--ShowVersion 显示脚本版本
    	    	ShowVersion
    	    	exit 0

    	    ;;
    	    *)
    	        echo "You must specify a right parameter."
    	        echo "You can use -h or -H to get help."
    	        exit 95
    	    ;;
    	esac
	done

	#如果oracle用户被指定，则必须要要执行解锁或是查询用户是否有密码错误登录情况
	if [[ -n $orauser ]] && [[ $unOraLock -eq 0 ]] && [[ $showUserInfo -eq 0 ]];then
		echo "You must specify a right parameter."
		echo "You can use -h or -H to get help."
	    exit 93
	fi
	
	if [[ ${#orauser} -gt 0 ]] && [[ ${#pdbname} -gt 0 ]] && [[ $unOraLock -eq 1 ]];then
		UnLockUser $pdbname $orauser
	elif [[ ${#orauser} -gt 0 ]] && [[ ${#pdbname} -eq 0 ]] && [[ $unOraLock -eq 1 ]];then
		UnLockUser $orauser
	fi
	
	if [[ ${#orauser} -gt 0 ]] && [[ ${#pdbname} -gt 0 ]] && [[ $showUserInfo -eq 1 ]];then
		UnlockUserInfo $pdbname $orauser
	elif [[ ${#orauser} -gt 0 ]] && [[ ${#pdbname} -eq 0 ]] && [[ $showUserInfo -eq 1 ]];then
		UnlockUserInfo $orauser
	fi


}


main $*
