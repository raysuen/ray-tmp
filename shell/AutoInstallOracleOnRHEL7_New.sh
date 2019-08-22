#!/bin/bash
#by raysuen
#v01

#################################################################################
#before the bash you must install necessary rpm for oracle and edit hostname    #
#################################################################################
echo "please confirm that you have put the script and software into the base dir"
echo ""
c_yellow="\e[1;33m"
c_red="\e[1;31m"
c_end="\e[0m"
echo ""

OraZipName="p13390677_112040_Linux-x86-64_1of7.zip,p13390677_112040_Linux-x86-64_2of7.zip"


####################################################################################
#stop firefall  and disable selinux
####################################################################################
StopFirewallAndDisableSelinux(){
	systemctl stop firewalld
	systemctl disable firewalld
	/usr/sbin/setenforce 0
	cp /etc/selinux/config /etc/selinux/config.$(date +%F)
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
}



####################################################################################
#obtain ip
####################################################################################
ObtainIP(){
	if [ "${eth:-None}" == "None" ];then
		echo "internet name:"
		for i in `ip addr | egrep "^[0-9]" | awk -F ':' '{print $2}'`
		do
			echo -e "	\e[1;33m"$i": "`ifconfig $i | egrep -v "inet6" | awk -F 'net|netmaskt' '{print $2}' | sed ':label;N;s/\n//;b label' | sed -e 's/ //g' -e 's/)//g'`"\e[0m"
		done
		
		while true
		do
			read -p "`echo -e "please enter the name of Ethernet，default [${c_yellow}lo${c_end}]: "`" eth
			ipaddr=`ifconfig ${eth:-lo} 2> /dev/null | egrep -v "inet6" | awk -F'inet|netmask' '{print $2}' | sed ':label;N;s/\n//;b label' | sed 's/ //g'`
			[ "${ipaddr:-None}" == "None" ]&& echo -e "pleas input the ${c_red}exact name of Ethernet${c_end}"&& continue
			if [ -n "$(echo ${ipaddr} | sed 's/[0-9]//g' | sed 's/.//g')" ];then
				echo -e 'shell can not obtain ip,pleas input the ${c_red}exact name of Ethernet${c_end}'
			continue
			else
				break
			fi
		done
	else
		ipaddr=`ifconfig ${eth:-lo} 2> /dev/null | egrep -v "inet6" | awk -F'inet|netmask' '{print $2}' | sed ':label;N;s/\n//;b label' | sed 's/ //g'`
		if [ "${ipaddr:-None}" == "None" ];then
    		echo -e "please enter ${c_red}a exiting interface name${c_end} "
    		exit 96
  		fi
	fi
}

####################################################################################
#obtain base dir
####################################################################################

ObtainBasedir(){
	if [ "${basedir:-None}" == "None" ];then
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
	else
		if [ ! -d ${basedir} ];then
			echo -e "the ${basedir} is not exsist,please ${c_red}make it up${c_end}"
			exit 95
		fi
	fi 
}

####################################################################################
#obtain ORACLE_SID
####################################################################################
ObtainSID(){
	if [ "${osid:-None}" == "None" ];then
		read -p "`echo -e "please enter the sid.default [${c_yellow}orcl${c_end}]: "`" oside
	fi
	orasid=${osid:-orcl}
}

####################################################################################
#obtain the momery percentage of the oracle using server momery
####################################################################################
ObtainMemPerc(){
	if [ "${mper:-None}" == "None" ];then
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
	else
		perusemom=${mper}
	fi
}

