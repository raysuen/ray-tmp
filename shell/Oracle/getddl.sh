#!/bin/bash
# author by ray
# v6

source ~/.bash_profile
export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK

#定义获取ddl的函数
getOracleTableDDL(){
	userpass=$1
	tname=$2
	sqlplus -s /nolog <<-RAY
	conn $userpass
	spool $3/${tname}.sql
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',false);
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'CONSTRAINTS',false);
	select DBMS_METADATA.GET_DDL('TABLE',upper('${tname}')) from dual;
	select 'comment on table '||TABLE_NAME||' is '||chr(39)||COMMENTS||chr(39)||';' from user_tab_comments where table_name=upper('${tname}');
	SELECT 'comment on column ' ||table_name||'.'||column_name|| ' ' || 'is' ||' ' || '''' || comments || ''''||';'    FROM USER_col_COMMENTS where table_name=upper('${tname}');
	select DBMS_METADATA.GET_DDL('INDEX',INDEX_NAME) from user_indexes where TABLE_NAME=upper('${tname}');
	select DBMS_METADATA.GET_DDL('CONSTRAINT',CONSTRAINT_NAME) from USER_CONSTRAINTS where TABLE_NAME=upper('${tname}');
	spool off;
	exit;
	RAY
	oraname=`echo ${userpass} | awk -F "/" '{print $1}' | tr [a-z] [A-Z]`
	#sed -i "s/\"${username}\"\.//g" $3/${tname}.sql
	sed -i 's/\"'${oraname}'\"\.//g' $3/${tname}.sql
	#sed -i "s/\"KCPT\"\.//g" $3/${tname}.sql
    	sed -i "s/\"//g" $3/${tname}.sql
}

getOracleIndexDDL(){
	userpass=$1
	Iname=$2
	sqlplus -s /nolog <<-RAY
	conn $userpass
	spool $3/${tname}.sql
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',false);
	select DBMS_METADATA.GET_DDL('INDEX',upper('${Iname}')) from dual;
	spool off;
	exit;
	RAY
	oraname=`echo ${userpass} | awk -F "/" '{print $1}' | tr [a-z] [A-Z]`
	#sed -i "s/\"${username}\"\.//g" $3/${tname}.sql
	sed -i 's/\"'${oraname}'\"\.//g' $3/${tname}.sql
	#sed -i "s/\"KCPT\"\.//g" $3/${tname}.sql
    	sed -i "s/\"//g" $3/${tname}.sql
}

getOracleViewDDL(){
	userpass=$1
	Vname=$2
	sqlplus -s /nolog <<-RAY
	conn $userpass
	spool $3/${tname}.sql
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
	SELECT DBMS_METADATA.GET_DDL('VIEW',upper('${Vname}')) FROM DUAL;
	spool off;
	exit;
	RAY
	oraname=`echo ${userpass} | awk -F "/" '{print $1}' | tr [a-z] [A-Z]`
	#sed -i "s/\"${username}\"\.//g" $3/${tname}.sql
	sed -i 's/\"'${oraname}'\"\.//g' $3/${tname}.sql
	#sed -i "s/\"KCPT\"\.//g" $3/${tname}.sql
    	sed -i "s/\"//g" $3/${tname}.sql
}

getOracleUserDDL(){
	userpass=$1
	Uname=$2
	sqlplus -s /nolog <<-RAY
	conn $userpass
	spool $3/${Uname}.sql
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
	SELECT DBMS_METADATA.GET_DDL('USER',upper('${Uname}')) FROM DUAL;
	SELECT 'grant ' || tt.granted_role || ' to ' || tt.grantee || ';' AS SQL_text FROM dba_role_privs tt WHERE tt.grantee = (UPPER('kcpt'))
	UNION ALL
	SELECT 'grant ' || tt. PRIVILEGE || ' to ' || tt.grantee || ';' FROM dba_sys_privs tt WHERE tt.grantee = (UPPER('kcpt'))
	UNION ALL
	SELECT 'grant ' || tt. PRIVILEGE || ' on ' || OWNER || '.' || table_name || ' to ' || tt.grantee || ';' FROM dba_tab_privs tt WHERE tt.grantee = (UPPER('kcpt'));
	spool off;
	exit;
	RAY
}

getOracleTablespaceDDL(){
	userpass=$1
	Tname=$2
	sqlplus -s /nolog <<-RAY
	conn $userpass
	spool $3/${Tname}.sql
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',false);
	SELECT DBMS_METADATA.GET_DDL('TABLESPACE','${Tname}') FROM DUAL;
	spool off;
	exit;
	RAY
}

getOracleSequenceDDL(){
	userpass=$1
	Sname=$2
	sqlplus -s /nolog <<-RAY
	conn $userpass
	spool $3/${Sname}.sql
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',false);
	SELECT DBMS_METADATA.GET_DDL('SEQUENCE','${Sname}') FROM DUAL;
	spool off;
	exit;
	RAY
	oraname=`echo ${userpass} | awk -F "/" '{print $1}' | tr [a-z] [A-Z]`
	#sed -i "s/\"${username}\"\.//g" $3/${tname}.sql
	sed -i 's/\"'${oraname}'\"\.//g' $3/${tname}.sql
	#sed -i "s/\"KCPT\"\.//g" $3/${tname}.sql
    	sed -i "s/\"//g" $3/${tname}.sql
}

