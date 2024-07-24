#!/bin/bash

#use Oracle Env.
source ~/.bash_profile


#Def backupdir
dirname=`date "+%Y-%U"`
lastweek=`date -d "-1 week" +%Y-%U`
backupdir=/u01/rman/${dirname}
rmdiractory=/u01/rman/${lastweek}
#check backdir
if [ ! -d $backupdir ];then
    mkdir -p $backupdir
fi


#
#Get Time And Set Backup Level.
#
Dayname=`date +%a`
if [ $Dayname = 'Sun' ]; then
        Level=0
   elif [ $Dayname = 'Thu' ];then
        Level=1
   else 
        Level=2
fi

#Wed means wedsday

#
#Define Backup Type.
#
if [ $Level = 0 ]; then  
        BACKUP_TYPE="incremental level 0" 
   elif [ $Level = 1 ]; then      
        BACKUP_TYPE="incremental level 1"
   else
        BACKUP_TYPE="incremental level 2"
fi

#
#Log.
#
logdate=`date +"%Y%m%d"`
logdate2=`date +%F`
logfile=$backupdir/racdb_rman_"$logdate".log
echo `date +'%Y%m%d %T'`' start backup-----' >> $logfile
cat >$logfile <<EOF
#
#This is RMAN Backup log.
#
#Today is $logdate2,$Dayname.The RMAN Backup Level is $Level and Backup type is $BACKUP_TYPE.
#
#RMAN Bakcup Process starting.
EOF

#backup body
rman target / log $logfile append <<EOF
     run{
        allocate channel a1 type disk;
		allocate channel a2 type disk;
		allocate channel a3 type disk;
        crosscheck backup;
        delete noprompt expired backup;
        crosscheck archivelog all;
        delete noprompt expired archivelog all;
        backup as compressed backupset $BACKUP_TYPE database  format '${backupdir}/incr${Level}_%T_%d_%s_%p.bak' filesperset=8;
        sql 'alter system archive log current';
        backup as compressed backupset archivelog all format  '${backupdir}/arc_%T_%d_%s_%p.bak' delete all input;
        backup current controlfile format '${backupdir}/ctl_%T_%d_db_%s_%p.bak';
        release channel a1;
		release channel a2;
		release channel a3;
        }
EOF
echo `date +'%Y%m%d %T'`' end backup-----' >> $logfile
#delete last week backup.
if [ -d ${rmdiractory} ];then
#	echo 2 >> $logfile
	rm -rf ${rmdiractory}
	echo `date +'%Y%m%d %T'`' end rm_his-----' >> $logfile
fi


##send mail to smc,if it have some error in backing
#if [ -e ${logfile} ];then
#	sum=`cat ${logfile} | grep -E "RMAN-|ORA-"|wc -l`
#        if [ ${sum} -gt 0 ];then
#                sh /home/oracle/shell/mail_pl.sh "smc@transilink.com" 'oracle北京45备份报警' "`cat ${logfile} | grep -E 'RMAN-|ORA-'`" "${logfile}" > /home/oracle/shell/mail_rman.log
#                while true
#                do
#                        mail_status=`cat /home/oracle/shell/mail_rman.log | awk -F ':' '{print $NF}' | awk '{print $NF}' |awk -F'!' '{print $1}'`
#                        if [ "${mail_status}" = "successfully" ];then
#                                echo 'mail is ok!'
#                        break
#                else
#                        echo 'mail is failed'
#                        sh /home/oracle/shell/mail_pl.sh "smc@transilink.com" 'oracle北京45备份报警' "`cat ${logfile} | grep -E 'RMAN-|ORA-'`" "${logfile}" > /home/oracle/shell/mail_rman.log
#                        sleep 20s
#                        continue
#                        fi
#                done
#        else
#                sh /home/oracle/shell/mail_pl.sh "smc@transilink.com" 'oracle北京45备份成功' "${logfile}" "${logfile}" > /home/oracle/shell/mail_rman.log
#                while true
#                do
#                        mail_status=`cat /home/oracle/shell/mail_rman.log | awk -F ':' '{print $NF}' | awk '{print $NF}' |awk -F'!' '{print $1}'`
#                        if [ "${mail_status}" = "successfully" ];then
#                                echo 'mail is ok!'
#                        break
#                else
#                        echo 'mail is failed'
#                        sh /home/oracle/shell/mail_pl.sh "smc@transilink.com" 'oracle北京45备份成功' "${logfile}" "${logfile}" > /home/oracle/shell/mail_rman.log
#                        sleep 20s
#                        continue
#                        fi
#                done
#        fi
#fi
#
#exit 0

