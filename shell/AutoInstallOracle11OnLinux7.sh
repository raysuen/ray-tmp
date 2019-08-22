#!/bin/bash
#by ray suen
#v0.3


#################################################################################
#before the bash you must install necessary rpm for oracle and edit hostname    #
#################################################################################
echo "please confirm that you have put the script and software into the base dir"
echo "please confirm that server can connect to internet"
c_yellow="\e[1;33m"
c_red="\e[1;31m"
c_end="\e[0m"

####################################################################################
#obtain ip
####################################################################################
echo " "
echo "internet name:"
for i in `ip addr | egrep "^[0-9]" | awk -F ':' '{print $2}'`
do
	echo -e "	\e[1;33m"$i": "`ifconfig $i | egrep -v "inet6" | awk -F 'net|netmaskt' '{print $2}' | sed ':label;N;s/\n//;b label' | sed -e 's/ //g' -e 's/)//g'`"\e[0m"
done

while true
do
	#read -p "please enter the name of Ethernet，default [eth0]:" eth
	read -p "`echo -e "please enter the name of Ethernet，default [${c_yellow}lo${c_end}]: "`" eth
	#get ip #ifconfig ${eth:-eth0} 2> /dev/null | grep -Po '(?<=inet addr:)[\d\.]+'
	ipaddr=`ifconfig ${eth:-lo} 2> /dev/null | egrep -v "inet6" | awk -F'inet|netmask' '{print $2}' | sed ':label;N;s/\n//;b label' | sed 's/ //g'`
	[ "${ipaddr:-None}" == "None" ]&& echo -e "pleas input the ${c_red}exact name of Ethernet${c_end}"&& continue
	if [ -n "$(echo ${ipaddr} | sed 's/[0-9]//g' | sed 's/.//g')" ];then
		echo -e 'shell can not obtain ip,pleas input the ${c_red}exact name of Ethernet${c_end}'
	continue
	else
		break
	fi
done


####################################################################################
#obtain base dir
####################################################################################
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

####################################################################################
#obtain hostname
####################################################################################
sname=$(hostname)  #get hostname
[ -z ${sname} ]&& echo -e 'shell can not obtain ${c_red}hostname${c_end},shell interrupt forcedly'&&exit 1

####################################################################################
#obtain ORACLE_BASE ORACLE_HOME
####################################################################################
orabase="${basedir}/oracle"    #set path of oracle_base
orahome="${basedir}/oracle/product/11.2.0/db_1" #set path of oracle_home

####################################################################################
#obtain ORACLE_SID
####################################################################################
read -p "`echo -e "please enter the sid.default [${c_yellow}orcl${c_end}]: "`" osid
orasid=${osid:-orcl} #set value of oracle_sid

####################################################################################
#obtain the momery percentage of the oracle using server momery
####################################################################################
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

####################################################################################
#obtain current day
####################################################################################
daytime=`date +%Y%m%d`

####################################################################################
#stop firefall  and disable selinux
####################################################################################
systemctl stop firewalld
systemctl disable firewalld
/usr/sbin/setenforce 0
cp /etc/selinux/config /etc/selinux/config.$(date +%F)
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

####################################################################################
#edit /etc/hosts
####################################################################################
cp /etc/hosts /etc/hosts${daytime}.bak
echo ${ipaddr}'  '${sname} >> /etc/hosts

####################################################################################
#edit sysctl.conf
####################################################################################
shmall=`/sbin/sysctl -a | grep "shmall" | awk '{print $NF}'`
shmmax=`/sbin/sysctl -a | grep "shmmax" | awk '{print $NF}'`

cp /etc/sysctl.conf /etc/sysctl.conf${daytime}.bak
echo 'kernel.shmall = '${shmall} >> /etc/sysctl.conf
echo 'kernel.shmmax = '${shmmax} >> /etc/sysctl.conf
echo 'kernel.shmmni = 4096' >> /etc/sysctl.conf
echo 'kernel.sem = 250 32000 100 128' >> /etc/sysctl.conf
echo 'fs.file-max = 6815744' >> /etc/sysctl.conf
echo 'net.ipv4.ip_local_port_range = 9000 65500' >> /etc/sysctl.conf
echo 'net.core.rmem_default = 262144' >> /etc/sysctl.conf
echo 'net.core.rmem_max = 4194304' >> /etc/sysctl.conf
echo 'net.core.wmem_default = 262144' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 1048576' >> /etc/sysctl.conf
echo 'fs.aio-max-nr=1048576' >> /etc/sysctl.conf

sysctl -p