####################################################################################
#install rpm that oracle is necessary for installing
####################################################################################
InstallRPM(){
	yum -y install binutils compat-libstdc++ elfutils-libelf-devel compat-libcap1 gcc gcc-c++ glibc glibc*.i686 glibc-devel glibc-devel*.i686 ksh libaio*.i686 libaio libaio-devel*.i686 libaio-devel libgcc*.i686 libgcc libstdc++*.i686 libstdc++ libstdc++-devel*.i686 libstdc++-devel libXi*.i686 libXi libXtst*.i686 libXtst make sysstat unixODBC*.i686 unixODBC unixODBC-devel unzip 
	yum -y localinstall compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm 
	yum -y localinstall elfutils-libelf-devel-0.168-8.el7.x86_64.rpm
	while true
	do
		if [ `rpm -q compat-libstdc++-33 elfutils-libelf-devel  binutils compat-libcap1 gcc gcc-c++ glibc glibc.i686 glibc-devel glibc-devel.i686 ksh libaio.i686 libaio libaio-devel.i686 libaio-devel libgcc.i686 libgcc libstdc++.i686 libstdc++ libstdc++-devel.i686 libstdc++-devel libXi.i686 libXi libXtst.i686 libXtst make sysstat unixODBC.i686 unixODBC unixODBC-devel unzip --qf '%{name}.%{arch}\n'| grep "not installed" | wc -l ` -gt 0 ];then
			rpm -q compat-libstdc++-33 elfutils-libelf-devel  binutils compat-libcap1 gcc gcc-c++ glibc glibc.i686 glibc-devel glibc-devel.i686 ksh libaio.i686 libaio libaio-devel.i686 libaio-devel libgcc.i686 libgcc libstdc++.i686 libstdc++ libstdc++-devel.i686 libstdc++-devel libXi.i686 libXi libXtst.i686 libXtst make sysstat unixODBC.i686 unixODBC unixODBC-devel unzip --qf '%{name}.%{arch}\n'| grep "not installed"
			read -p "`echo -e "Please confirm that all rpm package have installed.[${c_yellow}yes/no${c_end}] default yes:"`" ans
			if [ "${ans:-yes}" == "yes" ];then
				break
			else
				continue
			fi
		else
			break
		fi
	done
}

####################################################################################
#obtain basic infomation
####################################################################################
ObtainBasicInfo(){
	################################################################################
	#obtain hostname
	################################################################################
	sname=$(hostname) 
	[ -z ${sname} ]&& echo -e 'shell can not obtain ${c_red}hostname${c_end},shell interrupt forcedly'&&exit 1

	################################################################################
	#obtain ORACLE_BASE ORACLE_HOME
	################################################################################
	orabase="${basedir}/oracle"    #set path of oracle_base
	orahome="${basedir}/oracle/product/11.2.0/db_1" #set path of oracle_home
}

####################################################################################
#check swap,swap must be greater then 150M
####################################################################################

CheckSwap(){
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
	    	exit 94
	  	else
	  		echo "please enter yes/no"
	  		continue
	  	fi
	done
}


####################################################################################
# create user and groups for oracle installation,edit bash_profile
####################################################################################
CreateGUAndEditprofile(){
	####################################################################################
	# create user and groups for oracle installation
	####################################################################################
	groupadd -g 1100 oinstall
	groupadd -g 1101 dba
	groupadd -g 1102 oper
	useradd  -u 1101 -g oinstall -G dba,oper oracle
	
	if [ $? -ne 0 ];then
		echo "Oracle is not existing."
		exit  93
	fi
	echo "oracle" | passwd --stdin oracle
	if [ $? -ne 0 ];then
		echo "Oracle is not existing."
		exit  92
	fi
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
	
}
	
####################################################################################
#edit linux parameter files
####################################################################################
EditParaFiles(){
	####################################################################################
	#obtain current day
	####################################################################################
	daytime=`date +%Y%m%d`
	####################################################################################
	#edit /etc/hosts
	####################################################################################
	sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/hosts #delete content
	if [ `grep ${ipaddr} | wc -l` -eq 0 ];then
		cp /etc/hosts /etc/hosts${daytime}.bak
		echo "#OraConfBegin" >> /etc/hosts
		echo ${ipaddr}'  '${sname} >> /etc/hosts
		echo "#OraConfEnd" >> /etc/hosts
	fi
	
	####################################################################################
	#edit sysctl.conf
	####################################################################################
	shmall=`/sbin/sysctl -a | grep "shmall" | awk '{print $NF}'`
	shmmax=`/sbin/sysctl -a | grep "shmmax" | awk '{print $NF}'`
	
	sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/sysctl.conf #delete content
	cp /etc/sysctl.conf /etc/sysctl.conf.${daytime}
	echo "#OraConfBegin" >> /etc/sysctl.conf
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
	echo "#OraConfEnd" >> /etc/sysctl.conf
	
	sysctl -p
	
	####################################################################################
	#edit limits.conf
	####################################################################################
	sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/security/limits.conf
	cp /etc/security/limits.conf /etc/security/limits.conf.${daytime}
	echo "#OraConfBegin" >> /etc/security/limits.conf
	echo 'oracle soft nproc 2047' >> /etc/security/limits.conf
	echo 'oracle hard nproc 16384' >> /etc/security/limits.conf
	echo 'oracle soft nofile 1024' >> /etc/security/limits.conf
	echo 'oracle hard nofile 65536' >> /etc/security/limits.conf
	echo "#OraConfEnd" >> /etc/security/limits.conf
	
	####################################################################################
	#edit pam.d/login
	####################################################################################
	sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/pam.d/login
	cp /etc/pam.d/login /etc/pam.d/login.${daytime}
	echo "#OraConfBegin" >> /etc/pam.d/login
	echo 'session required /lib64/security/pam_limits.so' >> /etc/pam.d/login
	echo 'session required pam_limits.so' >> /etc/pam.d/login
	echo "#OraConfEnd" >> /etc/pam.d/login
}


