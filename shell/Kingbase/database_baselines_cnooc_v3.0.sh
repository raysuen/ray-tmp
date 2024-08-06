#!/bin/bash

####################################################################################################################                                                                                                                                                 
###                                                                                                                                                                                                                                                                  
### Descipt: this script help us to make a base optimization for database 
### Author : HM
### Create : 2023-01-06
###
### Usage  :
###        ./optimize_database_baselines.sh
###
### Reedit : Raysuen
### version: v3.0
###			reedit info: Separate configuration file,Distinguish cluster and single
###			reedit info: using sys_monitor.sh to set up parameters in cluster.
####################################################################################################################


echo "This tool help use to make a base optimization for database" 
echo ""

set -e
#1. get database data first, if not, exit. 
# TODO: or input the data dir?
check_database_data(){
    main_proc_num=$(ps -ef|grep "bin/kingbase"|grep D|wc -l)
    if [ $main_proc_num -eq 0 ]; then
        echo "the database is not on live, please input kingbase home path:"
        read kingbase_home
        if [[ ! -d $kingbase_home ]] || [[ ! -f $kingbase_home/Server/bin/kingbase ]]; then
            echo "kingbase home path is error, please check it and try again !"
            echo ""
            exit
        fi
        server_path=$kingbase_home/Server
        bin_path=$server_path/bin
    else
        kingbase_path=$(ps -ef|grep bin/kingbase|grep D|awk '{print $8}')
        bin_path=${kingbase_path%/*}
        server_path=${bin_path%/*}
        kingbase_home=${server_path%/*}
    fi
    echo "kingbase_path    : "$kingbase_path
    echo "server_path      : "$server_path
    echo "kingbase_home    : "$kingbase_home

    data_dir=$(ps -ef|grep "bin/kingbase"|grep D|awk '{print $10}')
    if [[ $data_dir = "." ]] || [[ -z $data_dir ]]; then
        echo "can not get data path from main process, please input the data path:"
        read data_dir
        if [[ ! -d $data_dir ]] || [[ ! -f $data_dir/kingbase.conf ]]; then
            echo "data path is error"
            echo "you can use: \"find / -name kingbase.conf\" to find it"
            echo "please check and try again !"
            exit -1
        fi
    fi
    echo "database data_dir: "$data_dir
}

#2. back kingbase.conf first
# TODO: we just modify the kingbase.conf or kingbase.auto.conf?
back_kingbase_conf(){
	if [[ ${DBMode} == "single" ]];then
    	kingbase_conf_back="kingbase.conf_back_"$(date "+%Y-%m-%d_%H_%M_%S")
    	cp $data_dir/kingbase.conf $data_dir/$kingbase_conf_back
    	echo "before optimize the database, back kingbase.conf to " $kingbase_conf_back
    elif [[ ${DBMode} == "cluster" ]];then
    	kingbase_conf_back="es_rep.conf_back_"$(date "+%Y-%m-%d_%H_%M_%S")
    	cp $data_dir/es_rep.conf $data_dir/$kingbase_conf_back
    	echo "before optimize the database, back es_rep.conf to " $kingbase_conf_back
    fi
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


#3.optimize database baselines 
optimize_baselines(){
    
    if [ "${DBMode}" == "cluster" ];then
    	[ -f "${etc_path}/set_db.conf" ]&& rm -f ${etc_path}/set_db.conf
    	baseline_conf=${etc_path}/set_db.conf
    	kingbase_conf=$data_dir/es_rep.conf		#设置kingbase集群的主配置文件
    elif [ "${DBMode}" == "single" ];then
    	baseline_conf=$data_dir/optimize.baseline.conf
    	kingbase_conf=$data_dir/kingbase.conf	#设置kingbase主配置文件
    fi
    
    keslibs=`egrep "^shared_preload_libraries" ${kingbase_conf} | sed "s/'/, passwordcheck,identity_pwdexp,sys_audlog,sysaudit'/2"`
    [ -f ${baseline_conf} ] && sed -i '/^#OptimizeBaselineBegin/,/^#OptimizeBaselineEnd/d' ${baseline_conf}
    cat >>$baseline_conf<<EOF
#OptimizeBaselineBegin
${keslibs}

#数据库口令复杂度参数
passwordcheck.enable=on                        #密码复杂度是否开启
passwordcheck.password_length=10                #口令的最小长度
passwordcheck.password_condition_letter=2      #口令至少包含字母个数
passwordcheck.password_condition_digit=2       #口令至少包含数字个数
passwordcheck.password_condition_punct=1       #口令至少包含特殊字符个数
identity_pwdexp.password_change_interval=90	     #密码有效期
identity_pwdexp.max_password_change_interval=90	 #最大密码有效期	

#登录失败处置参数
sys_audlog.error_user_connect_times=5         #允许用户连续登录失败的最大次数  
sys_audlog.error_user_connect_interval=30     #用户被锁定时间

#用户口令加密参数
password_encryption = scram-sha-256           #默认为scram-sha-256

#超时登出参数
#client_idle_timeout=1800 				#单位：秒

#审计参数
#sysaudit.enable = on                   #审计功能是否开启
#sysaudit.enable_auto_dump_auditlog=on  #审计日志自动转储是否开启

#OptimizeBaselineEnd
EOF

	if [ "${DBMode}" == "single" ];then
		[ `egrep "^include_if_exists = 'optimize.baseline.conf'" ${kingbase_conf} | wc -l` -eq 0 ]&& echo "include_if_exists = 'optimize.baseline.conf'" >> ${kingbase_conf}
	fi
	if [[ `whoami` == "kingbase" ]] && [[ ${DBMode} == "cluster" ]];then
    	$bin_path/sys_monitor.sh set #使用sys_monitore.sh 脚本进行批量修改。
    elif [[ `whoami` == "root" ]] && [[ ${DBMode} == "cluster" ]];then
    	su - kingbase -c "$bin_path/sys_monitor.sh set"  #使用sys_monitore.sh 脚本进行批量修改。
    fi

}

#4. restart database, make the conf work
restart_db(){
	if [[ `whoami` == "kingbase" ]] && [[ ${DBMode} == "cluster" ]];then
    	$bin_path/sys_monitor.sh stop && $bin_path/sys_monitor.sh start
    elif [[ `whoami` == "kingbase" ]] && [[ ${DBMode} == "single" ]];then
    	$bin_path/sys_ctl -D ${data_dir} stop && $bin_path/sys_ctl -D ${data_dir} start
    elif [[ `whoami` == "root" ]] && [[ ${DBMode} == "cluster" ]];then
    	su - kingbase -c "$bin_path/sys_monitor.sh stop && $bin_path/sys_monitor.sh start"
    elif [[ `whoami` == "kingbase" ]] && [[ ${DBMode} == "single" ]];then
    	su - kingbase -c "$bin_path/sys_ctl -D ${data_dir} stop && $bin_path/sys_ctl -D ${data_dir} start"
    fi
    
}

#5.db list 


db_list(){
	DATABASES=$($bin_path/ksql  -Usystem -A  test -c "select datname as test  from sys_catalog.sys_database where datname not in('test','template1','template0','security');" | sed '$d')
}
#6.create database extensions

create_extension(){
#echo $DATABASES
for db in $DATABASES
do
    echo $db
    #循环创建扩展，若已存在报错后会继续执行
set +e
     $bin_path/ksql -Usystem -d $db -c 'create extension passwordcheck;'
     $bin_path/ksql -Usystem -d $db -c 'create extension identity_pwdexp;'
     $bin_path/ksql -Usystem -d $db -c 'create extension sys_audlog;'
done
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

#3. optimize database baselines 
echo "3.optimize database baselines"
optimize_baselines

echo ""

echo "end optimize database"
echo ""
echo "4.restart database to make those configuration work"
#echo "please chose if restart database, 0: no, 1: yes:"
#4. restart database, make the conf work
while true
do
	chown -R kingbase:kingbase ${data_dir}
	chown -R kingbase:kingbase ${etc_path}   
	echo "please chose if restart database, 0: no, 1: yes"
	#7. restart database, make the conf work
	read restart_option
	#echo $bin_path;
	if [ ${restart_option:-100} -eq 1 ]; then
	    restart_db
	    echo ""
		echo "end"
		#5. db list
		echo "5.db list"
		db_list  
		echo "end"
		
		#6. create database extension
		echo "6.create database extension"
		create_extension 
		echo "end"
	    break
	elif [ ${restart_option:-100} -eq 0 ]; then
		echo "The baseline optimization is over."
		break
	    # echo "please restart database by hand to make those configuration work"
# 	    echo "usage:"
# 	    echo "su - $user -c "$bin_path/sys_ctl -D $data_dir restart -l restart.log""
	else
		echo "You must enter 1 or 2."
		continue
	fi
done



#echo "ov5yiOI#rqqyKb0D" | passwd --stdin cnooc
