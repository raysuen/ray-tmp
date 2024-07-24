#!/bin/bash
#by raysuen
#version 1.0


c_red="\e[1;31m"
c_end="\e[0m"

#############################################################
#oracle exec sql once
#############################################################
OraEcecSQL(){
	sqlplus -s /nolog<<-RAY
	conn / as sysdba
	set linesize 300;
	set feedback off;
	set head off;
	$1
	exit
	RAY
}


#############################################################
#Primary Check
#############################################################
PriCheck(){
	###################Log mode########################
	logmode=`echo $(OraEcecSQL 'select log_mode from v$database;')`
	if [ "${logmode}" == "NOARCHIVELOG" ];then
		echo -e "${c_red}please configure log mode to archivelog.${c_end}"
		exit 99
	fi
	forcelog=$(OraEcecSQL 'select force_logging from v$database;')
	if [ "${forcelog}" == "NO" ];then
		echo -e "${c_red}please configure force log to archivelog.${c_end}"
		exit 98
	fi
}

PriCheck