#!/bin/bash

#!/bin/bash
#by raysuen
#v 2.5

source ~/.bash_profile

######################################################
#The function for show datafile
######################################################
ShowDatafiles(){
	sqlplus -s /nolog<<-RAY
	conn / as sysdba
	set serveroutput on
	set linesize 300
	declare
		iscdb varchar2(5);
		execsql varchar2(1000);
		OMFPatch varchar2(20);
		cursor ncursor is select distinct substr(name,1,instr(name,'/',-1)) DATAFILE_PATH from v\$datafile;
		cursor ccursor is select distinct substr(df.name,1,instr(df.name,'/',-1)) DATAFILE_PATH,c.name PDB_NAME from gv\$datafile df,v\$containers c where c.con_id=df.con_id and c.name<>'PDB$SEED';
	begin
		dbms_output.put_line(' ');
		select cdb into iscdb from v\$database;
		select VALUE INTO OMFPatch from v\$parameter where name = 'db_create_file_dest';
		IF OMFPatch is not null THEN
			dbms_output.put_line(rpad('DATAFILE_PATH',100));
			dbms_output.put_line(lpad('_',100,'_'));
			dbms_output.put_line(OMFPatch);
		elsif iscdb = 'NO' then
			dbms_output.put_line(rpad('DATAFILE_PATH',100));
			dbms_output.put_line(lpad('_',100,'_'));
			for res in ncursor
			loop
				dbms_output.put_line(RPAD(res.DATAFILE_PATH,100));
			end loop;
		elsif iscdb = 'YES' then
			dbms_output.put_line(rpad('DATAFILE_PATH',100)||rpad('PDB_NAME',20));
			dbms_output.put_line(lpad('_',120,'_'));
			for res in ccursor
			loop
				dbms_output.put_line(RPAD(res.DATAFILE_PATH,100)||rpad(res.PDB_NAME,20));
			end loop;
		end if;
	end;
	/
RAY
}

######################################################
#The function for get OMF
######################################################
GetOMF(){
	sqlplus -s /nolog<<-RAY
		conn / as sysdba
		set heading off
		set feedback off
		select VALUE from v\$parameter where name = 'db_create_file_dest';
		--select VALUE from v\$parameter where name like 'db_create_file_dest%';
	RAY
}

