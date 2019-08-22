#!/bin/bash
#by ray
#2017-10-09


##########################################################################################
# funcations
##########################################################################################

######################################################
# funcation for getting user infomation
######################################################
userfile=./.userfile_`date +%Y%m%d%H%M%S`
getUsers(){
sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	set feedback off
	set pages 10000
	set heading off
	spool ${userfile}
	select username from dba_users;
	spool off
	exit
RAY
}

######################################################
# funcation for getting user infomation
######################################################
tablefile=./.tablefile_`date +%Y%m%d%H%M%S`
getTables(){
sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	set feedback off
	set pages 10000
	set heading off
	spool ${tablefile}
	select TABLE_NAME from dba_tables where owner='CUT';
	spool off
	exit
RAY
}

######################################################
# funcation for getting user infomation
######################################################
columnfile=./.columnfile_`date +%Y%m%d%H%M%S`
getColumns(){
sqlplus -s /nolog <<-RAY
	conn / as sysdba
	set linesize 300
	set feedback off
	set pages 10000
	set heading off
	spool ${columnfile}
	select COLUMN_NAME from dba_tab_columns where table_name='$1';
	spool off
	exit
RAY
}

##########################################################################################
# getting user name
##########################################################################################

######################################################
# exec funcation to display user name
######################################################
getUsers

######################################################
# ismatch is a lable, to check that user name is existed in instance
######################################################
ismatch=no

######################################################
# to judge whether user name is existed in instance
######################################################
while true
do
	read -p "Please Enter the user you want to create index:" orauser
	if [ ! ${orauser} ];then
		echo ""
		echo "You must specify a user name in oracle instance."
		continue
	else
		orauser=`echo ${orauser} | tr [a-z] [A-Z]`
		while read line
		do
			if [ ! ${line} ];then
				continue
			elif [ ${line} == ${orauser} ];then
				ismatch=yes
				break
			fi
		done < ${userfile}
		if [ ${ismatch} == 'yes' ];then
			#echo ${orauser}
			break
		else
			echo ""
			echo "The user must exist in instance."
			echo ""
			continue
		fi
	fi
done

[ -e ${userfile} ]&& rm -rf ${userfile}


##########################################################################################
# getting table name
##########################################################################################

######################################################
# exec funcation to display table name
######################################################
getTables

######################################################
# ismatch is a lable, to check that user name is existed in instance
######################################################
ismatch=no

######################################################
# to judge whether user table is existed in instance
######################################################
while true
do
	read -p "Please Enter the table you want to create index:" oratable
	if [ ! ${oratable} ];then
		echo ""
		echo "You must specify a table name in oracle instance."
		continue
	else
		oratable=`echo ${oratable} | tr [a-z] [A-Z]`
		while read line
		do
			if [ ! ${line} ];then
				continue
			elif [ ${line} == ${oratable} ];then
				ismatch=yes
				break
			fi
		done < ${tablefile}
		if [ ${ismatch} == 'yes' ];then
			#echo ${oratable}
			break
		else
			echo ""
			echo "The table must exist in instance."
			echo ""
			continue
		fi
	fi
done

[ -e ${tablefile} ]&& rm -rf ${tablefile}

##########################################################################################
# getting column name
##########################################################################################

######################################################
# exec funcation to display column name
######################################################
getColumns

######################################################
# ismatch is a lable, to check that user name is existed in instance
######################################################
ismatch=no

######################################################
# to judge whether user table is existed in instance
######################################################
while true
do
	read -p "Please Enter the columns you want to create index:" oracolumns
	if [ ! ${oracolumns} ];then
		echo ""
		echo "You must specify a table name in oracle instance."
		continue
	else
		oratable=`echo ${oratable} | tr [a-z] [A-Z]`
		while read line
		do
			if [ ! ${line} ];then
				continue
			elif [ ${line} == ${oratable} ];then
				ismatch=yes
				break
			fi
		done < ${tablefile}
		if [ ${ismatch} == 'yes' ];then
			#echo ${oratable}
			break
		else
			echo ""
			echo "The table must exist in instance."
			echo ""
			continue
		fi
	fi
done

[ -e ${tablefile} ]&& rm -rf ${tablefile}

