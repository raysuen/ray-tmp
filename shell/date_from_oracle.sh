#!/bin/bash

[ -e ~/.profile ]&&. ~/.profile
[ -e ~/.bash_profile ]&&. ~/.bash_profile


OraDateCol(){
	colDays=$1
	colFormat=$2
	oraDate=`sqlplus -s /nolog<<-RAY
		conn / as sysdba
		set feedback off;
		set heading off
		select to_char(sysdate+${colDays},'${colFormat}') from dual;
	RAY`
	echo ${oraDate}
}

OraDateCol $1 $2


