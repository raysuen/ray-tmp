#!/bin/bash
#by raysuen
#v 01


back_dir=/kingbase/dump/back/`date +%Y%m%d`
rm_dir=/kingbase/dump/back/`date +%Y%m%d -d "-30 day"`
hostinf="127.0.0.1"

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
	
	#echo 		
    #echo "kingbase_path    : "$kingbase_path
    #echo "server_path      : "$server_path
    #echo "kingbase_home    : "$kingbase_home     
    #echo "database data_dir: "$data_dir
}

GetPort(){
        if [[ `ls /tmp/.*.KINGBASE.* | egrep -v "lock" | wc -l` -eq 1 ]];then
               kingbase_port=`ls /tmp/.*.KINGBASE.* | egrep -v "lock" | awk -F. '{print $NF}'`
        fi
        if [[ "${data_dir: -1}" == "/" ]];then
                data_dir=`echo ${data_dir} | sed 's/.$//'`
        fi


        if [ -z ${kingbase_port} ];then
                #arr=(`egrep "^include" ${data_dir}/kingbase.conf | sed "s/'//g" | awk '{if (NR == 1) print "kingbase.conf\n "$NF;else print $NF}'`)
                arr=(`egrep "^include" ${data_dir}/kingbase.conf | sed "s/'//g" | awk 'BEGIN{print "kingbase.conf"}{print $NF}'`)
                for i in $(seq $((${#arr[@]}-1)) -1 0)
                do
                        kingbase_port=`egrep "^port|^PORT" ${data_dir}/${arr[$i]} | awk '{print $3}'`
                        if [ ! -z ${kingbase_port} ];then
                                break
                        fi
                done

        fi

        if [ -z ${kingbase_port} ];then
                echo "No kingbase port found!!"
                exit 66
        fi
        #echo "database port    : "$kingbase_port
}

db_list(){
	DATABASES=$($bin_path/ksql  -Usystem -h ${hostinf} -A -p $kingbase_port test -c "select datname as test  from sys_catalog.sys_database where datname not in('test','template1','template0','security','kingbase');" | sed '$d')
}

dump_db(){
	[ ! -d ${back_dir} ]&& mkdir -p ${back_dir}
	for db in $DATABASES
	do
    	#echo $db
    #循环创建扩展，若已存在报错后会继续执行
		set +e
		$bin_path/sys_dump -Usystem -h ${hostinf} -p $kingbase_port -Fc -d $db -f ${back_dir}/${db}.dump
	done
	
}

del_backup(){
	[ -d ${rm_dir} ]&& rm -rf ${rm_dir}
}

run(){
	check_database_data
	GetPort
	db_list
	dump_db
	del_backup
}

run