getOracleFunctionDDL(){
	userpass=$1
	Fname=$2
	sqlplus -s /nolog <<-RAY
	conn $userpass
	spool $3/${Fname}.sql
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',false);
	SELECT DBMS_METADATA.GET_DDL('FUNCTION','${Fname}') FROM DUAL;
	spool off;
	exit;
	RAY
	oraname=`echo ${userpass} | awk -F "/" '{print $1}' | tr [a-z] [A-Z]`
	#sed -i "s/\"${username}\"\.//g" $3/${tname}.sql
	sed -i 's/\"'${oraname}'\"\.//g' $3/${tname}.sql
	#sed -i "s/\"KCPT\"\.//g" $3/${tname}.sql
    	sed -i "s/\"//g" $3/${tname}.sql
}

getOracleProcedureDDL(){
	userpass=$1
	Pname=$2
	sqlplus -s /nolog <<-RAY
	conn $userpass
	spool $3/${Pname}.sql
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
	EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',false);
	SELECT DBMS_METADATA.GET_DDL('PROCEDURE','${Pname}') FROM DUAL;
	spool off;
	exit;
	RAY
	oraname=`echo ${userpass} | awk -F "/" '{print $1}' | tr [a-z] [A-Z]`
	#sed -i "s/\"${username}\"\.//g" $3/${tname}.sql
	sed -i 's/\"'${oraname}'\"\.//g' $3/${tname}.sql
	#sed -i "s/\"KCPT\"\.//g" $3/${tname}.sql
    	sed -i "s/\"//g" $3/${tname}.sql
}


getDDL(){
	objectname=$2
    	if [ -e ${objectname} ];then
        	for line in `cat $2`
        	do
            		$5 $1 ${line} $3
       		done
        	ls $3/*.sql | xargs cat >> $3/$4
        	rm -rf $3/*.sql
    	else
        	arr=(${objectname//,/ })
        	for line in ${arr[@]}
        	do
            		$5 $1 ${line} $3
            		ls $3/*.sql | xargs cat >> $3/$4
            		rm -rf $3/*.sql
        	done
    	fi
}

#循环获取参数
argvs=($@)
for i in ${argvs[@]}
do	
	case `echo $i | awk -F '=' '{print $1}' | awk -F '--' '{print $2}'| tr [a-z] [A-Z]` in 
		USERPASS)
			up=`echo $i | awk -F '=' '{print $2}'`
		;;
		OBJECT)
			obj=`echo $i | awk -F '=' '{print $2}'`
		;;
		SAVEPATH)
			sp=`echo $i | awk -F '=' '{print $2}'`
		;;
		SAVEFILE)
			sf=`echo $i | awk -F '=' '{print $2}'`
		;;
		TYPE)
			tp=`echo $i | awk -F '=' '{print $2}'`
		;;
	esac
done


#判断变量是否为空，为空报错退出
if [ ! ${up} ]; then  
	echo "user and pass is error"
	exit 1  
fi 
if [ ! ${obj} ]; then  
  echo "object is error"
  exit 1
fi 
if [ ! ${sp} ]; then  
  echo "savepath is error"
  exit 1
fi 
if [ ! ${sf} ]; then  
  echo "savefile is error"
  exit 1
fi 
if [ ! ${tp} ]; then  
  echo "type is error"
  exit 1
fi


#判断导出类型的个数
num=(${tp//,/ })
if [[ ${#num[@]} -gt 1 ]];then
	echo "No more than one type of parameters"
	exit 1
fi
#脚本的入口，调用函数获取DDL语句
case `echo ${tp} | tr [a-z] [A-Z]` in
	TABLE)
		getDDL ${up} ${obj} ${sp} ${sf} getOracleTableDDL
	;;
	INDEX)
		getDDL ${up} ${obj} ${sp} ${sf} getOracleIndexDDL
	;;
	VIEW)
		getDDL ${up} ${obj} ${sp} ${sf} getOracleViewDDL
	;;
	USER)
		getDDL ${up} ${obj} ${sp} ${sf} getOracleUserDDL
	;;
	TABLESPACE)
		getDDL ${up} ${obj} ${sp} ${sf} getOracleTablespaceDDL
	;;
	SEQUENCE)
		getDDL ${up} ${obj} ${sp} ${sf} getOracleSequenceDDL
	;;
	FUNCTION)
		getDDL ${up} ${obj} ${sp} ${sf} getOracleFunctionDDL
	;;
	PROCEDURE)
		getDDL ${up} ${obj} ${sp} ${sf} getOracleProcedureDDL
	;;
esac




#for n in `echo $i | awk -F '=' '{split($2,a,",")}END{for(i in a)print a[i]}'`  #有序awk -F '=' '{d=split($2,a,",")}END{for(c=0;c++<d;)print a[c]}'
##使用方法的例子
#./getddl.sh --userpass=kcbs/zjkc_2012_PT --type=table --savepath=/home/oracle/shell --savefile=aa.txt --object=/home/oracle/shell/tablename.txt
	#--type可以选择TABLE，INDEX，VIEW，USER，TABLESPACE，SEQUENCE，FUNCTION，PROCEDURE
	#--savepath 不用/结束
	#--object可以用多个，可以单个，也可以用文件
#./getddl.sh kcpt/zjkc_2012_PT /home/oracle/shell/tablename.txt /home/oracle/shell sqlfile.txt  #参数1用户名密码，参数2存放表名的文件，参数3存放导出ddl的目录不已/结束，参数4最后形成的sql文件
#./getddl.sh kcpt/zjkc_2012_PT LY_ADVANCE_MONEY ~/sql/LY_ADVANCE_MONEY.sql #参数1用户名密码，参数2检索的关键字,参数3最后形成的文件
#ls sql/*.sql | xargs cat >> sql/tmp.txt   