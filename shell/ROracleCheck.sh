#!/bin/bash
#by raysuen
#v1.0


orauser=system
orapasswd=oracle


NUM_CHK() {
        NUM_CHECK="$1"
        NUM_NAME="$2"
        if [ -z "$NUM_CHECK" ]
        then
                echo "CRITICAL: get the values is null"
                exit 99
        fi
        INTEGER=`echo "$NUM_CHECK" |sed 's/ ^*//g'|sed 's/ *$//g'`
        if [ `grep '^[[:digit:]]*$' <<< "${NUM_CHECK}"` ]
        then
                :
        else
                echo "CRITICAL: get ${NUM_NAME} value not integer,pls check"
                exit 98
        fi
}

TablespaceCheck(){
	if [ -z ${tnsname} ];then
		connstring=${orauser}/${orapasswd}
	else
		connstring=${orauser}/${orapasswd}@${tnsname}
	fi
	TS_RESULT=`$ORACLE_HOME/bin/sqlplus -s ${connstring} << EOF
        set linesize 120
        set head off
	 	select  a.tablespace_name,
			round(round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024, 2) / round((case maxbytes when 0 then a.bytes_alloc else maxbytes end)/1048576,2) * 100,2) "USED_MAX%"
        from  ( select  f.tablespace_name,
       				sum(f.bytes) bytes_alloc,
       				sum(decode(f.autoextensible, 'YES',f.maxbytes,'NO', f.bytes)) maxbytes
                from dba_data_files f
        		group by tablespace_name) a,
        	  ( select  f.tablespace_name,
       				sum(f.bytes)  bytes_free
                from dba_free_space f
                group by tablespace_name) b
        where a.tablespace_name = b.tablespace_name (+)
        union all
		select h.tablespace_name,
			round(round(sum(nvl(p.bytes_used, 0))/ 1048576, 2)/round(sum(case f.maxbytes when 0 then (h.bytes_free + h.bytes_used) else f.maxbytes end) / 1048576, 2) * 100,2) "USED_MAX%"
        from sys.v_\$TEMP_SPACE_HEADER h, sys.v_\$Temp_extent_pool p, dba_temp_files f
        where  p.file_id(+) = h.file_id
        	and p.tablespace_name(+) = h.tablespace_name
        	and f.file_id = h.file_id
        	and f.tablespace_name = h.tablespace_name
        group by h.tablespace_name
        ORDER BY 1;
EOF` > /dev/null 2>&1
	echo $TS_RESULT

}


main(){
	
	while (($#>=1))
	do
		if [ $1 == "-a" ];then  #-a action
			shift
			act=`echo $1 | tr [a-z] [A-Z]`
			shift
		elif [ $1 == "-c" ];then  #-c critical
			shift
			criticalNum=`echo $1 | tr [a-z] [A-Z]`
			shift
		elif [ $1 == "-w" ];then  #-w warning
			shift
			warningNum=`echo $1 | tr [a-z] [A-Z]`
			shift
		elif [ $1 == "-u" ];then  #-u user
			shift
			orauser=`echo $1`
			shift
		elif [ $1 == "-p" ];then  #-p password
			shift
			orapasswd=`echo $1`
			shift
		elif [ $1 == "-ts" ];then  #-ts tnsnames.ora  
			shift
			tnsname=`echo $1`
			shift
		else
			echo "You must enter right parameters!!"
			exit 1
		fi
		
	done
	
	if [ -z $act ];then
		echo "action must be specified!!"
		exit 2
	elif [ $act == "TABLESPACE" ];then
		TablespaceCheck
	fi
	

}

#######################################################################
#the entry of script
#######################################################################
argvs=($@)
main ${argvs[@]}