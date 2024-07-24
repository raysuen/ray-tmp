#!/bin/bash
#by ray
#2017-09-29
#version 2.0

###################################################
#read configuration file
###################################################
if [ -e ~/.bash_profile ];then
	. ~/.bash_profile
fi

if [ -e ~/.profile ];then
	. ~/.profile
fi


###################################################
#functions
###################################################

###################################################
#functions for DataGuard Applied
###################################################
getDgApplied(){
	sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	set pages 10000
	col name for a100
	select dest_id,sequence#,name,applied from v\$archived_log where name is not null order by sequence#;
	exit
	RAY
}

###################################################
#functions for Tablespace usage
###################################################
getTablespaceInfo(){
	sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	set pages 10000
	col TABLESPACE_NAME for a30;
	col PCT_FREE for a10;
	col PCT_USED for a10;
	col USED_MAX% for a10
	select  a.tablespace_name,
	       round(a.bytes_alloc / 1024 / 1024, 2) megs_alloc,
	       round(nvl(b.bytes_free, 0) / 1024 / 1024, 2) megs_free,
	       round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024, 2) megs_used,
	       round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2)||'%' Pct_Free,
	       100 - round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2)||'%' Pct_used,
	       round(maxbytes/1048576,2) Max,
	       round(round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024, 2) / round((case maxbytes when 0 then a.bytes_alloc else maxbytes end)/1048576,2) * 100,2) || '%' "USED_MAX%" 
	from  ( select  f.tablespace_name,
	               sum(f.bytes) bytes_alloc,
	               sum(decode(f.autoextensible, 'YES',f.maxbytes,'NO', f.bytes)) maxbytes
	        from dba_data_files f
	        group by tablespace_name) a,
	      ( select  f.tablespace_name,
	               sum(f.bytes)  bytes_free
	        from dba_free_space f
	        group by tablespace_name) b
	where a.tablespace_name = b.tablespace_name (+)
	union all
	select h.tablespace_name,
	       round(sum(h.bytes_free + h.bytes_used) / 1048576, 2) megs_alloc,
	       round(sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / 1048576, 2) megs_free,
	       round(sum(nvl(p.bytes_used, 0))/ 1048576, 2) megs_used,
	       round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2)||'%' Pct_Free,
	       100 - round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2)||'%' pct_used,
	       round(sum(f.maxbytes) / 1048576, 2) max,
	       round(round(sum(nvl(p.bytes_used, 0))/ 1048576, 2)/round(sum(case f.maxbytes when 0 then (h.bytes_free + h.bytes_used) else f.maxbytes end) / 1048576, 2) * 100,2)||'%' "USED_MAX%" 
	from   sys.v_\$TEMP_SPACE_HEADER h, sys.v_\$Temp_extent_pool p, dba_temp_files f
	where  p.file_id(+) = h.file_id
	and    p.tablespace_name(+) = h.tablespace_name
	and    f.file_id = h.file_id
	and    f.tablespace_name = h.tablespace_name 
	group by h.tablespace_name
	ORDER BY 1;
	exit
	RAY
}

###################################################
#functions for ASM DiskGroup usage
###################################################
getAsmDiskgroup(){
	sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	select name,total_mb,free_mb from v\$asm_diskgroup;
	RAY
	exit
}

###################################################
#functions for ASM Disk infomation
###################################################
getAsmDiskInfo(){
	sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	set pages 1000
	col name for a15
	col path for a60
	select adg.name,adg.TOTAL_MB group_TOTAL_MB,adg.free_mb group_free_mb,ad.path,ad.name,ad.TOTAL_MB disk_totle_mb,ad.free_mb disk_free_mb from v$asm_diskgroup adg,v$asm_disk ad where adg.GROUP_NUMBER=ad.GROUP_NUMBER order by ad.name;
	RAY
	exit
}


###################################################
#functions for Redo Log infomation
###################################################
getRedoInfo(){
	sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 500
	set pages 1000
	col group# for 999
	col mb for 9999
	col member for a60
	col thread# for 999
	col archived for a10
	select a.group#,a.BYTES/1024/1024 mb,b.MEMBER,a.thread#,a.sequence#,a.members,a.archived,a.status,a.first_time,a.next_time from gv\$log a,gv\$logfile b where a.GROUP#=b.GROUP# group by a.group#,a.thread#,a.BYTES/1024/1024,b.MEMBER,a.sequence#,a.members,a.archived,a.status,a.first_time,a.next_time order by group#;
	exit
	RAY
}

