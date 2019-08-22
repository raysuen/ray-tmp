#!/bin/bash
# by ray
# 2016-09-19
#v0.1

#判断参数个数
if [ $# -lt 2 ];then
    echo "Parameter must be 2 or greater"
    exit 1
fi

sqlplus -s /nolog <<-RAY
conn  $1
set linesize 300
col table_name for a40
col index_name for a40
col index_type for a20
col column_name for a50
select ui.table_name,ui.INDEX_NAME,ui.INDEX_TYPE,uic.COLUMN_NAME 
from user_indexes ui,USER_IND_COLUMNS uic 
where ui.INDEX_NAME(+)=uic.INDEX_NAME and ui.TABLE_NAME=upper('$2');
RAY


#./getTableIndexInfo.sh ora_name/ora_passwd table_name
#for example : ./getTableIndexInfo.sh scott/tiger TS_NE_BATTERY_EXTREME_DETAIL