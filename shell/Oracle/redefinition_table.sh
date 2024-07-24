#!/bin/bash
#by raysuen
#version 2.0


[ -e ~/.profile ] && . ~/.profile
[ -e ~/.bash_profile ] && . ~/.bash_profile


###################################################
#The function is check that the User exists in the database.
###################################################
CheckUser(){
	sqlplus -s /nolog<<-RAY
		set termout      off;
		set echo          off;
		set feedback      off;
		set verify        off;
		set heading off;
		conn $2
		select username from dba_users where username='$1';
	RAY
}


###################################################
#The function is check that the table exists in the database.
###################################################

CheckTable(){
	sqlplus -s /nolog<<-RAY
		set termout      off;
		set echo          off;
		set feedback      off;
		set verify        off;
		set heading off;
		conn $3
		select table_name from dba_tables where owner='$1' and table_name='$2';
	RAY
}

###################################################
#The function is check that can redefinition table.
###################################################
CanRedef(){
	sqlplus -s /nolog<<-RAY
		conn $1
		set termout      off;
		set echo          off;
		set verify        off;
		set heading off;
		$2
	RAY
}

###################################################
#The function that redefinition table
###################################################
redefinitionTable(){
	sqlplus -s /nolog<<-RAY
		conn $4
		set termout      off;
		set echo          off;
		set verify        off;
		set heading off;
		alter session force parallel dml;
		alter session force parallel query;
		$5
		DECLARE
			num_errors PLS_INTEGER;
		BEGIN
  			DBMS_REDEFINITION.COPY_TABLE_DEPENDENTS('$1', '$2','$3',
   			DBMS_REDEFINITION.CONS_ORIG_PARAMS, TRUE, TRUE, TRUE, TRUE, num_errors);
		END;
		/
		exec dbms_redefinition.sync_interim_table(uname => '$1',orig_table => '$2',int_table => '$3');
		exec dbms_redefinition.finish_redef_table(uname => '$1',orig_table => '$2',int_table => '$3');
	RAY
}

###################################################
#The function that abort table
###################################################
AbortTable(){
	sqlplus -s /nolog<<-RAY
		conn $4
		set termout      off;
		set echo          off;
		set verify        off;
		set heading off;
		DBMS_REDEFINITION.ABORT_REDEF_TABLE($1,$2,$3)
	RAY
}


###################################################
#Checkt to chennect oracle
###################################################
CheckConnect(){
	sqlplus /nolog<<-RAY
		conn $1
	RAY
}



###################################################
#The function for help
###################################################

func_help(){
	echo "Example:"
	echo "	redefinition_table.sh -o origins_table -i interlayer_table -u user_name -f option_flag -a action -c ora_user/ora_passwd@tnsname"
	echo "Value:"
	echo "	-c default value [/ as sysdba]"
	echo "	-f to use the way which redefine table."
	echo "		value: rowid/pk,default value: PK."
	echo "	-a specify a action which you want to do,default: redefine"
	
}



###################################################
#Entrance of the script
###################################################

