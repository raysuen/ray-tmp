#!/bin/bash

#kingbase clean wal

export KINGBASE_HOME=/home/kingbase/cluster/KBP01/KBC01/kingbase/
export KINGBASE_DATA=/home/kingbase/cluster/KBP01/KBC01/kingbase/data
export ARCHIVE_DIR=`egrep "^archive_command" /home/kingbase/cluster/KBP01/KBC01/kingbase/data/es_rep.conf | awk -F'%p' '{print $NF}'`

LASTWAL = `$KINGBASE_HOME/bin/sys_controldata -D $KINGBASE_DATA | grep -E "最新检查点的重做日志文件| REDO WAL file" | awk '{print $2}'`

echo $LASTWAL

$KINGBASE_HOME/bin sys_archivecleanup -d $ARCHIVE_DIR $LASTWAL




