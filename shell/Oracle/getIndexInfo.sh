#!/bin/bash
# by ray
# 2016-10-20
#v0.1

#判断参数个数
if [ $# -ne 1 ];then
    echo "Parameter is err"
    exit 1
fi

sqlplus -s /nolog <<-RAY
conn  / as sysdba
set linesize 300
col table_name for a40
col index_name for a40
col index_type for a20
col column_name for a50
select ui.table_name,ui.TABLE_TYPE,ui.INDEX_NAME,ui.INDEX_TYPE,uic.COLUMN_NAME
from dba_indexes ui,dba_IND_COLUMNS uic
where ui.INDEX_NAME(+)=uic.INDEX_NAME and ui.INDEX_NAME=upper('$1');
exit;
RAY



