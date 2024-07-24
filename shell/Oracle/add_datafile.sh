#!/bin/bash
#by raysuen
#v04

. ~/.profile

AddDataFile(){
        sqlplus -s /nolog<<-RAY
                conn / as sysdba
                $1
    
        RAY
}



while true
do
        sqltring=`/export/home/oracle/scripts/ray/oracle_ray.sh type=tablespace | egrep -v "TABLESPACE_NAME|selected|new mail|UNDOTB|TEMP" |tr "%" " " | awk '{if($NF>30) print "alter tablespace "$1" add datafile '\''+data1'\'' size 128M autoextend on next 128M maxsize unlimited;"}' | egrep "^alter"`
        if [ "${sqltring:-None}" == "None" ];then
                break
        else
                AddDataFile "${sqltring}"
                #echo ${sqltring}
        fi
        
done




##############################not OMF管理自动添加数据文件###########################################
#!/bin/bash
#by raysuen
#v01

#load profile for env
[ -f ~/.profile ]&& source ~/.profile
[ -f ~/.bash_profile ]&& source ~/.bash_profile

#function for add datafile
AddDataFile(){
	sqlplus -s /nolog<<-RAY
		conn / as sysdba
		$1
		
	RAY
}


#specify check script
ora_script=/home/oracle/script/ray/oracle_ray.sh

while true
do
	#obtain tablespace name which is over threshold value
	tablespace_name=`${ora_script} type=tablespace | egrep -v "TABLESPACE_NAME|selected|new mail|UNDOTB|TEMP" |tr "%" " " | awk '{if($NF>80) print $1}'`
	
	if [ "${tablespace_name:-None}" == "None" ];then
		break
	else
		#loop tablespace name if tablespace is more then 2
		for i in ${tablespace_name}
		do
			#obtain max datafile name
			max_datafile=`${ora_script} type=tsdf| grep "${i}" | sort -k 2 | tail -1 | awk '{print $2}'`
			#obtain max datafile number from max datafile
			max_num=`echo ${max_datafile} | awk -F\/ '{print $NF}' | sed -e "s/${i}//g" |  sed -e "s/$(echo ${i} | tr [A-Z] [a-z])//g" | sed -e "s/[^0-9]//g"`
			#plus 1 on max_num
			replace_num=$[$max_num+1]
			
			#judge replace_num whether is less then 10,if it is true ,then before the replace_num join 0
			if [ ${replace_num} -lt 10 ];then
				replace_num=`echo 0"${replace_num}"`
			fi
			#join the executable sql to add datafile
			sqltring=`echo "alter tablespace ${i} add datafile '"$(echo ${max_datafile} | sed "s/${max_num}\./${replace_num}\./g")"' size 128M autoextend on next 128M maxsize unlimited;"`
			#echo $sqltring
			AddDataFile "${sqltring}"
		done
	fi
		
done