####################################################################################
#edit rsp files
####################################################################################
EditRspFiles(){
	
	####################################################################################
	#edit responseFile of rdbms
	####################################################################################
		#SELECTED_LANGUAGES:en english,zh_CN:simplified Chinese
	echo 'oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v11_2_0' > ${basedir}/db.rsp
	echo 'oracle.install.option=INSTALL_DB_SWONLY' >> ${basedir}/db.rsp
	echo 'ORACLE_HOSTNAME='${sname} >> ${basedir}/db.rsp
	echo 'UNIX_GROUP_NAME=oinstall' >> ${basedir}/db.rsp
	echo 'INVENTORY_LOCATION='${basedir}'/oraInventory' >> ${basedir}/db.rsp
	echo 'SELECTED_LANGUAGES=en' >> ${basedir}/db.rsp
	echo 'ORACLE_HOME='${orahome} >> ${basedir}/db.rsp
	echo 'ORACLE_BASE='${orabase} >> ${basedir}/db.rsp
	echo 'oracle.install.db.InstallEdition=EE' >> ${basedir}/db.rsp
	echo 'oracle.install.db.EEOptionsSelection=false' >> ${basedir}/db.rsp
	echo 'oracle.install.db.optionalComponents=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.DBA_GROUP=dba' >> ${basedir}/db.rsp
	echo 'oracle.install.db.OPER_GROUP=oinstall' >> ${basedir}/db.rsp
	echo 'oracle.install.db.CLUSTER_NODES=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.isRACOneInstall=false' >> ${basedir}/db.rsp
	echo 'oracle.install.db.racOneServiceName=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.type=GENERAL_PURPOSE' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.globalDBName=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.SID=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.characterSet=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.memoryOption=false' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.memoryLimit=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.installExampleSchemas=false' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.enableSecuritySettings=true' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.password.ALL=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.password.SYS=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.password.SYSTEM=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.password.SYSMAN=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.password.DBSNMP=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.control=DB_CONTROL' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.gridcontrol.gridControlServiceURL=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.automatedBackup.enable=false' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.automatedBackup.osuid=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.automatedBackup.ospwd=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.storageType=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.fileSystemStorage.dataLocation=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.starterdb.fileSystemStorage.recoveryLocation=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.asm.diskGroup=' >> ${basedir}/db.rsp
	echo 'oracle.install.db.config.asm.ASMSNMPPassword=' >> ${basedir}/db.rsp
	echo 'MYORACLESUPPORT_USERNAME=' >> ${basedir}/db.rsp
	echo 'MYORACLESUPPORT_PASSWORD=' >> ${basedir}/db.rsp
	echo 'SECURITY_UPDATES_VIA_MYORACLESUPPORT=false' >> ${basedir}/db.rsp
	echo 'DECLINE_SECURITY_UPDATES=true' >> ${basedir}/db.rsp
	echo 'PROXY_HOST=' >> ${basedir}/db.rsp
	echo 'PROXY_PORT=' >> ${basedir}/db.rsp
	echo 'PROXY_USER=' >> ${basedir}/db.rsp
	echo 'PROXY_PWD=' >> ${basedir}/db.rsp
	echo 'PROXY_REALM=' >> ${basedir}/db.rsp
	echo 'COLLECTOR_SUPPORTHUB_URL=' >> ${basedir}/db.rsp
	echo 'oracle.installer.autoupdates.option=SKIP_UPDATES' >> ${basedir}/db.rsp
	echo 'oracle.installer.autoupdates.downloadUpdatesLoc=' >> ${basedir}/db.rsp
	echo 'AUTOUPDATES_MYORACLESUPPORT_USERNAME=' >> ${basedir}/db.rsp
	echo 'AUTOUPDATES_MYORACLESUPPORT_PASSWORD=' >> ${basedir}/db.rsp
	
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

}

