#!/bin/bash

sessionFile=/tmp/.killLockedSession.txt
killSql=/tmp/.killLockedSession.sql
killSqlHisFile=/home/oracle/killLockedSessionHisFile.txt

#函数，获取执行较长时间的sql的信息
getSessionInfo(){
        [ -e ${sessionFile} ]&& rm -f ${sessionFile}
        [ -e ${killSql} ]&& rm -f ${killSql}  
		sqlplus -s /nolog <<-RAY
		conn / as sysdba
		set termout off;
        set echo off;
        set feedback off;
        set verify off;
        set heading off;
        set wrap on;
        set trimspool on;
        set serveroutput on;
        set escape on;
        set pagesize 50000;
        set long 2000000000;
        set linesize 300;
		spool ${killSql}
		SELECT
		s1.SID
		||','
		||s1.SERIAL# kill_string
		FROM
		v\$lock l1,
		v\$session s1,
		v\$lock l2,
		v\$session s2,
		v\$locked_object lo,
		dba_objects DO
		WHERE
		s1.SID    =l1.SID
		AND s2.SID   =l2.SID
		AND l1.ID1   =l2.ID1
		AND s1.SID   =lo.SESSION_ID
		AND lo.OBJECT_ID=do.OBJECT_ID
		AND l1.BLOCK  =1
		AND l2.REQUEST >0;
		spool off
		exit
		RAY
        
}

getSqlInfo()
{
		#形成kill会话脚本
        awk '$0!="" {print "alter system kill session '\''"$1"'\'';"}' ${sessionFile} > ${killSql}
        #把被kill会话的信息写入文件
        echo "#########################################################################################" >> ${killSqlHisFile}
        echo "#######################################"`date`"#######################################" >> ${killSqlHisFile}
        cat ${killSql} >> ${killSqlHisFile}

}


#执行脚本的函数
execSQL(){
        sqlplus -s /nolog <<-RAY
        conn / as sysdba
        @${killSql}
        exit
        RAY
}

#脚本入口
while true
do
	getSessionInfo
	if [ -e ${sessionFile} ];then
			getSqlInfo
	else
			sleep 10s
			continue
	fi
	execSQL
	[ -e ${sessionFile} ]&& rm -f ${sessionFile}
    [ -e ${killSql} ]&& rm -f ${killSql}
    sleep 10s 
done




