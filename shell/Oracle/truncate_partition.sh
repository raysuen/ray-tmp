#!/bin/bash
# by ray
# 2016-06-08

. ~/.bash_profile
export NLS_LANG="AMERICAN_AMERICA.ZHS16GBK"
todayUtc=`date +%s000`   #获取毫秒的utc时间
tdate=`date +%F-%H%M%S`    #获取当前时间
days=185   #指定向前的天数，以获取保留的分区数
truncdir=/tmp/truncpar

if [ ! -d ${truncdir} ];then
    mkdir -p ${truncdir}
fi


#获取所有分区表的函数
getParTableInfo(){
	[ -e ${truncdir}/.partable.tmp ]&& rm -f ${truncdir}/.partable.tmp  #检查文件是否存在，删除存在的文件
	[ -e ${truncdir}/.partable.txt ]&& rm -f ${truncdir}/.partable.txt
	#获取所有分区表的表名和用户名称
	sqlplus -s /nolog <<-RAY
	conn $1/$2@$3
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	spool ${truncdir}/.partable.tmp;
	select DISTINCT A.TABLE_NAME from user_TAB_PARTITIONS A ;
	spool off
	RAY
	grep "^[A-Z]" ${truncdir}/.partable.tmp > ${truncdir}/.partable.txt
	[ -e ${truncdir}/.partable.tmp ]&& rm -f ${truncdir}/.partable.tmp
}


#获取某个表的所有分区信息
getPartitionInfo(){
	[ -e ${truncdir}/.$1-$3-$4.tmp ]&& rm -f ${truncdir}/.$1-$3-$4.tmp
	[ -e ${truncdir}/.$1-$3-$4.txt ]&& rm -f ${truncdir}/.$1-$3-$4.txt   #检查文件是否存在，文件的命名规则是oracleuser-tnsname-tablename.txt,例如kcpt-RACDB-th_vehicle_alarm.TXT用户kcpt,tns连接字符串为RACDB,表名为th_vehicle_alarm
	sqlplus -s /nolog <<-RAY
	conn $1/$2@$3
	set termout       off;
	set echo          off;
	set feedback      off;
	set verify        off;
	set heading off;
	set wrap          on;
	set trimspool     on;
	set serveroutput  on;
	set escape        on;
	set pagesize 50000;
	set long     2000000000;
	set linesize 300;
	spool ${truncdir}/.$1-$3-$4.tmp;
	SELECT a.table_name,a.PARTITION_NAME,a.HIGH_VALUE
	FROM dba_TAB_PARTITIONS A
	WHERE A .table_name = '$4';
	spool off
	RAY
	grep "^$4" ${truncdir}/.$1-$3-$4.tmp | sort -n -k 3 | awk '{print NR","$1","$2","$3}' > ${truncdir}/.$1-$3-$4.txt
	[ -e ${truncdir}/.$1-$3-$4.tmp ]&& rm -f ${truncdir}/.$1-$3-$4.tmp
}

