#!/bin/bash

[ -e ~/.bash_profile ]&& . ~/.bash_profile
[ -e ~/.profile ]&& . ~/.profile


tmp_sql_id=$1
sqlplus -s  / as sysdba<<EOF
set trimspool on trim on
set pages 0 linesize 1000
set long 1000000 longchunksize 1000000
SELECT dbms_sqltune.report_sql_monitor(
    sql_id => '${tmp_sql_id}',
    report_level => 'ALL',
    type=>'ACTIVE',
    base_path =>'http://www.ray/sqlmon') 
FROM dual;
EOF