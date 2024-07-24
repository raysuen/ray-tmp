#!/bin/bash
#by raysuen

syspwd=password
pritnsname=ORCL
stytnsname=ORCLSTY
duplogfile=duplog_`date +%Y%m%d%H%M`.log

rman target sys/${syspwd}@${pritnsname} auxiliary sys/${syspwd}@${stytnsname} log ${duplogfile} append <<EOF
run {
allocate channel cl1 type disk;
allocate channel cl2 type disk;
ALLOCATE AUXILIARY CHANNEL c1 TYPE DISK;
ALLOCATE AUXILIARY CHANNEL c2 TYPE DISK;
duplicate target database for standby nofilenamecheck dorecover from active database;
release channel c2;
release channel c1;
release channel cl2;
release channel cl1;
}
EOF





