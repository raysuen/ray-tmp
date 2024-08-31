#!/bin/bash

. ~/.bash_profile

SQLPLUS=/u01/oracle/product/11.2.0/db_1/bin/sqlplus
RACNUM=2

getAppliedArchNum(){
	${SQLPLUS} -s /nolog<<EOF
	conn / as sysdba
	set heading off
	set feedback off
	select 'delete noprompt archivelog until sequence '||(MAX(SEQUENCE#)-3)||'  thread '||thread#||';' from v\$archived_log where applied='YES' GROUP by  THREAD#;
EOF

}

rmanDelArch(){
	rman target /<<EOF
	$1
EOF
}

#DelArchSQL=`getAppliedArchNum`
#echo `getAppliedArchNum` | awk -F';' '{print $1";"}'
#echo `getAppliedArchNum` | awk -F';' '{print $2";"}'

#rmanDelArch "crosscheck copy;"

for ((i=1;i<=$RACNUM;i++))
do
	DelArchSQL=$(echo `getAppliedArchNum` | awk -F';' '{print $'$i'";"}')
	rmanDelArch "$DelArchSQL"
	#echo $DelArchSQL 
done