####################################################################################
#edit limits.conf
####################################################################################
cp /etc/security/limits.conf /etc/security/limits.conf${daytime}.bak
echo 'oracle soft nproc 2047' >> /etc/security/limits.conf
echo 'oracle hard nproc 16384' >> /etc/security/limits.conf
echo 'oracle soft nofile 1024' >> /etc/security/limits.conf
echo 'oracle hard nofile 65536' >> /etc/security/limits.conf

####################################################################################
#edit pam.d/login
####################################################################################
cp /etc/pam.d/login /etc/pam.d/login${daytime}.bak
echo 'session required /lib64/security/pam_limits.so' >> /etc/pam.d/login
echo 'session required pam_limits.so' >> /etc/pam.d/login

#install rpm that oracle is necessary for installing
yum -y install binutils compat-libstdc++ compat-libcap1 gcc gcc-c++ glibc glibc*.i686 glibc-devel glibc-devel*.i686 ksh libaio*.i686 libaio libaio-devel*.i686 libaio-devel libgcc*.i686 libgcc libstdc++*.i686 libstdc++ libstdc++-devel*.i686 libstdc++-devel libXi*.i686 libXi libXtst*.i686 libXtst make sysstat unixODBC*.i686 unixODBC unixODBC-devel unzip 
yum -y localinstall compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm 
yum -y localinstall elfutils-libelf-devel-0.168-8.el7.x86_64.rpm

rpm -q compat-libstdc++-33 elfutils-libelf-devel  binutils compat-libcap1 gcc gcc-c++ glibc glibc.i686 glibc-devel glibc-devel.i686 ksh libaio.i686 libaio libaio-devel.i686 libaio-devel libgcc.i686 libgcc libstdc++.i686 libstdc++ libstdc++-devel.i686 libstdc++-devel libXi.i686 libXi libXtst.i686 libXtst make sysstat unixODBC.i686 unixODBC unixODBC-devel unzip --qf '%{name}.%{arch}\n'|sort

while true
do
	read -p "`echo -e "Please confirm that all rpm package have installed.[${c_yellow}yes/no${c_end}] default yes:"`" ans
	if [ "${ans:-yes}" == "yes" ];then
		break
	else
		continue
	fi
done

####################################################################################
# create user and groups for oracle installation
####################################################################################
groupadd -g 1100 oinstall
groupadd -g 1101 dba
groupadd -g 1102 oper
useradd  -u 1101 -g oinstall -G dba,oper oracle
echo "oracle" | passwd --stdin oracle

####################################################################################
#create directories for oracle installation
####################################################################################
mkdir -p ${orabase}
chown -R oracle:oinstall  ${basedir}
chmod -R 755  ${basedir}

####################################################################################
#edit oracle's bash
####################################################################################
su - oracle -c "cp /home/oracle/.bash_profile /home/oracle/.bash_profile${daytime}.bak"
su - oracle -c "echo 'ORACLE_BASE='${orabase} >> /home/oracle/.bash_profile"
su - oracle -c "echo 'ORACLE_HOME='${orahome} >> /home/oracle/.bash_profile"
su - oracle -c "echo 'ORACLE_SID='${orasid} >> /home/oracle/.bash_profile"
su - oracle -c "echo 'export ORACLE_BASE ORACLE_HOME ORACLE_SID' >> /home/oracle/.bash_profile"
su - oracle -c "echo 'export PATH=\$PATH:\$HOME/bin:\$ORACLE_HOME/bin' >> /home/oracle/.bash_profile"
su - oracle -c "echo 'export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK' >> /home/oracle/.bash_profile"
su - oracle -c "echo 'export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib' >> /home/oracle/.bash_profile"

####################################################################################
#uncompress the oracle install file
####################################################################################
su - oracle -c "unzip ${basedir}/p13390677_112040_Linux-x86-64_1of7.zip -d ${basedir}/"
su - oracle -c "unzip ${basedir}/p13390677_112040_Linux-x86-64_2of7.zip -d ${basedir}/"

####################################################################################
#edit responseFile of rdbms
####################################################################################
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
su - oracle -c "echo 'oracle.install.db.OPER_GROUP=oinstall' >> ${basedir}/db.rsp"
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

####################################################################################
#edit responseFile of instance
####################################################################################
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

####################################################################################
#change the owner and group of the  responseFile
####################################################################################
chown -R oracle:oinstall  ${basedir}
chmod -R 755  ${basedir}

####################################################################################
#check swap,swap must be greater then 150M
####################################################################################

