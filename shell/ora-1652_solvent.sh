#!/bin/bash
# by ray
# 2016-05-19

export ORACLE_BASE=/u01/oracle
export ORACLE_HOME=$ORACLE_BASE/11g
export ORACLE_SID=RACDB1
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/bin:/bin:/usr/bin:/usr/local/bin:$ORACLE_HOME/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export NLS_LANG="AMERICAN_AMERICA.ZHS16GBK"

[ -e /tmp/kill_session_temptablespace.sql ]&& rm -f /tmp/kill_session_temptablespace.sql

sqlplus /nolog <<EOF
conn kcpt/zjkc_2012_PT
@/home/oracle/shell/ora-1652_solvent.sql
@/tmp/kill_session_temptablespace.sql
EOF

[ -e /tmp/kill_session_temptablespace.sql ]&& rm -f /tmp/kill_session_temptablespace.sql