###################################################
#functions for Redo Log shift frequency
###################################################
getRedoShiftFrequ(){
	sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	set pages 10000
	SELECT 
	to_char(first_time,'YYYY-MM-DD') day,   
	to_char(sum(decode(to_char(first_time,'HH24'),'00',1,0)),'999') "00",   
	to_char(sum(decode(to_char(first_time,'HH24'),'01',1,0)),'999') "01",   
	to_char(sum(decode(to_char(first_time,'HH24'),'02',1,0)),'999') "02",   
	to_char(sum(decode(to_char(first_time,'HH24'),'03',1,0)),'999') "03",   
	to_char(sum(decode(to_char(first_time,'HH24'),'04',1,0)),'999') "04",   
	to_char(sum(decode(to_char(first_time,'HH24'),'05',1,0)),'999') "05",   
	to_char(sum(decode(to_char(first_time,'HH24'),'06',1,0)),'999') "06",   
	to_char(sum(decode(to_char(first_time,'HH24'),'07',1,0)),'999') "07",   
	to_char(sum(decode(to_char(first_time,'HH24'),'08',1,0)),'999') "08",   
	to_char(sum(decode(to_char(first_time,'HH24'),'09',1,0)),'999') "09",   
	to_char(sum(decode(to_char(first_time,'HH24'),'10',1,0)),'999') "10",   
	to_char(sum(decode(to_char(first_time,'HH24'),'11',1,0)),'999') "11",   
	to_char(sum(decode(to_char(first_time,'HH24'),'12',1,0)),'999') "12",   
	to_char(sum(decode(to_char(first_time,'HH24'),'13',1,0)),'999') "13",   
	to_char(sum(decode(to_char(first_time,'HH24'),'14',1,0)),'999') "14",   
	to_char(sum(decode(to_char(first_time,'HH24'),'15',1,0)),'999') "15",   
	to_char(sum(decode(to_char(first_time,'HH24'),'16',1,0)),'999') "16",   
	to_char(sum(decode(to_char(first_time,'HH24'),'17',1,0)),'999') "17",   
	to_char(sum(decode(to_char(first_time,'HH24'),'18',1,0)),'999') "18",   
	to_char(sum(decode(to_char(first_time,'HH24'),'19',1,0)),'999') "19",   
	to_char(sum(decode(to_char(first_time,'HH24'),'20',1,0)),'999') "20",   
	to_char(sum(decode(to_char(first_time,'HH24'),'21',1,0)),'999') "21",   
	to_char(sum(decode(to_char(first_time,'HH24'),'22',1,0)),'999') "22",   
	to_char(sum(decode(to_char(first_time,'HH24'),'23',1,0)),'999') "23" 
	from 
	   v\$log_history   
	GROUP by 
	   to_char(first_time,'YYYY-MM-DD') order by day desc;
	exit
	RAY
}

###################################################
#functions for Tablespace include datafile infomation
###################################################
getTablespaceAndDatafile(){
	sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	set pages 1000
	col ts_name for a30
	col df_name for a100
	select ts.name ts_name,df.name df_name from v\$tablespace ts,v\$datafile df where ts.ts#=df.ts# group by ts.name,df.name order by ts.name;
	exit
	RAY
}

###################################################
#functions for executing sql
###################################################
getExecutingSQL(){
	sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 80
	set heading off
	set pages 1000
	col sid for 999999
	col SERIAL# for 99999
	col spid for 999999
	col LAST_CALL_ET for a20
	col sql_id for a20
	col status for a20
	col event for a40
	select distinct 'sid: '||b.SID,
	                'serial#: '||b.SERIAL#,
	                'spid: '||p.SPID,
	                'last_call: '||b.LAST_CALL_ET as LAST_CALL_ET,
	                'sql_id: '||a.sql_id, 
	                'status: '||b.status,
	                'event: '||b.event,
	                'module: '||b.MODULE, 
	                'os_user: '||b.OSUSER,
	                'machine: '||b.MACHINE,
	                'sql_text: '||a.sql_text 
	            from v\$sql a,v\$session b,v\$process p 
	            where a.SQL_ID=b.SQL_ID and b.PADDR=p.ADDR and b.STATUS='ACTIVE' order by LAST_CALL_ET desc;
	RAY
}

