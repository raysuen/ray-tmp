#!/bin/bash
# by ray
# 2016-06-16

ksfile=/tmp/.kill_session.tmp  #kill session 的文件路径
killSqlFile=/tmp/.kill_session_temptablespace_highparallel.sql  #kill脚本的路径 
killSqlHisFile=/home/oracle/shell/killSqlHisInfo.txt           #被kill的会话信息
oraUser=kcpt                 #oracle的用户名
oraPwd=zjkc_2012_PT          #oracle的密码

#函数，获取执行较长时间的sql的信息
getSqlInfo(){
	[ -e ${killSqlFile} ]&& rm -f ${killSqlFile}
	[ -e $3 ]&& rm -f $3
	sqlplus -s /nolog <<-RAY
	conn $1/$2
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
	spool $3
	select distinct b.SID,b.SERIAL\#,b.LAST_CALL_ET,a.sql_id,b.OSUSER,b.MACHINE from v\$sql a,v\$session b,v\$process p where a.SQL_ID=b.SQL_ID and b.PADDR=p.ADDR and b.STATUS=\'ACTIVE\' and b.LAST_CALL_ET>100 and b.MODULE=\'JDBC Thin Client\' order by a.sql_id,B.LAST_CALL_ET desc;
	spool off
	RAY
	#形成kill会话脚本
	awk '$0!=""{print "alter system kill session'\''"$1","$2"'\'';"}' $3 > ${killSqlFile}
	#把被kill会话的信息写入文件
	echo "#########################################################################################" >> ${killSqlHisFile}
	echo "#######################################"`date`"#######################################" >> ${killSqlHisFile}
	cat $3 >> ${killSqlHisFile}
	
}

#执行脚本的函数
execSQL(){
	sqlplus /nolog <<-RAY
	conn $1/$2
	@$3
	RAY
}

#脚本入口
getSqlInfo ${oraUser} ${oraPwd} ${ksfile} 
execSQL ${oraUser} ${oraPwd} ${killSqlFile}
[ -e ${ksfile} ]&& rm -f ${ksfile}
[ -e ${killSqlFile} ]&& rm -f ${killSqlFile}
