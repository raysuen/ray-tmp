#!/bin/bash
#2017-09-04
#by ray

obtain_ParNameOfMaxvalue(){
sqlplus -s /nolog <<-RAY
	conn / as sysdba
	spool /export/home/oracle/.$2
	set termout      off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool    on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long    2000000000;
	set linesize 300;
	col PARTITION_NAME for a20
	col HIGH_VALUE for a100
	$1
	spool off
RAY
}


##the function for executing split sql
exec_sql(){
sqlplus -s /nolog <<-RAY
conn / as sysdba
@$1
RAY
}


##entrance of the shell
par_table_list=/export/home/oracle/.par_table_list.txt ##this file will save all of partition table

#gets all the partitioned table
sqlplus -s /nolog <<-RAY
conn / as sysdba
	set pages 1000
	set feedback off
	set heading off
	spool ${par_table_list}
	select distinct table_owner,table_name from dba_tab_partitions where table_name not in (select object_name from dba_recyclebin) and table_owner not in ('SYS','SYSTEM','SCOTT') order by table_owner;
	spool off
RAY

##delete the space of ${par_table_list}
grep -v "^$" ${par_table_list} > ${par_table_list}.tmp
[ -e ${par_table_list} ]&& rm -rf ${par_table_list}

#spliting file
SplitingFile=/export/home/oracle/.split_partition.sql


part_name_date=$1
part_value_date=$[$part_name_date+1]

##reading file to get table name that is parition tables
while read line
do
	#set sql which be used by spliting PARTITION
	sql_part="select PARTITION_NAME,HIGH_VALUE,to_char(sysdate+${part_value_date},'yyyy-mm-dd'),to_char(sysdate+${part_name_date},'yyyymmdd') from dba_tab_partitions where 1=1 "
	username=`echo ${line} | awk '{print $1}' | tr [a-z] [A-Z]`  ##table owner
	tablename=`echo ${line} | awk '{print $2}' | tr [a-z] [A-Z]` ##table name
	sql_part=${sql_part}"and table_name='"${tablename}"' "
	sql_part=${sql_part}"and table_owner='"${username}"';"
	#echo ${sql_part}
	obtain_ParNameOfMaxvalue "${sql_part}" "${tablename}"  #specify the table name to get all partition infomation
	grep "MAXVALUE" /export/home/oracle/.${tablename} |  awk '{print "alter table ""'${username}'"".""'${tablename}'"" split partition "$1" at(to_date('\''"$3" 00:00:00'\'','\''SYYYY-MM-DD HH24:MI:SS'\'','\''NLS_CALENDAR=GREGORIAN'\'')) into (partition P_"$4",partition "$1") ;"}' >> ${SplitingFile}
	[ -e /export/home/oracle/.${tablename} ]&& rm -rf /export/home/oracle/.${tablename}
done < ${par_table_list}.tmp
[ -e ${par_table_list}.tmp ] && rm -rf ${par_table_list}.tmp

##exec split sql
exec_sql "${SplitingFile}"
[ -e ${SplitingFile} ]&& rm -rf ${SplitingFile}