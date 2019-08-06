#!/bin/bash
#by raysuen

prisyspwd=password
pritnsname=CMS
duplogfile=duplog_`date +%Y%m%d%H%M`.log

rman target sys/${prisyspwd}@${pritnsname} auxiliary / log ${duplogfile} append <<EOF
run {
allocate channel a1 type disk;
allocate channel a2 type disk;
allocate channel a3 type disk;
allocate channel a4 type disk;
duplicate target database for standby nofilenamecheck;
release channel a4;
release channel a3;
release channel a2;
release channel a1;
}
EOF