####################################################################################
#uncompress the oracle install file
####################################################################################
UnzipOra(){
	if [ "${oraname:-None}" == "None" ];then
		array=(${OraZipName//,/ })
		for var in ${array[@]}
		do
		   su - oracle -c "unzip ${basedir}/$var -d ${basedir}/"
		done
	else
		array=(${oraname//,/ })
		for var in ${array[@]}
		do
		   su - oracle -c "unzip $var -d ${basedir}/"
		done
	fi
	
}

####################################################################################
#obtain datafile destination
####################################################################################
ObtainDatafileDir(){
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
}


####################################################################################
#install rdbms
####################################################################################
InstallRdbms(){
	su - oracle -c "${basedir}/database/runInstaller -silent -noconfig -ignorePrereq -responseFile ${basedir}/db.rsp > ${basedir}/install.log"
	#follow coding are create oracle instance.if you don't want to create install instance,you can use # making coding invalidly
	echo ' '
	echo ' '
	echo -e "you use the command to get information about installation:\e[1;37m tail -f ${basedir}/install.log${c_end}"
	sleep 1m
	echo ' '
	while true
	do
		installRes=`tail -1 ${basedir}/install.log | awk '{print $1}'`
		if [[ "${installRes}" = "Successfully" ]];then
			${basedir}/oraInventory/orainstRoot.sh
			${orahome}/root.sh
			echo -e "${c_yellow} RDBMS has been installed.${c_end}"
			break
		else
			sleep 20s
			continue
		fi
	done
}


####################################################################################
#install instance
####################################################################################
InstallInstance(){
	while true
	do
		installRes=`tail -1 ${basedir}/install.log | awk '{print $1}'`
		if [[ "${installRes}" = "Successfully" ]];then
			#create instance
			if [ "${datafiledir}" == "default" ];then
				su - oracle -c "dbca -silent -responseFile ${basedir}/dbca.rsp -cloneTemplate"
			elif [ -n "${datafiledir}" ];then
				if [ -d ${datafiledir} ];then
					chown oracle:oinstall ${datafiledir}
				else
					mkdir ${datafiledir}
					chown oracle:oinstall ${datafiledir}
				fi
				su - oracle -c "dbca -silent -responseFile ${basedir}/dbca.rsp -cloneTemplate -datafileDestination ${datafiledir}"
			else
				ObtainDatafileDir
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
			fi
			break
		else
			sleep 20s
			continue
		fi
	done

}

####################################################################################
#start listen,the port is 1521
####################################################################################
ConfigListen(){
	su - oracle -c "netca /silent /responsefile ${basedir}/database/response/netca.rsp"
}

####################################################################################
#edit tnsnames.ora   
####################################################################################
ConfigTnsnames(){
	su - oracle -c "echo ${orasid}' =' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '  (DESCRIPTION =' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '    (ADDRESS_LIST =' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '      (ADDRESS = (PROTOCOL = TCP)(HOST = '${sname}')(PORT = 1521))' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '    )' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '    (CONNECT_DATA =' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '      (SERVICE_NAME = '${orasid}')' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '    )' >> ${orahome}/network/admin/tnsnames.ora"
	su - oracle -c "echo '  )' >> ${orahome}/network/admin/tnsnames.ora"
}

####################################################################################
#initial parameter
####################################################################################
InitialPara(){
	su - oracle -c "sqlplus /nolog <<-RAY
	conn / as sysdba
	ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
	alter system set open_cursors=1500 scope=both;
	alter system set session_cached_cursors=100 scope=spfile;
	alter system set processes=1000 scope=spfile;
	alter system set sessions=1000 scope=spfile;
	alter system set sec_case_sensitive_logon=false;
	ALTER SYSTEM SET \"_use_adaptive_log_file_sync\"= false;
	exit
	RAY"
	
	su - oracle -c "sqlplus /nolog <<-RAY
	conn / as sysdba
	shutdown immediate;
	startup
	exit
	RAY"
}

####################################################################################
#install function
####################################################################################
InstallFun(){
	StopFirewallAndDisableSelinux
	ObtainBasedir
	ObtainSID
	ObtainMemPerc
	ObtainIP
	ObtainBasicInfo
	CheckSwap
	InstallRPM
	CreateGUAndEditprofile
	EditRspFiles
	UnzipOra
	InstallRdbms
	if [ "${installoption}" == "yes" ];then
		exit 0
	fi
	InstallInstance
	ConfigListen
	ConfigTnsnames
	InitialPara
}

####################################################################################
#help
####################################################################################
help_fun(){
	echo "Discription:"
	echo "		This is a script to install oracle 11G RDBMS and instance."
	echo "Parameters:"
	echo "		--listeninterface		specify a existing name of Etherne for oracle listen."
	echo "		--oraclesid				specify a oracle sid."
	echo "		--memorypercent			specify a number for oracle useing,the number is percentage"
	echo "		--basedirectory			specify a base directory."
	echo "		--datafilepath			if you do not want to use the defaut directory,you can specify a directory name."
	echo "		--usedefaultdatapath	if you want to use the defaut directory,you can use this parameter."
	echo "								attention:You just can use one parameter in --datafilepath and --usedefaultdatapath."
	echo "		--notinstallinstance	if you use this parameter,means you just install RDBMS witout instance."
	echo "Example:"
	echo "		bash AutoInstallOracleOnRHEL7_New.sh"
	echo "			means that you use communication to set parameters."
	echo "		bash AutoInstallOracleOnRHEL7_New.sh --listeninterface eth0 --oraclesid orcl --memorypercent 80 --basedirectory /u01 --datafilepath /u01/oradata --oraclesoftname oracle_linux_1of7.zip,oracle_linux_2of7.zip,"
	echo "		bash AutoInstallOracleOnRHEL7_New.sh --listeninterface eth0 --oraclesid orcl --memorypercent 80 --basedirectory /u01 --notinstallinstance"
	echo ""
	echo ""
	echo ""
}


####################################################################################
#The entry of the script
####################################################################################

#
#obtain the values of parameters
#
while (($#>=1))
do
	#
	#to sure is the parameter start with --
	#
	if [ `echo $1 | egrep "^--"` ];then
		if [ "$1" == "--usedefaultdatapath" ];then
			datafiledir="default"
			shift
			continue
		fi 
		if [ "$1" == "--notinstallinstance" ];then
			installoption=yes
			shift
			continue
		fi
		pastpara=$1
		shift
		if [ `echo $1 | egrep "^--"` ];then
			echo "The value of ${pastpara} must be specified!"
			exit 99
		fi

		case `echo $pastpara | sed s/--//g` in
			listeninterface)
				eth=$1
			;;
			basedirectory)
				basedir=$1
			;;
			oraclesid)
				osid=$1
			;;
			memorypercent)
				mper=$1
				if [ -n "`echo ${mper} | sed 's/[0-9]//g' | sed 's/-//g'`" ];then
    				echo -e "please enter ${c_red}exact number${c_end} for $pastpara"
    				exit 97
  				fi
			;;
			oraclesoftname)
				oraname=$1
			;;
			datafilepath)
				datafiledir=$1
			;;
			help)
				help_fun
				exit 0
			;;
			*)
				echo "$lastpara is a illegal parameter!"
				exit 98
			;;
		esac
	else
		shift
		continue
	fi

done

####################################################################################
#begin to install
####################################################################################
InstallFun



#bash AutoInstallOracleOnRHEL7_New.sh --help
#bash AutoInstallOracleOnRHEL7_New.sh --listeninterface eth0 --oraclesid orcl --memorypercent 80 --basedirectory /u01 --datafilepath /u02/oradata --oraclesoftname p13390677_112040_Linux-x86-64_1of7.zip,p13390677_112040_Linux-x86-64_2of7.zip
#--oraclesoftname,You must specify a absolute path.
#You just use one,between --usedefaultdatapath and --datafilepath