######################################################
#The function for create tablespace,$1 is tablespace name,$2 is datafile path,$3 is pdb_name
######################################################
CreateTablespace(){
	OMFList=(`GetOMF`)
	if [ ! -z ${OMFList} ];then 
		for i in ${OMFList[@]}
		do
			if [ "$i" == `echo $2 | tr '[:lower:]' '[:upper:]'` ];then
				#tb_sql="create tablespace "$1" datafile '"$2"' size 128M autoextend on next 128M maxsize unlimited;"
				tbname=$1
				dbfile=$2
			fi
		done
#		if [ `GetOMF` == `echo $2 | tr '[:lower:]' '[:upper:]'` ];then
#			#tb_sql="create tablespace "$1" datafile '"$2"' size 128M autoextend on next 128M maxsize unlimited;"
#			tbname=$1
#			dbfile=$2
#		else
#			echo "OMF is seted,pleas enter a right path."
#			exit 49
#		fi
	else
		if [ `echo $2 | egrep ".*/$"` ];then 
			#tb_sql="create tablespace "$1" datafile '"$2$1"_01.dbf' size 128M autoextend on next 128M maxsize unlimited;"
			tbname=$1
			dbfile=$2$1"_01.dbf"
		else
			#tb_sql="create tablespace "$1" datafile '"$2"/"$1"_01.dbf' size 128M autoextend on next 128M maxsize unlimited;"
			tbname=$1
			dbfile=$2"/"$1"_01.dbf"
		fi
	fi
#	echo $tbname
#	echo $dbfile
	if [ $# -gt 2 ] && [ ! -z $tbname ] && [ ! -z $dbfile ];then
		sqlplus -s /nolog<<-RAY
				conn / as sysdba
				set feedback off
				alter session set container=$3;
				set serveroutput on
				DECLARE
					cb_error  exception;--声明异常
					pragma exception_init(cb_error,-1119);--使用编译指示器将异常名称和oracle的错误代码绑定
					execsql varchar2(2000);
				BEGIN
					-- 尝试执行某些操作，可能会引发异常
					--v_value := 10 / 0;
					execsql := 'CREATE TABLESPACE $tbname DATAFILE '||chr(39)||'$dbfile'||chr(39)||' SIZE 128M autoextend ON NEXT 128M maxsize unlimited';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					DBMS_OUTPUT.PUT_LINE('OK');
					--DBMS_OUTPUT.PUT_LINE('The tablespace is created successfully.');
					EXCEPTION
						WHEN cb_error THEN
							-- 捕获除以零的异常
							DBMS_OUTPUT.PUT_LINE('create tablesapce failed！,info：'|| SQLCODE || ' - ' || SQLERRM);
						WHEN OTHERS THEN
							-- 捕获其他所有类型的异常
							DBMS_OUTPUT.PUT_LINE('other exceptions: ' || SQLCODE || ' - ' || SQLERRM);
				END;
				/
				RAY
	elif  [ ! -z $tbname ] && [ ! -z $dbfile ];then
		sqlplus -s /nolog<<-RAY
				conn / as sysdba
				set serveroutput on
				set feedback off
				DECLARE
					cb_error  exception;--声明异常
					pragma exception_init(cb_error,-1119);--使用编译指示器将异常名称和oracle的错误代码绑定
					execsql varchar2(2000);
				BEGIN
					-- 尝试执行某些操作，可能会引发异常
					--v_value := 10 / 0;
					execsql := 'CREATE TABLESPACE $tbname DATAFILE '||chr(39)||'$dbfile'||chr(39)||' SIZE 128M autoextend ON NEXT 128M maxsize unlimited';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					DBMS_OUTPUT.PUT_LINE('OK');
					--DBMS_OUTPUT.PUT_LINE('The tablespace is created successfully.');
					EXCEPTION
						WHEN cb_error THEN
							-- 捕获除以零的异常
							DBMS_OUTPUT.PUT_LINE('create tablesapce failed！,info：'|| SQLCODE || ' - ' || SQLERRM);
						WHEN OTHERS THEN
							-- 捕获其他所有类型的异常
							DBMS_OUTPUT.PUT_LINE('other exceptions：' || SQLCODE || ' - ' || SQLERRM);
				END;
				/
				RAY
	fi
	
}

######################################################
#The function for create User,$1 is username,$2 is pdb_name
######################################################
CreateUser(){
	
	if [ $# -gt 2 ];then
		sqlplus -s /nolog<<-RAY
				conn / as sysdba
				set feedback off
				alter session set container=$3;
				set serveroutput on
				DECLARE
					cu_error1  exception;--声明异常
					pragma exception_init(cu_error1,-959);--使用编译指示器将异常名称和oracle的错误代码绑定
					execsql varchar2(2000);
					userinfo varchar2(500);
				BEGIN
					-- 尝试执行某些操作，可能会引发异常
					--v_value := 10 / 0;
					execsql := 'create user $1 identified by "$2" default tablespace $1';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					execsql := 'grant resource,connect to $1';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					execsql := 'grant create table,create view,create job,create materialized view,create sequence,create any procedure to $1';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					execsql := 'ALTER USER $1 QUOTA UNLIMITED ON $1';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					DBMS_OUTPUT.PUT_LINE('OK');
					--DBMS_OUTPUT.PUT_LINE('The user is created successfully.');
					--userinfo := 'The user name: $1, password : ${userpwd}';
					DBMS_OUTPUT.PUT_LINE(userinfo);
					EXCEPTION
						WHEN cu_error1 THEN
							-- 捕获除以零的异常
							DBMS_OUTPUT.PUT_LINE('create user failed！,info：'|| SQLCODE || ' - ' || SQLERRM);
						WHEN OTHERS THEN
							-- 捕获其他所有类型的异常
							DBMS_OUTPUT.PUT_LINE('other exceptions:' || SQLCODE || ' - ' || SQLERRM);
				END;
				/
				RAY
	else
		sqlplus -s /nolog<<-RAY
				conn / as sysdba
				set serveroutput on
				set feedback off
				DECLARE
					cu_error1  exception;--声明异常
					pragma exception_init(cu_error1,-959);--使用编译指示器将异常名称和oracle的错误代码绑定
					execsql varchar2(2000);
				BEGIN
					-- 尝试执行某些操作，可能会引发异常
					--v_value := 10 / 0;
					execsql := 'create user $1 identified by "$2" default tablespace $1';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					execsql := 'grant resource,connect to $1';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					execsql := 'grant create table,create view,create job,create materialized view,create sequence,create any procedure to $1';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					execsql := 'ALTER USER $1 QUOTA UNLIMITED ON $1';
					--DBMS_OUTPUT.PUT_LINE(execsql);
					execute IMMEDIATE execsql;
					DBMS_OUTPUT.PUT_LINE('OK');
					--DBMS_OUTPUT.PUT_LINE('The user is created successfully.');
					--DBMS_OUTPUT.PUT_LINE('The user name:'||$1||', password : '${userpwd});
					EXCEPTION
						WHEN cu_error1 THEN
							-- 捕获除以零的异常
							DBMS_OUTPUT.PUT_LINE('create user failed！,info：'|| SQLCODE || ' - ' || SQLERRM);
						WHEN OTHERS THEN
							-- 捕获其他所有类型的异常
							DBMS_OUTPUT.PUT_LINE('other exceptions:' || SQLCODE || ' - ' || SQLERRM);
				END;
				/
				
				RAY

	fi
	
}


######################################################
#The function for get pdb name
######################################################
IsPDBExists(){
	sqlplus -s /nolog<<-RAY
		conn / as sysdba
		set heading off
		set feedback off
		select name from v\$containers where name=upper('$1');
	RAY
	
}

help_fun(){
	echo "CreateUserAndTablespace usage:
		-s:		show datafile paths.
		-u:		specify oracle user name.
		-p:		specify oracle pdb name.
		-sid:	specify oracle SID name. 
		-d:		specify a path of datafiles.
		-a:		specify a action:all\tablespace\user,all means creating user and tablespace,
					tablespace means creating a tablespace,user means creating a user.
	example:
		CreateUserAndTablespace.sh -s
		CreateUserAndTablespace.sh -a all -u test -d datafile_path
		CreateUserAndTablespace.sh -a all -u test -d datafile_path -sid sid_name
		CreateUserAndTablespace.sh -a all -u test -d datafile_path -p pdb_name
	"
	
}

######################################################
#The function for main
######################################################
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
			SID)    #指定pdb的名称，如果不指定则默认当前数据库为非容器类型数据库 
				shift
				if [ $# -eq 0 ];then
					echo "You must specify right parameters."
					echo "You can use -h or -H to get help."
					exit 97
				else
					orasid=$1
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
					orapdb=$1
				fi
				shift
				
			;;
			D)    #--datafile path,创建表空间的数据文件的路径
				shift
				if [ $# -eq 0 ];then
					echo "You must specify right parameters."
					echo "You can use -h or -H to get help."
					exit 95
				else
					filepath=$1
				fi
				shift
				
			;;
			A)    #--action,指定脚本的动作，all表示表空间和用户都创建，tablesapce表示创建表空间，user表示创建用户
				shift
				if [ $# -eq 0 ];then
					echo "You must specify right parameters."
					echo "You can use -h or -H to get help."
					exit 94
				else
					action=$1
				fi
				shift
			;;
			S)   #显示所有数据文件的路径
				ShowDatafiles
				exit
				
			;;
			*)
				echo "You must specify right parameters."
				echo "You can use -h or -H to get help."
				exit 93
			;;
		esac
	done
	
	
	#如果oracle用户被指定，则必须要要执行解锁或是查询用户是否有密码错误登录情况
	if [ -z $action ];then
		echo "You must specify right parameters."
		echo "You can use -h or -H to get help."
		exit 92
	elif [[ "$action" == "all" ]] && ([[ -z $filepath ]] || [[ -z $orauser ]]);then
		echo "You must specify right parameters."
		echo "You can use -h or -H to get help."
		exit 91
	elif [[ "$action" == "tablespace" ]] && [[ -z $filepath ]];then
		echo "You must specify right parameters."
		echo "You can use -h or -H to get help."
		exit 90
	elif [[ "$action" == "user" ]] && [[ -z $orauser ]];then
		echo "You must specify right parameters."
		echo "You can use -h or -H to get help."
		exit 89
	fi
	
	#####################################################
	#判断当前服务器是否存在指定的数据库实例，并指定SID
	if [ ! -z $orasid ];then
		if [ -z `ps -ef | grep "pmon_${orasid}" | egrep -v grep | awk -F'[ _]' '{print $NF}'` ];then
			echo "You must enter a right sid."
			exit 86
			
		else
			export ORACLE_SID=$orasid
		fi
	fi
	
	
	#####################################################
	#判断pdb是否存在
	if [ ! -z ${orapdb} ];then
		if [ -z `IsPDBExists ${orapdb}` ];then
			echo "You must enter a existed pdb name."
			exit 87
		fi
	fi
	
	userpwd=`openssl rand -base64 12`
	#echo ${userpwd}
	if [[ "$action" == "all" ]] ;then
		if [[ ${#orapdb} -gt 0 ]];then
			CT_res=`CreateTablespace $orauser $filepath ${orapdb}`
			if [ "${CT_res}" == "OK" ];then
				echo "The tablespace is created successfully."
			else
				echo -e "\e[1;33m${CT_res}\e[0m"
				exit 1
			fi
			CU_res=`CreateUser $orauser ${userpwd} ${orapdb}`
			if [ "${CU_res}" == "OK" ];then
				echo "The user is created successfully."
				echo -e "The user's name:\e[1;31m"$orauser"\e[0m, password : \e[1;31m"${userpwd}"\e[0m"
			else 
				echo -e "\e[1;33m${CU_res}\e[0m"
				exit 2
			fi
		else
			CT_res=`CreateTablespace $orauser $filepath`
			if [ "${CT_res}" == "OK" ];then
				echo "The tablespace is created successfully."
			else
				echo -e "\e[1;33m${CT_res}\e[0m"
				exit 3
			fi
			CU_res=`CreateUser $orauser ${userpwd}`
			if [ "${CU_res}" == "OK" ];then
				echo "The user is created successfully."
				echo -e "The user's name:\e[1;31m"$orauser"\e[0m, password : \e[1;31m"${userpwd}"\e[0m"
			else
				echo -e "\e[1;33m${CU_res}\e[0m"
				exit 4
			fi
#			CreateTablespace $orauser $filepath
#			CreateUser $orauser
		fi
	elif [[ "$action" == "tablespace" ]] ;then
		if [[ ${#orapdb} -gt 0 ]];then
			CT_res=`CreateTablespace $orauser $filepath ${orapdb}`
			if [ "${CT_res}" == "OK" ];then
				echo "The tablespace is created successfully."
			else
				echo -e "\e[1;33m${CT_res}\e[0m"
				exit 5
			fi
		else
			CT_res=`CreateTablespace $orauser $filepath`
			if [ "${CT_res}" == "OK" ];then
				echo "The tablespace is created successfully."
			else
				echo -e "\e[1;33m${CT_res}\e[0m"
				exit 6
			fi
		fi
	elif [[ "$action" == "user" ]] ;then
		if [[ ${#orapdb} -gt 0 ]];then
			CU_res=`CreateUser $orauser ${userpwd} ${orapdb}`
			if [ "${CU_res}" == "OK" ];then
				echo "The user is created successfully."
				echo -e "The user's name:\e[1;31m"$orauser"\e[0m, password : \e[1;31m"${userpwd}"\e[0m"
			else 
				echo -e "\e[1;33m${CU_res}\e[0m"
				exit 7
			fi
		else
			CU_res=`CreateUser $orauser ${userpwd}`
			if [ "${CU_res}" == "OK" ];then
				echo "The user is created successfully."
				echo -e "The user's name:\e[1;31m"$orauser"\e[0m, password : \e[1;31m"${userpwd}"\e[0m"
			else
				echo -e "\e[1;33m${CU_res}\e[0m"
				exit 8
			fi
		fi
	else
		echo "You must specify right parameters."
		echo "You can use -h or -H to get help."
		exit 88
	fi
	
}

###########################################
#
###########################################
main $*


