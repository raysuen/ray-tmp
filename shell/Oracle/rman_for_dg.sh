#!/bin/bash
#by raysuen

logfile=rman_`date +%Y%m%d%H%M`.log
backdir=/data/rman

rman target / log ${logfile} append<<EOF
run {
allocate channel a1 type disk;
allocate channel a2 type disk;
allocate channel a3 type disk;
allocate channel a4 type disk;
backup incremental level 0 format '${backdir}/inr0_%U.bak' tag 'full_bak_for_standby' database plus archivelog;
release channel a4;
release channel a3;
release channel a2;
release channel a1;
}
backup format '${backdir}/control01.ctl' current controlfile for standby;

EOF