while true
do
	swap=`free -m | grep Swap | awk '{print $4}'`
	if [[ ${swap} -lt 150 ]];then
		echo 'failed,swap less then 150M'
		echo 'please increase the space of swap, greater then 150M'
	else
		break
	fi
	echo "Have you been increased the space of swap?"
	read -p "`echo -e "Whether or not to check the space of swap? ${c_yellow}yes/no${c_end}. no will quit the intalling: "`" swapDone
	if [[ "${swapDone}" = "yes" ]];then
		continue
  	elif [[ "${swapDone}" = "no" ]];then
    	exit
  	else
  		echo "please enter yes/no"
  		continue
  	fi
done

####################################################################################
#install rdbms
####################################################################################
su - oracle -c "${basedir}/database/runInstaller -silent -noconfig -ignorePrereq -responseFile ${basedir}/db.rsp > ${basedir}/install.log"
#follow coding are create oracle instance.if you don't want to create install instance,you can use # making coding invalidly
echo ' '
echo ' '
echo -e "you use the command to get information about installation:\e[1;37m tail -f ${basedir}/install.log${c_end}"
sleep 1m
echo ' '

####################################################################################
#obtain datafile destination
####################################################################################
echo -e "Default datafile directory is ${c_yellow}${orabase}/oradata/${orasid}${c_end}"
while true
do
	read -p "`echo -e "You can specify another directory.Do you sure change datafile directory.default no .${c_yellow}yes/no ${c_end} :"`" ans
	if [ "${ans:-no}" == "yes" ];then
		while true
		do
			read -p "`echo -e "please enter your datafile directory: "`" datafiledir
			if [ "${datafiledir:-none}" == "none" ];then
				echo "The directory must be specified."
				continue
			else
				echo -e "The datafile directory is ${c_yellow}${datafiledir}${c_end}."
				read -p "`echo -e "Are you sure? Default yes. ${c_yellow}yes/no${c_end} :"`" ans2
				if [ "${ans2:-yes}" == "yes" ];then
					break
				else
					continue
				fi
			fi
		done
		break
		
	elif [ "${ans:-no}" == "no" ];then
		break
	else
		continue
	fi
done


####################################################################################
#install instance
####################################################################################
while true
do
	installRes=`tail -1 ${basedir}/install.log | awk '{print $1}'`
	if [[ "${installRes}" = "Successfully" ]];then
		${basedir}/oraInventory/orainstRoot.sh
		${orahome}/root.sh
		#create instance
		if [ "${datafiledir:-none}" == "none" ];then
			su - oracle -c "dbca -silent -responseFile ${basedir}/dbca.rsp -cloneTemplate"
		else
			if [ -d ${datafiledir} ];then
				chown oracle:oinstall ${datafiledir}
			else
				mkdir ${datafiledir}
				chown oracle:oinstall ${datafiledir}
			fi
			su - oracle -c "dbca -silent -responseFile ${basedir}/dbca.rsp -cloneTemplate -datafileDestination ${datafiledir}"
		fi
		break
	else
		sleep 20s
		continue
	fi
done

####################################################################################
#start listen,the port is 1521
####################################################################################
su - oracle -c "netca /silent /responsefile ${basedir}/database/response/netca.rsp"


####################################################################################
#edit tnsnames.ora   
####################################################################################
su - oracle -c "echo ${orasid}' =' >> ${orahome}/network/admin/tnsnames.ora"
su - oracle -c "echo '  (DESCRIPTION =' >> ${orahome}/network/admin/tnsnames.ora"
su - oracle -c "echo '    (ADDRESS_LIST =' >> ${orahome}/network/admin/tnsnames.ora"
su - oracle -c "echo '      (ADDRESS = (PROTOCOL = TCP)(HOST = '${sname}')(PORT = 1521))' >> ${orahome}/network/admin/tnsnames.ora"
su - oracle -c "echo '    )' >> ${orahome}/network/admin/tnsnames.ora"
su - oracle -c "echo '    (CONNECT_DATA =' >> ${orahome}/network/admin/tnsnames.ora"
su - oracle -c "echo '      (SERVICE_NAME = '${orasid}')' >> ${orahome}/network/admin/tnsnames.ora"
su - oracle -c "echo '    )' >> ${orahome}/network/admin/tnsnames.ora"
su - oracle -c "echo '  )' >> ${orahome}/network/admin/tnsnames.ora"

####################################################################################
#initial parameter
####################################################################################
su - oracle -c "sqlplus /nolog <<EOF
conn / as sysdba
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
alter system set open_cursors=3000 scope=both;
alter system set session_cached_cursors=100 scope=spfile;
alter system set processes=1500 scope=spfile;
alter system set sessions=1500 scope=spfile;
alter system set sec_case_sensitive_logon=false;
ALTER SYSTEM SET \"_use_adaptive_log_file_sync\"= false;
exit
EOF"

su - oracle -c "sqlplus /nolog <<EOF
conn / as sysdba
shutdown immediate;
startup
exit
EOF"

