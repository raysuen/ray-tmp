#!/bin/bash
#by ray suen
#v0.8
#################################################################################
#before the bash you must install necessary rpm for oracle and edit hostname    #
#################################################################################
c_yellow="\e[1;33m"
c_red="\e[1;31m"
c_end="\e[0m"


echo "please confirm that you have put the script and software into the base dir"
echo "please confirm that server can connect to internet"

while true
do
	read -p "`echo -e "please enter the name of Ethernet，default [${c_yellow}net0${c_end}]: "`" inet
	ipddr=`ipadm | grep ${inet:-net0}"/v4" | awk '{print $NF}' | awk -F/ '{print $1}'`
	if [ ! ${ipddr} ];then
		echo ${inet}": the name of Ethernet dose not exists"
		continue
	else
		break
	fi
done

#################################################################################
##obtain base dir                                                               #
#################################################################################
while true
do
	read -p "`echo -e "please enter the name of base dir,put this shell and software in the dir.default [${c_yellow}/u01${c_end}]: "`" bdir
	basedir=${bdir:-/u01}  #this is base dir,put this shell and software in the dir
  	if [ ! -d ${basedir} ];then
    	echo -e "the ${basedir} is not exsist,please ${c_red}make it up${c_end}"
    	continue
  	else
    	break
  	fi
done

#################################################################################
##obtain hostnam                                                                #
#################################################################################
sname=$(hostname)  #get hostname
[ -z ${sname} ]&& echo -e 'shell can not obtain ${c_red}hostname${c_end},shell interrupt forcedly'&&exit 1

#################################################################################
#obtain ORACLE_BASE ORACLE_HOME                                                 #
#################################################################################
orabase="${basedir}/app/oracle"    #set path of oracle_base
orahome="${basedir}/app/oracle/product/11.2.0/db_1" #set path of oracle_home

#################################################################################
#obtain ORACLE_SID                                                              #
#################################################################################
read -p "`echo -e "please enter the sid.default [${c_yellow}orcl${c_end}]: "`" osid
orasid=${osid:-orcl} #set value of oracle_sid

#################################################################################
#obtain the momery percentage of the oracle using server momery                 #
#################################################################################
#
while true
do
	read -p "`echo -e "Please enter the momery percentage of the oracle using server momery.default [${c_yellow}60${c_end}]: "`" mper
  	perusemom=${mper:-60}
  	if [ -n "`echo ${perusemom} | sed 's/[0-9]//g' | sed 's/-//g'`" ];then
    	echo -e "please enter ${c_red}exact number${c_end}"
    	continue
  	else
    	[ "${perusemom}" -ge "90" ]&& echo -e "the percentage can not be greater than ${c_red}90${c_end}"&& continue
    	break
  	fi
done

#################################################################################
#obtain the datatime                                                            #
#################################################################################
daytime=`date +%Y%m%d`

#################################################################################
#install package of solaris                                                     #
#################################################################################
pkg install compatibility/packages/SUNWxwplt SUNWmfrun SUNWarc SUNWhea SUNWlibm

#################################################################################
#edit system                                                                    #
#################################################################################
cp /etc/system  /etc/system_${daytime}.bak
echo "set semsys:seminfo_semmni = 100" >> /etc/system
echo "set semsys:seminfo_semmns = 1024" >> /etc/system
echo "set semsys:seminfo_semmsl = 256" >> /etc/system
echo "set semsys:seminfo_semvmx = 32767" >> /etc/system
echo "set shmsys:shminfo_shmmax = ﻿68719476736" >> /etc/system
echo "set shmsys:shminfo_shmmni = 100" >> /etc/system
echo "set max_nprocs = 20000" >> /etc/system
echo "set rlim_fd_max = 65536" >> /etc/system
echo "set rlim_fd_cur = 1024" >> /etc/system

#################################################################################
#create user and group                                                          #
#################################################################################
mkdir  /export/home/oracle
groupadd -g 500 oinstall
groupadd -g 501 dba
groupadd -g 502 oper
useradd -u 1000 -g oinstall -G dba,oper -d /export/home/oracle oracle
chown oracle:oinstall /export/home/oracle

#################################################################################
#create ora_base directory                                                      #
#################################################################################
mkdir -p ${orabase}
chown -R oracle:oinstall  ${basedir}
chmod -R 755  ${basedir}

