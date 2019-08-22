#!/bin/bash
#by ray suen
#v0.9
#################################################################################
#before the bash you must install necessary rpm for oracle and edit hostname    #
#################################################################################
echo "please confirm that you have put the script and software into the base dir"
echo "please confirm that server can connect to internet"
c_yellow="\e[1;33m"
c_red="\e[1;31m"
c_end="\e[0m"

#obtain ip
echo " "
echo "internet name:"
for i in `ip addr | egrep "^[0-9]" | awk -F ':' '{print $2}'`
do
	echo -e "	${c_yellow}"$i": "`ifconfig ${i} 2> /dev/null | awk -F'addr:|Bcast' '/Bcast/{print $2}' | egrep "."`"${c_end}"
done
while true
do
  #read -p "please enter the name of Ethernet，default [eth0]:" eth
  read -p "`echo -e "please enter the name of Ethernet，default [${c_yellow}eth0${c_end}]: "`" eth
  #get ip #ifconfig ${eth:-eth0} 2> /dev/null | grep -Po '(?<=inet addr:)[\d\.]+'
  ipaddr=$(ifconfig ${eth:-eth0} 2> /dev/null | awk -F'addr:|Bcast' '/Bcast/{print $2}' | egrep ".") 
  [ $? != 0 ]&& echo -e "pleas input the ${c_red}exact name of Ethernet${c_end}"&& continue
  if [ -n "$(echo ${ipaddr} | sed 's/[0-9]//g' | sed 's/.//g')" ];then
    echo -e 'shell can not obtain ip,pleas input the ${c_red}exact name of Ethernet${c_end}'
    continue
  else
    break
  fi
done
#####
#obtain base dir
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
#obtain hostname
sname=$(hostname)  #get hostname
[ -z ${sname} ]&& echo -e 'shell can not obtain ${c_red}hostname${c_end},shell interrupt forcedly'&&exit 1

#obtain ORACLE_BASE ORACLE_HOME
orabase="${basedir}/oracle"    #set path of oracle_base
orahome="${basedir}/oracle/product/11.2.0/db_1" #set path of oracle_home

#obtain ORACLE_SID
read -p "`echo -e "please enter the sid.default [${c_yellow}orcl${c_end}]: "`" osid
orasid=${osid:-orcl} #set value of oracle_sid

#obtain the momery percentage of the oracle using server momery
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
daytime=`date +%Y%m%d`

/etc/init.d/iptables stop
/sbin/chkconfig iptables off
/usr/sbin/setenforce 0
cp /etc/selinux/config /etc/selinux/config.$(date +%F)
sed -i 's/^SELINUX=/#SELINUX=/g' /etc/selinux/config;echo 'SELINUX=disabled' >> /etc/selinux/config

#edit /etc/hosts
cp /etc/hosts /etc/hosts${daytime}.bak
echo ${ipaddr}'  '${sname} >> /etc/hosts
#edit sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf${daytime}.bak
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

#edit limits.conf
cp /etc/security/limits.conf /etc/security/limits.conf${daytime}.bak
echo 'oracle soft nproc 2047' >> /etc/security/limits.conf
echo 'oracle hard nproc 16384' >> /etc/security/limits.conf
echo 'oracle soft nofile 1024' >> /etc/security/limits.conf
echo 'oracle hard nofile 65536' >> /etc/security/limits.conf

#edit pam.d/login
cp /etc/pam.d/login /etc/pam.d/login${daytime}.bak
echo 'session required /lib64/security/pam_limits.so' >> /etc/pam.d/login
echo 'session required pam_limits.so' >> /etc/pam.d/login

#install rpm that oracle is necessary for installing
#yum -y install binutils compat-libstdc++-33* compat-libstdc++-33.i686 elfutils-libelf elfutils-libelf-devel elfutils-libelf-devel-static gcc gcc-c++ glibc* kernel-headers ksh libaio libaio.i686 libaio-devel libaio-devel.i686 libgcc libgcc.i686 libgomp libstdc++* libstdc++.i686 make sysstat unixODBC.i686 unixODBC.x86_64 unixODBC-devel.i686 unixODBC-devel.x86_64

