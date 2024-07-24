#!/bin/bash
#by ray
#2017-08-30
#v0.1

. ~/.bash_profile

#get sequence id that have applied.
[ -e /home/oracle/.applied_archivelog.txt ] && rm -f /home/oracle/.applied_archivelog.txt
sqlplus -s /nolog <<-RAY
conn / as sysdba
set heading off
set feedback off
set linesize 300
set pages 1000
col name for a100
spool /home/oracle/.applied_archivelog.txt
select sequence# from v\$archived_log where applied='YES' order by sequence#;
spool off
exit
RAY

[ -e /home/oracle/.applied_archivelog.txt ] && seq=`tail -2 /home/oracle/.applied_archivelog.txt | sed -n '1p'` || (echo "delete archive log failed!" >> /home/oracle/log/delete_archivelog.log ; exit 1)

logfile=/home/oracle/log/delete_archivelog_`date +%Y%m%d-%H%M%S`.log

rman target / log $logfile append <<EOF
	delete noprompt archivelog until sequence ${seq};
    crosscheck archivelog all;
	delete noprompt expired archivelog all;
    exit;
EOF

