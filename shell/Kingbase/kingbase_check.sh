#!/bin/bash
#by raysuen
#v 1.0
#for check kingbase status

export LANG=C

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
    #echo "kingbase_path    : "$kingbase_path
    #echo "server_path      : "$server_path
    #echo "kingbase_home    : "$kingbase_home

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
    #echo "database data_dir: "$data_dir

}


Check_DB_Mode(){
	DBMode=None
	#kingbase_path=$(ps -ef|grep "bin/kingbase" | egrep -v grep | awk '{print $8}')
    bin_path=${kingbase_path%/*}
    if [ `whoami` == "kingbase" ];then
    	if [[ `ps -ef | egrep repmgrd | egrep -v grep | wc -l` -eq 1 ]] && [[ `$bin_path/repmgr cluster show 2>/dev/null | egrep primary | wc -l` -eq 1 ]]  && [[ `ps -ef | grep walsender |egrep -v grep | wc -l` -ge 1 ]];then
    		DBMode="cluster"
			etc_path=${bin_path%/*}"/etc"
    	elif [[ `ps -ef | egrep repmgrd | egrep -v grep | wc -l` -eq 1 ]] && [[ `$bin_path/repmgr cluster show 2>/dev/null | egrep standby | wc -l` -eq 1 ]] && [[ `ps -ef | grep walsender |egrep -v grep | wc -l` -eq 0 ]];then
    		echo "This is the standby node of the cluster！！"
    		DBMode="cluster"
    		#exit 0
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
    		DBMode="cluster"
    		#exit 0
    	else
    		DBMode="single"

    	fi
        
    fi
}


check_database_status(){
    if [[ $DBMode == "cluster" ]];then
        if [[ `${bin_path}/repmgr cluster show  2>&1 | egrep "primary|standby" |wc -l` -ge 2 ]] && [[ `${bin_path}/repmgr cluster show 2>&1  | egrep "primary|standby" | awk -F'[|]+' 'BEGIN{res="ok"}{temp=$4;gsub(/*/,"",temp);gsub(/ /,"",temp);if(temp="running"){ res="ok"} else {res="warning"} }END{print res}'` == "ok" ]] && [[ $(${bin_path}/repmgr service status  2>&1 | egrep "primary|standby" | awk -F'[|]+' 'BEGIN{res="ok"}{temp=$5;gsub(/ /,"",temp);if(temp="running"){ res="ok"} else {res="warning"} }END{print res}') ]] && [[ `ps -ef | grep repmgrd | egrep -v grep | wc -l ` -eq 1 ]] && [[ `${bin_path}/repmgr cluster show  2>&1 | egrep "WARNING" | wc -l` -eq 0 ]] && [[ `${bin_path}/repmgr service status  2>&1 | egrep "WARNING" | wc -l` -eq 0 ]];then
    	   echo "Kingbase Database Check: OK"
        else
            echo "Kingbase Database Check: WARNING"
        fi
    elif [[ $DBMode == "single" ]];then
        if [[ `ps -ef | grep "bin/kingbase" |egrep -v "grep" | wc -l` -ge 1 ]];then
            echo "Kingbase Database Check: OK"
        else
            echo "Kingbase Database Check: WARNING"
        fi

    fi

}


check_OS_status(){
    df -h | egrep -v "Filesystem|loop" | awk 'BEGIN{res="ok"}{temp=$5;gsub(/%/,"",temp);if(temp+0>=85) {res="warning";print $0}}END{print "DISK CHECK: "res}'

    free -m | egrep -v "total" | awk 'BEGIN{res="ok"}{if($1=="Mem:"){if(($NF/$2)*100<=15) {res="warning"}} else if($1=="Swap:"){if(($NF/$2)*100<=15) {res="warning"}}}END{print "MEMORY CHECK: "res}'

}


check_Kingbase_rman(){
    rman_list=(`crontab -l 2>&1 | egrep "sys_rman" | egrep -v "^#" | egrep "type=full" | awk '{print $6" "$7" "$8}'`)

    if [[ -n ${rman_list} ]];then
        echo ${rman_list[0]}" "${rman_list[1]}" "${rman_list[2]}" info" | bash | awk -F'[ _-]+' 'BEGIN{res="warning"}/backup:/{if(($2=="full")&&($4==strftime("%Y%m%d",systime()))) {res="ok"} else if(($2=="incr")&&($6==strftime("%Y%m%d",systime()))){res="ok"}}END{print "Kingbase Rman Check: "res}'
    fi

}


RUN(){
    check_database_data
    Check_DB_Mode
    check_database_status
    check_Kingbase_rman
    check_OS_status
    
}


RUN