if [ `sed -n '1p' /etc/issue | awk '{print $3}' | awk -F '.' '{print $1}'` == "5" -o `sed -n '1p' /etc/issue | awk -F '(' '{print $1}' | awk '{print $NF}' | awk -F '.' '{print $1}'` == "5" ];then
        yum -y install binutils compat-libstdc++-33* libXp* compat-libstdc++-33.i386 elfutils-libelf elfutils-libelf-devel elfutils-libelf-devel-static gcc gcc-c++ glibc* kernel-headers ksh libaio libaio.i386 libaio-devel libaio-devel.i386 libgcc libgcc.i386 libgomp libstdc++* libstdc++.i386 make sysstat unixODBC.i386 unixODBC.x86_64 unixODBC-devel.i386 unixODBC-devel.x86_64
elif [ `sed -n '1p' /etc/issue | awk '{print $3}' | awk -F '.' '{print $1}'` == "6" -o `sed -n '1p' /etc/issue | awk -F '(' '{print $1}' | awk '{print $NF}' | awk -F '.' '{print $1}'` == "6" ];then
        yum -y install binutils compat-libstdc++-33* compat-libstdc++-33.i686 elfutils-libelf elfutils-libelf-devel elfutils-libelf-devel-static gcc gcc-c++ glibc* kernel-headers ksh libaio libaio.i686 libaio-devel libaio-devel.i686 libgcc libgcc.i686 libgomp libstdc++* libstdc++.i686 make sysstat unixODBC.i686 unixODBC.x86_64 unixODBC-devel.i686 unixODBC-devel.x86_64
fi


#the follow well create a new user for oracle installation
groupadd -g 1000 oinstall
groupadd -g 1001 dba
useradd  -u 1001 -g oinstall -G dba oracle
echo "oracle" | passwd --stdin oracle
#the follow well create directories for oracle installation
mkdir -p ${orabase}
#mkdir -p /u01/software
chown -R oracle:oinstall  ${basedir}
chmod -R 755  ${basedir}
#edit oracle's bash
su - oracle -c "cp /home/oracle/.bash_profile /home/oracle/.bash_profile${daytime}.bak"
su - oracle -c "echo 'ORACLE_BASE='${orabase} >> /home/oracle/.bash_profile"
su - oracle -c "echo 'ORACLE_HOME='${orahome} >> /home/oracle/.bash_profile"
su - oracle -c "echo 'ORACLE_SID='${orasid} >> /home/oracle/.bash_profile"
su - oracle -c "echo 'export ORACLE_BASE ORACLE_HOME ORACLE_SID' >> /home/oracle/.bash_profile"
su - oracle -c "echo 'export PATH=\$PATH:\$HOME/bin:\$ORACLE_HOME/bin' >> /home/oracle/.bash_profile"
su - oracle -c "echo 'export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK' >> /home/oracle/.bash_profile"
su - oracle -c "echo 'export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib' >> /home/oracle/.bash_profile"

#uncompress the oracle install file
su - oracle -c "unzip ${basedir}/p13390677_112040_Linux-x86-64_1of7.zip -d ${basedir}/"
su - oracle -c "unzip ${basedir}/p13390677_112040_Linux-x86-64_2of7.zip -d ${basedir}/"

#edit responseFile of rdbms
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

#edit responseFile of instance
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

#change the owner and group of the  responseFile
chown -R oracle:oinstall  ${basedir}
chmod -R 755  ${basedir}


#xhost +

#check swap,swap must be greater then 150M
swap=`free -m | grep Swap | awk '{print $4}'`

while true
do
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

#install rdbms
su - oracle -c "${basedir}/database/runInstaller -silent -noconfig -ignorePrereq -responseFile ${basedir}/db.rsp > ${basedir}/install.log"
#follow coding are create oracle instance.if you don't want to create install instance,you can use # making coding invalidly
echo ' '
echo ' '
echo -e "you use the command to get information about installation:\e[1;37m tail -f ${basedir}/install.log${c_end}"
sleep 1m
echo ' '
#while true
#do
#  read -p "`echo -e "are you sure that the rdbms is installed ${c_yellow}yes/no${c_end}: "`" var
#  if [[ "${var}" = "yes" ]];then
#    ${basedir}/oraInventory/orainstRoot.sh
#    ${orahome}/root.sh
#    #create instance
#    su - oracle -c "dbca -silent -responseFile ${basedir}/dbca.rsp -cloneTemplate"
#    break
#  else
#    echo "Please wait that RDBMS installation is complete"
#    continue
#  fi
#done


#specify a datafile directory
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


#install instance
while true
do
	installRes=`tail -1 ${basedir}/install.log | awk '{print $1}'`
	if [[ "${installRes}" == "Successfully" ]];then
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



#start listen,the port is 1521
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


#SELECT * FROM dba_profiles s WHERE s.profile='DEFAULT' AND resource_name='PASSWORD_LIFE_TIME';
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