###################################################
#get parameter
###################################################
if [ $# -lt 1 ];then
	echo "no parameters"
	exit 99
else
	while (($#>=1))
	do
		#echo $#
    	if [ $1 == "-o" ];then  #-o origins
    		shift
    		orig_table=`echo $1 | tr [a-z] [A-Z]`
    		shift
    	elif [ $1 == "-i" ];then  #-i interlayer
    		shift
    		int_table=`echo $1 | tr [a-z] [A-Z]`
    		shift 
    	elif [ $1 == "-u" ];then
    		shift
    		user_name=`echo $1 | tr [a-z] [A-Z]`
    		shift
    	elif [ $1 == "-c" ];then   #conect string include ora_username/ora_pwd@tns_name
    		shift
    		oraConStr=`echo $1`
    		shift
    	elif [ $1 == "-f" ];then   #option_flag default: dbms_redefinition.cons_use_pk. values: rowid/PK
    		shift
    		option_flag=`echo $1 | tr [a-z] [A-Z]`
    		shift
    	elif [ $1 == "-a" ];then   #action, the value must be redifine/abort. default: redifine
    		shift
    		action=`echo $1 | tr [a-z] [A-Z]`
    		shift
    	elif [ $1 == "-h" ];then
    		func_help
    		exit 0
    	else
    		echo "Please enter right parameter!"
    		echo "-h,you can use the parameter to get help!"
    		exit 99
    	fi
	done
fi

#echo $orig_table
#echo $int_table
#echo $user_name

###################################################
#Check that the value of orig_table 
###################################################
if [ ! ${orig_table} ];then
	echo "-o must be specified!"
	exit 1
fi
###################################################
#Check that the value of int_table 
###################################################
if [ ! ${int_table} ];then
	echo "-i must be specified!"
	exit 2
fi
###################################################
#Check that the value of user_name 
###################################################
if [ ! ${user_name} ];then
	echo "-u must be specified!"
	exit 3
fi

###################################################
#Check whether is successful to connecting oracle
###################################################
[ ! ${oraConStr} ]&& oraConStr=' / as sysdba'

CheckConnect "${oraConStr}" | grep "Connected" > /dev/null 2>&1
if [ $? -ne 0 ];then
        echo "it is fail to connect oracle using input connection string!"
        exit 4
fi

###################################################
#Check whether the input user exists in the database.
###################################################
if [ ! `CheckUser ${user_name} ${oraConStr} | sed 's/\n//g'` ];then
	echo "User:("${user_name}") dose not exists in database!"
	exit 5s
fi

###################################################
#Check whether the input table exists in the database.
###################################################
if [ ! `CheckTable ${user_name} ${orig_table} ${oraConStr} | sed 's/\n//g'` ];then
	echo "Table:("${orig_table}") dose not exists in database!"
	exit 6
fi
if [ ! `CheckTable ${user_name} ${int_table} ${oraConStr} | sed 's/\n//g'` ];then
	echo "Table:("${int_table}") dose not exists in database!"
	exit 7
fi


###################################################
#Check the value of action be specified
###################################################
[ ! ${action} ] && action="REDEFINE"

###################################################
#Check whether can redefinition table.
###################################################
if [ ${action} == 'REDEFINE' ];then
	if [ ! ${option_flag} ];then
		option_flag="PK"
		canRedStr="exec dbms_redefinition.can_redef_table(""'"$user_name"'"",""'"$orig_table"'"");"
		startRedStr="exec DBMS_REDEFINITION.start_redef_table(uname => '"$user_name"',orig_table => '"$orig_table"',int_table => '"${int_table}"');"
	elif [ ${option_flag} == "PK" ];then
		canRedStr="exec dbms_redefinition.can_redef_table(""'"$user_name"'"",""'"$orig_table"'"");"
		startRedStr="exec DBMS_REDEFINITION.start_redef_table(uname => '"$user_name"',orig_table => '"$orig_table"',int_table => '"${int_table}"');"
	elif [ ${option_flag} == "ROWID" ];then
		canRedStr="exec dbms_redefinition.can_redef_table(""'"$user_name"'"",""'"$orig_table"',dbms_redefinition.cons_use_rowid);"
		startRedStr="exec DBMS_REDEFINITION.start_redef_table(uname => '"$user_name"',orig_table => '"$orig_table"',int_table => '"${int_table}"',options_flag => dbms_redefinition.cons_use_rowid);"
	else
		echo "you must specify value for -f,only rowid/pk."
		exit 8
	fi
	
	if [ `CanRedef ${oraConStr} "${canRedStr}" | grep "successfully" | wc -l` -eq 0 ];then
		echo ${orig_table}" can not redefine using "${option_flag}
		exit 9
	fi
	###################################################
	#begin to redefinit table
	###################################################
	redefinitionTable ${user_name} ${orig_table} ${int_table} "${oraConStr}" "${startRedStr}"
elif [ ${action} == 'ABORT' ];then
	AbortTable ${user_name} ${orig_table} ${int_table} "${oraConStr}"
else
	echo "The value of action only use [redefine|abort]."
	exit 10
fi



###################################################
#core code
###################################################
#exec dbms_redefinition.can_redef_table('$1', '$2');
#exec DBMS_REDEFINITION.start_redef_table(uname => '$1',orig_table => '$2',int_table => '$3');
#DECLARE
#	num_errors PLS_INTEGER;
#BEGIN
#	DBMS_REDEFINITION.COPY_TABLE_DEPENDENTS('$1', '$2','$3',
#	DBMS_REDEFINITION.CONS_ORIG_PARAMS, TRUE, TRUE, TRUE, TRUE, num_errors);
#END;
#/
#exec dbms_redefinition.sync_interim_table(uname => '$1',orig_table => '$2',int_table => '$3');
#exec dbms_redefinition.finish_redef_table(uname => '$1',orig_table => '$2',int_table => '$3');