###################################################
#functions for geting full sqltext
###################################################
getFullSqlText(){
	if [ $2 == "HIST" ];then
		sqlplus -s /nolog <<-RAY
		conn / as sysdba
		set linesize 300
		set serveroutput on
		set feedback off
		spool ./$1.txt
		declare 
		l_buffer varchar2(3000);
		l_amount binary_integer :=3000;
		l_pos int :=1;
		l_clob_length int;
		sqlid varchar2(100) := '$1';
		begin
		select DBMS_LOB.getlength(sql_text) into l_clob_length from dba_hist_sqltext where sql_id=sqlid;
		while l_pos<l_clob_length loop
		select DBMS_LOB.SUBSTR(sql_text,l_amount,l_pos) into l_buffer from dba_hist_sqltext where sql_id=sqlid;
		dbms_output.put(l_buffer);
		l_pos:=l_pos+l_amount;
		end loop;
		dbms_output.put_line(' ');
		end;
		/
		spool off
		exit
		RAY
	fi
	
	if [ $2 == "MEMORY" ];then
		sqlplus -s /nolog <<-RAY
		conn / as sysdba
		set linesize 300
		set serveroutput on
		set feedback off
		spool ./$1.txt
		declare 
		l_buffer varchar2(3000);
		l_amount binary_integer :=3000;
		l_pos int :=1;
		l_clob_length int;
		sqlid varchar2(100) := '$1';
		begin
		select DBMS_LOB.getlength(sql_fulltext) into l_clob_length from v\$sqlarea where sql_id=sqlid;
		while l_pos<l_clob_length loop
		select DBMS_LOB.SUBSTR(sql_fulltext,l_amount,l_pos) into l_buffer from v\$sqlarea where sql_id=sqlid;
		dbms_output.put(l_buffer);
		l_pos:=l_pos+l_amount;
		end loop;
		dbms_output.put_line(' ');
		end;
		/
		spool off
		exit
		RAY
	fi
	
}

###################################################
#functions for indexes in table
###################################################
getIndexInTable(){
	sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	col table_name for a20
	col index_name for a30
	col index_type for a10
	col columns for a50
	select
		table_name,
    	TABLE_TYPE,
    	INDEX_NAME,
    	INDEX_TYPE,
    	TABLE_OWNER,
    	max(columns) columns
	from
	(SELECT
    	ui.table_name,
    	ui.TABLE_TYPE,
    	ui.INDEX_NAME,
    	ui.INDEX_TYPE,
    	uic.TABLE_OWNER,
    	to_char(wm_concat (uic.COLUMN_NAME) 
    	over(partition by ui.table_name,ui.TABLE_TYPE,ui.INDEX_NAME,ui.INDEX_TYPE,uic.TABLE_OWNER order by uic.COLUMN_POSITION)) columns
	FROM
    	dba_indexes ui,
    	dba_IND_COLUMNS uic
	WHERE
    	ui.INDEX_NAME (+) = uic.INDEX_NAME
		AND ui.TABLE_NAME = UPPER ('$1'))
	GROUP BY
    	table_name,
    	TABLE_TYPE,
    	INDEX_NAME,
    	INDEX_TYPE,
    	TABLE_OWNER;
	exit
	RAY
}

###################################################
#functions for geting executing plan
###################################################
getXplan(){
	if [ $2 == "CURSOR" ];then
		sqlplus -s /nolog <<-RAY
		conn / as sysdba
		set linesize 300
		set pages 10000
		spool ./$1.txt
		select * from table(dbms_xplan.display_cursor('$1',null,'advanced'));  
		spool off
		exit
		RAY
	fi
	
	if [ $2 == "AWR" ];then
		sqlplus -s /nolog <<-RAY
		conn / as sysdba
		set linesize 300
		set pages 10000
		spool ./$1.txt
		select * from table(dbms_xplan.DISPLAY_AWR('$1',format=>'advanced'));
		spool off
		exit
		RAY
	fi
}

