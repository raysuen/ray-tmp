#!/bin/bash

####################################################################################################################                                                                                                                                                 
###                                                                                                                                                                                                                                                                  
### Descipt: this script help us to make a base optimization for database 
### Author : HM
### Create : 2020-04-28
###
### Usage  :
###        ./optimize_database_conf.sh
###
###
### Reedit : Raysuen
### version: v3.0
###			reedit info: Separate configuration file,Distinguish cluster and single
###			reedit info: using sys_monitor.sh to set up parameters in cluster.
####################################################################################################################

echo "This tool help use to make a base optimization for database" 
echo ""
user=`whoami`;

set -e
#1. get database data first, if not, exit. 
# TODO: or input the data dir?
check_database_data(){
	main_proc_num=$(ps -ef|grep -E "kingbase:.*checkpointer"|grep -v grep|wc -l)
    case $main_proc_num in
		0)
			echo "the database is not on live, please input kingbase home path:"
			read kingbase_home
			if [[ ! -d "$kingbase_home" ]] || [[ ! -f "$kingbase_home/Server/bin/kingbase" ]]; then
				echo "kingbase home path is error, please check it and try again !"
				echo ""
				exit
			fi
			server_path=$kingbase_home/Server
			bin_path=$server_path/bin		
			kingbase_path=$bin_path/kingbase
			
			echo "can not get data path from main process, please input the data path:"
			read data_dir
			if [[ ! -d "$data_dir" ]] || [[ ! -f "$data_dir/kingbase.conf" ]]; then
				echo "data path is error"
				echo "you can use: \"find / -name kingbase.conf\" to find it"
				echo "please check and try again !"
				exit 10
			fi			
			;;
		1)
			KESPID=$(ps -ef|grep -E "kingbase:.*checkpointer"|grep -v grep|awk '{print $3}'|head -1)
			kingbase_path=$(ls -l /proc/$KESPID/exe|awk '{print $NF}')
			data_dir=$(ls -l /proc/$KESPID/cwd|awk '{print $NF}')
			bin_path=${kingbase_path%/*}
			server_path=${bin_path%/*}
			kingbase_home=${server_path%/*}
			;;		
		*)
			echo "There are multiple KingbaseES main processes, please select one: "
			ps -ef|grep -E "kingbase:.*checkpointer"|grep -v grep|awk '{print $3}'|while read line; do echo "KES PID: $line"; ls -l /proc/$line/exe|awk '{print $NF}'|xargs echo "    CMD : " ;ls -l /proc/$line/cwd|awk '{print $NF}'|xargs echo "    DATA: " ;  done
			echo "Enter KingbaseES PID:"
			read KESPID
			kingbase_path=$(ls -l /proc/$KESPID/exe|awk '{print $NF}')
			data_dir=$(ls -l /proc/$KESPID/cwd|awk '{print $NF}')
			bin_path=${kingbase_path%/*}
			server_path=${bin_path%/*}
			kingbase_home=${server_path%/*}
	esac 
	
	if [ ! -f "$kingbase_path" ]; then
		echo "kingbase_path is error"
		echo "please check and try again !"
		exit 10
	fi
	
	echo 		
    echo "kingbase_path    : "$kingbase_path
    echo "server_path      : "$server_path
    echo "kingbase_home    : "$kingbase_home     
    echo "database data_dir: "$data_dir
}


#sigle,cluster 
Check_DB_Mode(){
	DBMode=None
	kingbase_path=$(ps -ef|grep "bin/kingbase" | egrep -v grep | awk '{print $8}')
    bin_path=${kingbase_path%/*}
    if [ `whoami` == "kingbase" ];then
    	if [[ `ps -ef | egrep repmgrd | egrep -v grep | wc -l` -eq 1 ]] && [[ `$bin_path/repmgr cluster show 2>/dev/null | egrep primary | wc -l` -eq 1 ]]  && [[ `ps -ef | grep walsender |egrep -v grep | wc -l` -eq 1 ]];then
    		DBMode="cluster"
			etc_path=${bin_path%/*}"/etc"
    	elif [[ `ps -ef | egrep repmgrd | egrep -v grep | wc -l` -eq 1 ]] && [[ `$bin_path/repmgr cluster show 2>/dev/null | egrep standby | wc -l` -eq 1 ]] && [[ `ps -ef | grep walsender |egrep -v grep | wc -l` -eq 0 ]];then
    		echo "This is the standby node of the cluster！！"
    		exit 0
    	else
    		DBMode="single"

    	fi
        
    elif [ `whoami` == "root" ];then
    	primary_exist=`su - kingbase -c "$bin_path/repmgr cluster show 2>/dev/null | egrep primary | wc -l"`

    	if [[ `ps -ef | egrep repmgrd | egrep -v grep | wc -l` -eq 1 ]] && [[ ${primary_exist} -eq 1 ]] && [[ `ps -ef | grep walsender |egrep -v grep | wc -l` -eq 1 ]];then
    		DBMode="cluster"
			etc_path=${bin_path%/*}"/etc"
    	elif [[ `ps -ef | egrep repmgrd | egrep -v grep | wc -l` -eq 1 ]] && [[ ${primary_exist} -eq 1 ]] && [[ `ps -ef | grep walsender |egrep -v grep | wc -l` -eq 0 ]];then
    		echo "This is the standby node of the cluster！！"
    		exit 0
    	else
    		DBMode="single"

    	fi
        
    fi
}

#2. back kingbase.conf first
# TODO: we just modify the kingbase.conf or kingbase.auto.conf?
back_kingbase_conf(){
	kingbase_conf=$data_dir/kingbase.conf
    if [[ ${DBMode} == "single" ]];then
    	kingbase_conf_back="kingbase.conf_back_"$(date "+%Y-%m-%d_%H_%M_%S")
    	cp $data_dir/kingbase.conf $data_dir/$kingbase_conf_back
    	echo "before optimize the database, back kingbase.conf to " $kingbase_conf_back
    	optimize_conf=$data_dir/optimize.db.conf
    elif [[ ${DBMode} == "cluster" ]];then
    	kingbase_conf_back="es_rep.conf_back_"$(date "+%Y-%m-%d_%H_%M_%S")
    	cp $data_dir/es_rep.conf $data_dir/$kingbase_conf_back
    	echo "#`date +"%Y-%m-%d %H-%M"`, optimize_database" >> $data_dir/es_rep.conf
    	[ -f "${etc_path}/set_db.conf" ]&& rm -f ${etc_path}/set_db.conf
    	optimize_conf=${etc_path}/set_db.conf

    fi
    
}


#3. get system source conf, the optimize base info
get_system_config(){
    #1) get cpu cores:
    cpu_cores=$(cat /proc/cpuinfo |grep 'processor'|wc -l)
    echo "system CPU cores: " $cpu_cores

    #2) get memery KB:
    mem_kb=$(cat /proc/meminfo |grep MemTotal|awk '{print $2}')
    echo "system Mem: " $mem_kb "KB as " $(echo "$mem_kb/1024"|bc) "MB"


    #3) db_data path:
    #data_dir=$(ps -ef|grep kingbase|grep D|grep data|awk '{print $10}')
    #echo "database data dir: " $data_dir

    #4) get disk type:
    # this kind conf optimize by kingbaser
    # mount check data divice name for optimize
    #is_ssd=$(cat /sys/block/$DIVIE_NAME/queue/rotational)
    #1: SATA
    #0: SSD
}

#4. optimize database memory configuration
#shared_buffers = 128MB 
#effective_cache_size = 4GB 
#maintenance_work_mem = 64MB
#wal_buffers = -1
#work_mem = 16MB
#min_wal_size = 80MB
#max_wal_size = 1GB
optimize_db_mem(){

    shared_mem=$(echo "$mem_kb/1024/4"|bc)
    echo "shared_mem: " $shared_mem "MB"

	[ -f ${optimize_conf} ] && sed -i '/^#OptimizeMemBegin/,/^#OptimizeMemEnd/d' ${optimize_conf}
    cat >>$optimize_conf <<EOF
#OptimizeMemBegin
shared_buffers = ${shared_mem}MB
effective_cache_size = $(echo "$mem_kb/1024 - $shared_mem"|bc)MB
min_wal_size = 2GB
max_wal_size = 8GB
EOF
    if [ $mem_kb -lt $(echo "32*1024*1024"|bc) ]; then
        echo "maintenance_work_mem = $(echo "$shared_mem/4"|bc)MB">>$optimize_conf
    else
        echo "maintenance_work_mem = 2GB">>$optimize_conf
    fi

	echo "#OptimizeMemEnd" >> $optimize_conf
    #TODO: work_mem do not optimize rigth now
    #TODO: temp_buffers do not optimize rigth now
}

##5. optimize database checkpoint
optimize_checkpoint(){

    
    [ -f ${optimize_conf} ] && sed -i '/^#OptimizeCheckpointBegin/,/^#OptimizeCheckpointEnd/d' ${optimize_conf}
    cat >>$optimize_conf <<EOF
#OptimizeCheckpointBegin
checkpoint_completion_target = 0.9
checkpoint_timeout = 30min
max_connections=1000
max_locks_per_transaction=1024

#log
logging_collector=on
log_destination='csvlog'
log_directory='sys_log'
log_filename='kingbase-%d.log'   #日志保留一个月
log_truncate_on_rotation=on
log_rotation_age=1440
log_connections=on
log_disconnections=on
log_statement='ddl'
log_checkpoints=on
log_rotation_size=204800 #200M
log_lock_waits=on
log_autovacuum_min_duration=0
log_temp_files=0
lc_messages='C'
log_min_duration_statement=1000
log_line_prefix='%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h'
#OptimizeCheckpointEnd
EOF

}

#6. optimize database parallel
optimize_parallel(){

    
    [ -f ${optimize_conf} ] && sed -i '/^#OptimizeParallelBegin/,/^#OptimizeParallelEnd/d' ${optimize_conf}
    echo "#OptimizeParallelBegin">>$optimize_conf
    echo "max_worker_processes = $cpu_cores">>$optimize_conf
    if [ $cpu_cores -ge 8 ]; then
        echo "max_parallel_workers_per_gather = 4">>$optimize_conf
    elif [ $cpu_cores -ge 2 ]; then
        echo "max_parallel_workers_per_gather = $(echo "$cpu_cores/2"|bc)">>$optimize_conf
    else
        #do not open parallel 
        echo "do not open parallel"
    fi
    echo "#OptimizeParallelEnd">>$optimize_conf
}

#7. restart database, make the conf work
restart_db(){
    case $main_proc_num in
    1)
    	#kingbase_path=$(ps -ef|grep kingbase|grep data |grep D|awk '{print $8}')
        #kingbase_path=$(ps -ef|grep "bin/kingbase" | egrep -v grep | awk '{print $8}')
        kingbase_path=$(ls -l /proc/$KESPID/exe|awk '{print $NF}')
    	bin_path=${kingbase_path%/*}
    	if [[ "${user}" == "kingbase" ]] && [[ ${DBMode} == "cluster" ]];then
    		$bin_path/sys_monitor.sh stop && $bin_path/sys_monitor.sh start
    	elif [[ "${user}" == "kingbase" ]] && [[ ${DBMode} == "single" ]];then
    		$bin_path/sys_ctl -D ${data_dir} stop && $bin_path/sys_ctl -D ${data_dir} start
    	elif [[ "${user}" == "root" ]] && [[ ${DBMode} == "cluster" ]];then
    		su - kingbase -c "$bin_path/sys_monitor.sh stop && $bin_path/sys_monitor.sh start"
    	elif [[ "${user}" == "root" ]] && [[ ${DBMode} == "single" ]];then
    		su - kingbase -c "$bin_path/sys_ctl -D ${data_dir} stop && $bin_path/sys_ctl -D ${data_dir} start"
    	fi
    	#su - $user -c "$bin_path/sys_ctl -D $data_dir restart -l restart.log"
        
	       
    	;;
    *)
   	    #kingbase_path=$(ps -ef|grep kingbase|grep data |grep $KESPID|grep D|awk '{print $8}')
        kingbase_path=$(ls -l /proc/$KESPID/exe|awk '{print $NF}')
    	bin_path=${kingbase_path%/*}
    	if [[ "${user}" == "kingbase" ]] && [[ ${DBMode} == "cluster" ]];then
    		$bin_path/sys_monitor.sh stop && $bin_path/sys_monitor.sh start
    	elif [[ "${user}" == "kingbase" ]] && [[ ${DBMode} == "single" ]];then
    		$bin_path/sys_ctl -D ${data_dir} stop && $bin_path/sys_ctl -D ${data_dir} start
    	elif [[ "${user}" == "root" ]] && [[ ${DBMode} == "cluster" ]];then
    		su - kingbase -c "$bin_path/sys_monitor.sh stop && $bin_path/sys_monitor.sh start"
    	elif [[ "${user}" == "root" ]] && [[ ${DBMode} == "single" ]];then
    		su - kingbase -c "$bin_path/sys_ctl -D ${data_dir} stop && $bin_path/sys_ctl -D ${data_dir} start"
    	fi
    	#su - $user -c "$bin_path/sys_ctl -D ${data_dir} stop && $bin_path/sys_ctl -D ${data_dir} start"
    esac
        if [ ! -f "$kingbase_path" ]; then
                echo "kingbase_path is error"
                echo "please check and try again !"
                exit 10
        fi

    echo
    echo "kingbase_path    : "$kingbase_path
    echo "server_path      : "$server_path
    echo "kingbase_home    : "$kingbase_home
    echo "database data_dir: "$data_dir
}

#main:
echo "begin optimize database"
#1. get database data first, if not, exit. 
echo "1.get database data, check database is alive"
check_database_data
Check_DB_Mode
echo ""

#2. back kingbase.conf first
echo "2.back kingbase.conf file"
back_kingbase_conf
echo ""

#3.get system conf
echo "3.get system resource"
get_system_config
echo ""

#4. optimize database memory configuration
echo "4.optimize database memory"
optimize_db_mem
echo ""

#5. optimize database checkpoint
echo "5.optimize database checkpoint"
optimize_checkpoint
echo ""

#6. optimize database parallel
echo "6.optimize database parallel"
optimize_parallel
echo ""




#edit kingbase.conf
if [ "${DBMode}" == "single" ];then
	[ `egrep "^include_if_exists = 'optimize.baseline.conf'" ${kingbase_conf} | wc -l` -eq 0 ]&& echo "include_if_exists = 'optimize.baseline.conf'" >> ${kingbase_conf}
fi
if [[ "${user}" == "kingbase" ]] && [[ ${DBMode} == "cluster" ]];then
	$bin_path/sys_monitor.sh set #使用sys_monitore.sh 脚本进行批量修改。
elif [[ "${user}" == "root" ]] && [[ ${DBMode} == "cluster" ]];then
	su - kingbase -c "$bin_path/sys_monitor.sh set"  #使用sys_monitore.sh 脚本进行批量修改。
fi

echo "end optimize database"
echo ""
echo "7.restart database to make those configuration work"
while true
do
	chown -R kingbase:kingbase ${data_dir}
	[ -d "${etc_path}" ]&& chown -R kingbase:kingbase ${etc_path}  
	echo "please chose if restart database, 0: no, 1: yes"
	#7. restart database, make the conf work
	read restart_option
	#echo $bin_path;
	if [ ${restart_option:-100} -eq 1 ]; then
	    restart_db
	    break
	elif [ ${restart_option:-100} -eq 0 ]; then
		echo "The optimization is over."
		break
	    # echo "please restart database by hand to make those configuration work"
# 	    echo "usage:"
# 	    echo "su - $user -c "$bin_path/sys_ctl -D $data_dir restart -l restart.log""
	else
		echo "You must enter 1 or 0."
		continue
	fi
done


echo ""
echo "end"