#################################################################################
#edit profile                                                                   #
#################################################################################
su - oracle -c "cp /export/home/oracle/.profile /export/home/oracle/.profile_${daytime}.bak"
su - oracle -c "echo 'umask 0022' >> /export/home/oracle/.profile" 
su - oracle -c "echo 'ORACLE_BASE='${orabase} >> /export/home/oracle/.profile" 
su - oracle -c "echo 'ORACLE_HOME='${orahome} >> /export/home/oracle/.profile" 
su - oracle -c "echo 'ORACLE_SID='${orasid} >> /export/home/oracle/.profile" 
su - oracle -c "echo 'export ORACLE_BASE ORACLE_HOME ORACLE_SID' >> /export/home/oracle/.profile" 
su - oracle -c "echo 'export PATH=\$ORACLE_HOME/bin:\$PATH:\$HOME/bin:/usr/bin:/sbin' >> /export/home/oracle/.profile" 
su - oracle -c "echo 'LD_LIBRARY_PATH=$ORACLE_HOME/lib' >> /export/home/oracle/.profile" 

#################################################################################
#edit project parameter                                                         #
#################################################################################
projadd -U oracle user.oracle
projmod -sK "project.max-sem-ids=(privileged,100,deny)" user.oracle
projmod -sK "project.max-sem-nsems=(privileged,256,deny)" user.oracle
projmod -sK "project.max-shm-memory=(privileged,64G,deny)" user.oracle
projmod -sK "project.max-shm-ids=(privileged,100,deny)" user.oracle


ipadm set-prop -p smallest_anon_port=9000 tcp
ipadm set-prop -p largest_anon_port=65500 tcp
ipadm set-prop -p smallest_anon_port=9000 udp
ipadm set-prop -p largest_anon_port=65500 udp


#################################################################################
#edit responseFile of rdbms                                                     #
#################################################################################
su - oracle -c "echo 'oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v11_2_0' > ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.option=INSTALL_DB_SWONLY' >> ${basedir}/db.rsp"
su - oracle -c "echo 'ORACLE_HOSTNAME='${sname} >> ${basedir}/db.rsp"
su - oracle -c "echo 'UNIX_GROUP_NAME=oinstall' >> ${basedir}/db.rsp"
su - oracle -c "echo 'INVENTORY_LOCATION='${basedir}'/oraInventory' >> ${basedir}/db.rsp"
su - oracle -c "echo 'SELECTED_LANGUAGES=en' >> ${basedir}/db.rsp"
su - oracle -c "echo 'ORACLE_HOME='${orahome} >> ${basedir}/db.rsp"
su - oracle -c "echo 'ORACLE_BASE='${orabase} >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.InstallEdition=EE' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.EEOptionsSelection=false' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.optionalComponents=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.DBA_GROUP=dba' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.OPER_GROUP=oper' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.CLUSTER_NODES=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.isRACOneInstall=false' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.racOneServiceName=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.type=GENERAL_PURPOSE' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.globalDBName=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.SID=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.characterSet=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.memoryOption=false' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.memoryLimit=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.installExampleSchemas=false' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.enableSecuritySettings=true' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.password.ALL=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.password.SYS=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.password.SYSTEM=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.password.SYSMAN=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.password.DBSNMP=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.control=DB_CONTROL' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.gridcontrol.gridControlServiceURL=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.automatedBackup.enable=false' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.automatedBackup.osuid=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.automatedBackup.ospwd=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.storageType=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.fileSystemStorage.dataLocation=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.starterdb.fileSystemStorage.recoveryLocation=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.asm.diskGroup=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.install.db.config.asm.ASMSNMPPassword=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'MYORACLESUPPORT_USERNAME=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'MYORACLESUPPORT_PASSWORD=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'SECURITY_UPDATES_VIA_MYORACLESUPPORT=false' >> ${basedir}/db.rsp"
su - oracle -c "echo 'DECLINE_SECURITY_UPDATES=true' >> ${basedir}/db.rsp"
su - oracle -c "echo 'PROXY_HOST=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'PROXY_PORT=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'PROXY_USER=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'PROXY_PWD=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'PROXY_REALM=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'COLLECTOR_SUPPORTHUB_URL=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.installer.autoupdates.option=SKIP_UPDATES' >> ${basedir}/db.rsp"
su - oracle -c "echo 'oracle.installer.autoupdates.downloadUpdatesLoc=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'AUTOUPDATES_MYORACLESUPPORT_USERNAME=' >> ${basedir}/db.rsp"
su - oracle -c "echo 'AUTOUPDATES_MYORACLESUPPORT_PASSWORD=' >> ${basedir}/db.rsp"