###################################################
#functions for geting a specified partition table infomation
###################################################
getPartTableInfo(){
	sqlplus -s /nolog <<-RAY
		conn / as sysdba
		set linesize 400
		set pages 1000
		col table_owner for a10
		col table_name for a30
		col M for 9999999999
		col PARTITION_NAME for a15 
		col HIGH_VALUE for a30
		col NUM_ROWS for 9999999999
		col TABLESPACE_NAME for a15
		col COLUMN_NAME for a20
		col LAST_ANALYZED for a15
		SELECT
		    a.TABLE_OWNER,
		    a.table_name,
		    c. M,
		    a.PARTITION_NAME,
		    a.HIGH_VALUE,
		    a.NUM_ROWS,
		    a.TABLESPACE_NAME,
		    b.COLUMN_NAME,
		    A.LAST_ANALYZED
		FROM
		    dba_TAB_PARTITIONS A,
		    dba_PART_KEY_COLUMNS b,
		    (
		        SELECT
		            SUM (bytes / 1024 / 1024) M,
		            segment_name,
		            partition_name
		        FROM
		            dba_segments
		        WHERE segment_type LIKE '%TABLE%'
		        AND partition_name IS NOT NULL
		        and segment_name = upper('$1')
		        GROUP BY
		            segment_name,
		            partition_name
		        ORDER BY
		            segment_name,
		            partition_name DESC
		    ) c
		WHERE
		    A .TABLE_NAME = b. NAME(+)
		AND A .table_name = c.SEGMENT_NAME(+)
		AND A .partition_name = c.PARTITION_NAME(+)
		AND A .table_name = upper('$1')
		ORDER BY
		    A .TABLE_NAME,
		    partition_name DESC;
	RAY
}


###################################################
#functions for help
###################################################
func_help(){
	echo "Example:"
	echo "			/bin/bash oracle_ray.sh type=*******"
	echo "Parameter:"
	echo "	  type:"
	echo "		value:"
	echo "			DGAPPLIED:		to check archive logfile applied infomation for DataGuard."
	echo "			TABLESPACE:		to check tablespace usage."
	echo "			ASMDISKGROUP:	to check ASM Diskgroup usage."
	echo "			ASMDISK:		to check ASM Disk infomation."
	echo "			REDOINFO:		to get redo log infomation."
	echo "			REDOSHIFT		to get redo logfile shift frequency."
	echo "			TSDF			to get datafiles for tablespace."
	echo "			EXECNOW:		to get executing sql."
	echo "			FULLSQL:		to get full sql text,the parameter must be used with from and sqlid."
	echo "							the parameter only use MEMORY/memory/HIST/hist for from."
	echo "				Example:	/bin/bash oracle_ray.sh ype=FULLSQL from=memory sqlid=********"
	echo "			INDEX:			to get indexes for a tables,the parameter must be used with table."
	echo "				Example:	/bin/bash oracle_ray.sh type=INDEX table=*********"
	echo "			XPLAN:			to get executing plan for a sql,the parameter must be used with from and sqlid."
	echo "							the parameter only use CURSOR/cursor/AWR/awr for from."
	echo "							Even you can't use this parameter,from.Cause,there is default value,cursor,for from."
	echo "				Example:	/bin/bash oracle_ray.sh type=XPLAN from=cursor sqlid=****"
	echo "							/bin/bash oracle_ray.sh type=XPLAN sqlid=****"
	echo "			PARTITIONINFO	to get all of partition which will be specified infomation"
	echo "							the parameter must be used with table."
	echo "				Example:	/bin/bash oracle_ray.sh type=PARTITIONINFO table=**********"
	echo "	  from:"
	echo "		value:"
	echo "			HIST:			to get full sql text from history table."
	echo "			MEMORY:			to get full sql text from memory."
	echo "			CURSOR:			to get Xplan text from memory."
	echo "			AWR:			to get Xplan from awr view."
	echo "	  sqlid:				specify a sql id."
	echo "	  table:				specify a table name."
	echo ""
	echo ""
}


###################################################
#get parameter
###################################################
argvs=($@)
for i in ${argvs[@]}
do
        case `echo $i | awk -F= '{print $1}' | tr [a-z] [A-Z]` in 
        TYPE)
            ExecType=`echo $i | awk -F= '{print $2}' | tr [a-z] [A-Z]`
        ;;
        FROM)
            fm=`echo $i | awk -F= '{print $2}' | tr [a-z] [A-Z]`
        ;;
        SQLID)
            sqlid=`echo $i | awk -F= '{print $2}' `
        ;;
        TABLE)
            tname=`echo $i | awk -F= '{print $2}' | tr [a-z] [A-Z] `
        ;;
        HELP)
        	if [ ! `echo $i | awk -F= '{print $2}' | tr [a-z] [A-Z]` ];then
        		echo "If you want to get help,pleas use help=y!"
        		exit 1
        	elif [ `echo $i | awk -F= '{print $2}' | tr [a-z] [A-Z]` == 'Y' ];then
            	func_help
            	exit 0
            else
            	echo "If you want to get help,pleas use help=y!"
            	exit 1
            fi
        esac
