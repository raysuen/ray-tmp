#!/bin/bash
#by ray
#2017/08/15

##The function is getting partition infomation
get_partiton(){
sqlplus -s /nolog <<-RAY
conn / as sysdba
spool ./.partition_info_tmp.txt
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
col PARTITION_NAME for a20
col HIGH_VALUE for a100
$1
spool off
RAY
}

##The function is that create scripts for drop partiton and tablespace
create_scripts(){
bt=`date -d "$2" +%s`  ##BeginTime
et=`date -d "$3" +%s`  ##EndTime
while read line
do
	highValue=`echo ${line} | awk '{print $4}'`
	highValue=`date -d "${highValue}" +%s`
	if [ ${highValue} -ge ${bt} ] && [ ${highValue} -le ${et} ];then
		tbName=`echo ${line} | awk '{print $1}'`
		parName=`echo ${line} | awk '{print $2}'`
		tsName=`echo ${line} | awk '{print $NF}'`
		indTsNmae=`echo ${line} | awk '{print $NF}' | awk -F'DATA' '{print $1}'`
		echo "alter table "$4"."${tbName}" drop partition "${parName}" update global indexes;" >> ./.drop_PartitonAndTablespace_tmp.sql
		echo "drop tablespace "${tsName}" including contents and datafiles;" >> ./.drop_PartitonAndTablespace_tmp.sql
		echo "drop tablespace "${indTsNmae}"INDX including contents and datafiles;" >> ./.drop_PartitonAndTablespace_tmp.sql
		
	fi
done < $1
}

##exec sql
exec_sql(){
sqlplus -s /nolog <<-RAY
conn / as sysdba
@$1
RAY
}

func_help(){
	echo " --user=user              specify a user which exist in oracle. "
	echo " --tables=all/table_name  specify a table_name or all which been owned by user that you have specified."
	echo " --btime=2010-01-01       specify a time that you want to delete the start time of parition and tablespace "
	echo " --etime=2010-01-01       specify a time that you want to delete the end time of parition and tablespace "
	echo " For example:"
	echo "     drop_cut_partition.sh --user=cut --tables=all --btime=2017-08-08 --etime=2017-08-09"
}

##check parameter
#get parameter
argvs=($@)
for i in ${argvs[@]}
do
		case `echo $i | awk -F '=' '{print $1}' | awk -F '--' '{print $2}'| tr [a-z] [A-Z]` in 
        USER)
            user=`echo $i | awk -F '=' '{print $2}' | tr [a-z] [A-Z]`
        ;;
        TABLE)
            tables=`echo $i | awk -F '=' '{print $2}' | tr [a-z] [A-Z]`
        ;;
        BTIME)
            begintime=`echo $i | awk -F '=' '{print $2}'`
        ;;
        ETIME)
            endttime=`echo $i | awk -F '=' '{print $2}'`
        ;;
        HELP)
        	func_help
        	exit 1
		esac
done

#checke parameter is null
if [ ! ${user} ]; then  
  echo "The user must be specified!"
  exit 1  
fi 
if [ ! ${tables} ]; then  
  echo "The tables must be specified to a table name or all!!"
  exit 1
fi 
if [ ! ${begintime} ]; then  
  echo "The begintime must be specified!"
  exit 1
fi 
if [ ! ${endttime} ]; then  
  echo "The endttime must be specified!"
  exit 1
fi 

#check time format
echo -e "BeginTime: \c"
date -d "${begintime}" +%Y-%m-%d  2> /dev/null
if [ $? -gt 0 ];then
	echo "Please enter right time format.Example:2017-08-01"
	exit 1
fi
echo -e "EndTime: \c"
date -d "${endttime}" +%Y-%m-%d  2> /dev/null 
if [ $? -gt 0 ];then
	echo "Please enter right time format.Example:2017-08-01"
	exit 1
fi

#check:is begintime begger then endtime
[ `date -d "${begintime}" +%s` -gt `date -d "${endttime}" +%s` ] && echo "The begintime can not bigger then endtime!"

#SQL for getting partiton info
sql_part="select TABLE_NAME,PARTITION_NAME,HIGH_VALUE,TABLESPACE_NAME from dba_tab_partitions where TABLE_owner='CUT'"
if [ ${tables} != "ALL" ];then
	sql_part=${sql_part}" and table_name="${tables}" order by TABLE_NAME;"
else
	sql_part=${sql_part}" order by TABLE_NAME;"
fi

##exec get_partiton to get partition infomation
get_partiton "${sql_part}"

#sort high value
[ -s ./.partition_info_tmp.txt ] && sort -k 1 -k 4 ./.partition_info_tmp.txt | awk '{if($4~/^[0-9]/) print}' > ./.partition_info.txt

##exec create_scripts to get scripts
create_scripts "./.partition_info.txt" "${begintime}" "${endttime}" "${user}"

##uniq executable sql file
sort ./.drop_PartitonAndTablespace_tmp.sql | uniq > ./drop_PartitonAndTablespace.sql

[ -e ./.partition_info_tmp.txt ] && rm -f ./.partition_info_tmp.txt
[ -e ./.partition_info.txt ] && rm -f ./.partition_info.txt
[ -e ./.drop_PartitonAndTablespace_tmp.sql ] && rm -f ./.drop_PartitonAndTablespace_tmp.sql


##exec script to drop partition and tablespace
exec_sql "drop_PartitonAndTablespace.sql"

[ -e ./drop_PartitonAndTablespace.sql ] && rm -f ./drop_PartitonAndTablespace.sql