#################################################################################
#edit responseFile of instance                                                  #
#################################################################################
echo '[GENERAL]' > ${basedir}/dbca.rsp
echo 'RESPONSEFILE_VERSION ="'' 11.2.0''"' >> ${basedir}/dbca.rsp
echo 'OPERATION_TYPE = "''createDatabase''"' >> ${basedir}/dbca.rsp
echo '[CREATEDATABASE]' >> ${basedir}/dbca.rsp
echo 'GDBNAME = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo 'SID = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo 'TEMPLATENAME = "''General_Purpose.dbc''"' >> ${basedir}/dbca.rsp
echo 'SYSPASSWORD = "''oracle''"' >> ${basedir}/dbca.rsp
echo 'SYSTEMPASSWORD = "''oracle''"' >> ${basedir}/dbca.rsp
echo 'SYSMANPASSWORD = "''oracle''"' >> ${basedir}/dbca.rsp
echo 'CHARACTERSET = "''ZHS16GBK''"' >> ${basedir}/dbca.rsp
echo 'NATIONALCHARACTERSET= "''UTF8''"' >> ${basedir}/dbca.rsp
echo 'MEMORYPERCENTAGE = "'${perusemom}'"' >> ${basedir}/dbca.rsp
echo 'AUTOMATICMEMORYMANAGEMENT = "''TRUE''"' >> ${basedir}/dbca.rsp
echo '[createTemplateFromDB]' >> ${basedir}/dbca.rsp
echo 'SOURCEDB = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo 'SYSDBAUSERNAME = "''system''"' >> ${basedir}/dbca.rsp
echo 'TEMPLATENAME = "''My Copy TEMPLATE''"' >> ${basedir}/dbca.rsp
echo '[createCloneTemplate]' >> ${basedir}/dbca.rsp
echo 'SOURCEDB = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo 'SYSDBAUSERNAME = "''sys''"' >> ${basedir}/dbca.rsp
echo 'TEMPLATENAME = "''My Clone TEMPLATE''"' >> ${basedir}/dbca.rsp
echo '[DELETEDATABASE]' >> ${basedir}/dbca.rsp
echo 'SOURCEDB = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo 'SYSDBAUSERNAME = "''sys''"' >> ${basedir}/dbca.rsp
echo '[generateScripts]' >> ${basedir}/dbca.rsp
echo 'TEMPLATENAME = "''New Database''"' >> ${basedir}/dbca.rsp
echo 'GDBNAME = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo '[CONFIGUREDATABASE]' >> ${basedir}/dbca.rsp
echo '[ADDINSTANCE]' >> ${basedir}/dbca.rsp
echo 'DB_UNIQUE_NAME = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo 'INSTANCENAME = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo 'NODELIST=' >> ${basedir}/dbca.rsp
echo 'SYSDBAUSERNAME = "''sys''"' >> ${basedir}/dbca.rsp
echo '[DELETEINSTANCE]' >> ${basedir}/dbca.rsp
echo 'DB_UNIQUE_NAME = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo 'INSTANCENAME = "'${orasid}'"' >> ${basedir}/dbca.rsp
echo 'SYSDBAUSERNAME = "''oracle''"' >> ${basedir}/dbca.rsp
chown oracle:oinstall ${basedir}/dbca.rsp

#################################################################################
#uncompress the oracle install file                                             #
#################################################################################
su - oracle -c "unzip ${basedir}/p13390677_112040_Solaris86-64_1of6.zip -d ${basedir}/"
su - oracle -c "unzip ${basedir}/p13390677_112040_Solaris86-64_2of6.zip -d ${basedir}/"
chown -R oracle:oinstall  ${basedir}

#################################################################################
#install rdbms                                                                  #
#################################################################################
su - oracle -c "${basedir}/database/runInstaller -silent -noconfig -ignorePrereq -responseFile ${basedir}/db.rsp > ${basedir}/install.log"
echo ' '
echo -e "you use the command to get information about installation:\e[1;37m tail -f ${basedir}/install.log${c_end}"
sleep 1m
echo ' '

#################################################################################
#install instance                                                               #
#################################################################################
while true
do
    installRes=`tail -1 ${basedir}/install.log | awk '{print $1}'`
    if [[ "${installRes}" = "Successfully" ]];then
        ${basedir}/oraInventory/orainstRoot.sh
        ${orahome}/root.sh
        #create instance
        su - oracle -c "${orahome}/bin/dbca -silent -responseFile ${basedir}/dbca.rsp -cloneTemplate"
        break
    else
        sleep 20s
        continue
    fi
done

#start listen,the port is 1521
su - oracle -c "${orahome}/bin/netca /silent /responsefile ${basedir}/database/response/netca.rsp"
