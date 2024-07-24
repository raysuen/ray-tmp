#!/bin/bash
# by ray
# 2017-08-31
#v0.1

##get sqltext from dbs_hist_sqltext,sqltext will be save current directory and file name will be sql_id.txt
FromHist(){
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
}


##get sqltext from V$sqlarea,sqltext will be save current directory and file name will be sql_id.txt
FromMomery(){
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
}

func_help(){
	echo "--from        specifying how to get sqltext,memery or hist can be used.default momery!!"
    echo "--sqlid        specify a sql_id"
    echo "for example:"
    echo "get_fulltext.sh --from=momery --sqlid=*********"
}

#get parameter
argvs=($@)
for i in ${argvs[@]}
do
        case `echo $i | awk -F '=' '{print $1}' | awk -F '--' '{print $2}'| tr [a-z] [A-Z]` in 
        FROM)
            fm=`echo $i | awk -F '=' '{print $2}' | tr [a-z] [A-Z]`
        ;;
        SQLID)
            sqlid=`echo $i | awk -F '=' '{print $2}' `
        ;;
        HELP)
            func_help
            exit 1
        esac
done

if [ ! ${fm} ]; then  
    fm='MOMERY'
fi 
if [ ! ${sqlid} ]; then  
    echo "The sql_id must be specified!!"
    exit 1
fi

##exec script
if [ ${fm} == "HIST" ];then
    FromHist "${sqlid}"
elif [ ${fm} == "MOMERY" ];then
    FromMomery "${sqlid}"
else
    echo "then type of parameter only are HIST or MOMERY!!"
fi