done

###################################################
#To judge whether the type is empty
###################################################
if [ ! ${ExecType} ]; then  
    echo "The TYPE must be specified!!"
    exit 2
fi

###################################################
#exec function
###################################################
case ${ExecType} in
DGAPPLIED)
	getDgApplied
	;;
TABLESPACE)
	getTablespaceInfo
	;;
ASMDISKGROUP)
	getAsmDiskgroup
	;;
ASMDISK)
	getAsmDiskInfo
	;;
REDOINFO)
	getRedoInfo
	;;
REDOSHIFT)
	getRedoShiftFrequ
	;;
TSDF)
	getTablespaceAndDatafile
	;;
EXECNOW)
	getExecutingSQL
	;;
PARTITIONINFO)
	if [ ! ${tname} ];then
    	echo "The table of parameter must be specified!!"
    	echo ""
    	exit 3
	else
    	getPartTableInfo "${tname}"
    fi 
	;;
FULLSQL)
	if [ ! ${fm} ];then
		echo "The from of parameter must be specified!"
	elif [ ${fm} == "HIST" ];then
     	getFullSqlText "${sqlid}" "HIST"
 	elif [ ${fm} == "MEMORY" ];then
     	getFullSqlText "${sqlid}" "MEMORY"
 	else
     	echo "The from of parameter only is HIST or MEMORY!!"
     	echo ""
     	exit 4
 	fi
	;;
INDEX)
	if [ ! ${tname} ];then
    	echo "The table of parameter must be specified!!"
    	echo ""
    	exit 5
	else
    	getIndexInTable "${tname}"
    fi
	;;
XPLAN)
    if [ ! ${sqlid} ];then
    	echo "The sqlid of parameter must be specified!!"
    	echo ""
    	exit 6
    else
    	if [ ! ${fm} ];then
    		getXplan "${sqlid}" "CURSOR"
    	elif [ ${fm} == "CURSOR" ];then
    		getXplan "${sqlid}" "CURSOR"
    	elif [ ${fm} == "AWR" ];then
    		getXplan "${sqlid}" "AWR"
    	else
    		echo "The from of parameter only are cursor or awr!!"
    	fi
    fi
	;;
*)
    echo "You have entered a invalid parameter value!!"
	echo "If you want to help, You can use the parameter: --help ."
	;;
esac


#if [ ${ExecType} == "DGAPPLIED" ];then
#    getDgApplied
#elif [ ${ExecType} == "TABLESPACE" ];then
#    getTablespaceInfo
#elif [ ${ExecType} == "ASMDISKGROUP" ];then
#    getAsmDiskgroup
#elif [ ${ExecType} == "REDOINFO" ];then
#    getRedoInfo
#elif [ ${ExecType} == "REDOSHIFT" ];then
#    getRedoShiftFrequ
#elif [ ${ExecType} == "TSDF" ];then
#    getTablespaceAndDatafile
#elif [ ${ExecType} == "EXECNOW" ];then
#    getExecutingSQL
#elif [ ${ExecType} == "FULLSQL" ];then
#    if [ ${fm} == "HIST" ];then
#    	getFullSqlText "${sqlid}" "HIST"
#	elif [ ${fm} == "MEMORY" ];then
#    	getFullSqlText "${sqlid}" "MEMORY"
#	else
#    	echo "The from of parameter only is HIST or MEMORY!!"
#    	echo ""
#    	exit 2
#	fi
#elif [ ${ExecType} == "INDEX" ];then
#    if [ ! ${tname} ];then
#    	echo "The table of parameter must be specified!!"
#    	echo ""
#    	exit 3
#    else
#    	getIndexInTable "${tname}"
#    fi
#elif [ ${ExecType} == "XPLAN" ];then
#    if [ ! ${sqlid} ];then
#    	echo "The sqlid of parameter must be specified!!"
#    	echo ""
#    	exit 4
#    else
#    	if [ ! ${fm} ];then
#    		getXplan "${sqlid}" "CURSOR"
#    	elif [ ${fm} == "AWR" ];then
#    		getXplan "${sqlid}" "AWR"
#    	else
#    		echo "The from of parameter only are cursor or awr!!"
#    	fi
#    fi
#else
#    echo "You have entered a invalid parameter value!!"
#    echo "If you want to help, You can use the parameter: --help ."
#fi