#函数：获取备份命令
getExpdpParCommandAndTruncSql(){
	#循环获取表名
	for i in `cat ${truncdir}/.partable.txt`
	do
		un=$1
		up=$2
		tn=$3
		dn=$4
		getPartitionInfo $1 $2 $3 $i
		for j in `cat ${truncdir}/.$1-$3-$i.txt`
    	do
    		utc=`echo $j | awk -F ',' '{print $4}'`
    		if [[ ${utc} -ge ${todayUtc} ]];then
    			linenum=`echo $j | awk -F ',' '{print $1}'`     #获取表内highvalue值大于当前utc时间的分区的行号
    			linenum=$[$linenum-$days]                       #获取表内highvalue值大于当前utc时间减去指定的天数的分区的行号
            	dumpnum=$[$linenum+2]                           #获取备份的分区表的行号
            	if [[ ${dumpnum} -lt 1  ||  ${linenum} -lt 1 ]];then                  #当行号小于1时推出当前循环
                	continue
                else
                	#获取expdp命令，把命令写入文件
                	#sed -n "${dumpnum}p" ${truncdir}/.$1-$3-$i.txt | awk -F ',' '{print "expdp '${un}'/'${up}' directory=expdp network_link='${dn}' dumpfile='${tn}'-"$2"-"$3"-'${tdate}'.dmp logfile='${tn}'-"$2"-"$3"-'${tdate}'.log tables="$2":"$3}' >> ${truncdir}/ExpdpPar.cmd
                	sed -n "${dumpnum}p" ${truncdir}/.$1-$3-$i.txt | awk -F ',' '{print "expdp '${un}'/'${un}' directory=expdp network_link='${dn}' dumpfile='${tn}'-"$2"-"$3"-'${tdate}'.dmp logfile='${tn}'-"$2"-"$3"-'${tdate}'.log tables="$2":"$3}' >> ${truncdir}/ExpdpPar.cmd
                	#获取truncate命令，把命令写入文件
                	sed -n "${linenum}p" ${truncdir}/.$1-$3-$i.txt | awk -F ',' '{print "alter table "$2" truncate partition "$3" update global indexes;"}' >> ${truncdir}/truncPar.sql
                	#expdpcommand=`sed -n "${dumpnum}p" ${truncdir}/.$1-$3-$i.txt | awk -F ',' '{print "expdp '${un}'/'${up}' director=expdp network_link='${dn}' dumpfile='${tn}'-"$2"-"$3"-'${tdate}'.dmp logfile='${tn}'-"$2"-"$3"-'${tdate}'.log tables="$2":"$3}'`
                	#echo ${expdpcommand} >> ${truncdir}/ExpdpPar.cmd
                	break
                	#rm -rf ${truncdir}/.$1-$3-$i.txt
            	fi
    		fi
    	done
	done
}

#函数:执行指定sql
execSQL(){
	sqlplus /nolog <<-RAY
	conn $1/$2@$3
	@$4
	RAY
}

#脚本入口
#循环参数文件的内容
for f in `cat $1`
do
	[ -e ${truncdir}/ExpdpPar.cmd ]&& rm -f ${truncdir}/ExpdpPar.cmd
	[ -e ${truncdir}/truncPar.sql ]&& rm -f ${truncdir}/truncPar.sql
	#获取oracle用户，密码和tns连接字符串名称，dblink名称
	ouname=`echo ${f} | awk -F ',' '{print $1}'`
	oupass=`echo ${f} | awk -F ',' '{print $2}'`
	tnsname=`echo ${f} | awk -F ',' '{print $3}'`
	dblname=`echo ${f} | awk -F ',' '{print $4}'`
	#获取指定用户的所有的分区表
	getParTableInfo ${ouname} ${oupass} ${tnsname}
	#获取指定用户的所有分区表指定分区的expdp语句和截断分区语句
	getExpdpParCommandAndTruncSql ${ouname} ${oupass} ${tnsname} ${dblname}
	#执行备份
	[ -e ${truncdir}/ExpdpPar.cmd ]&& bash ${truncdir}/ExpdpPar.cmd
	#执行截断分区
	[ -e ${truncdir}/truncPar.sql ]&& execSQL ${ouname} ${oupass} ${tnsname} "${truncdir}/truncPar.sql"
	
	[ -e ${truncdir}/ExpdpPar.cmd ]&& rm -f ${truncdir}/ExpdpPar.cmd
	[ -e ${truncdir}/truncPar.sql ]&& rm -f ${truncdir}/truncPar.sql
done


###################################
:<<BLOCK'
###################################
#trunc_par.prm 参数文件
#参数文件，格式：用户名，密码，tns连接字符串，dblink名称
kcbs,zjkc_2012_PT,RACDB,DB_BASIC
kcpt,zjkc_2012_PT,RACDB,DB_STORAGE
kcpt,zjkc_2012_PT,kcptdg2,kcpt103

###################################
'BLOCK
#用法：./trunc_partition-data.sh /path/trunc_par.prm
