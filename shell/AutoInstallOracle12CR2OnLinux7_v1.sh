#!/bin/bash
#by raysuen
#v01

export LANG=C

#################################################################################
#before the bash you must install necessary rpm for oracle and edit hostname    #
#################################################################################
echo "please confirm that you have put the script and software into the base dir"
echo ""
c_yellow="\e[1;33m"
c_red="\e[1;31m"
c_end="\e[0m"
echo ""

####################################################################################
#stop firefall  and disable selinux
####################################################################################
StopFirewallAndDisableSelinux(){
	systemctl stop firewalld
	systemctl disable firewalld
	if [ "`/usr/sbin/getenforce`" != "Disabled" ];then
		/usr/sbin/setenforce 0
	fi
	if [ ! -z `grep "SELINUX=enforcing" /etc/selinux/config` ];then
		cp /etc/selinux/config /etc/selinux/config.$(date +%F)
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	fi
	
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
		read -p "`echo -e "please enter the sid.default [${c_yellow}orcl${c_end}]: "`" osid
	fi
	#echo ${osid}
	orasid=${osid:-orcl}
	su - oracle -c "sed -i 's/^ORACLE_SID=$/ORACLE_SID='${orasid}'/g' ~/.bash_profile"
	source ~/.bash_profile
	
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
	#sed -i 's/^MEMORYPERCENTAGE = \"\"$/MEMORYPERCENTAGE = "'${perusemom}'"/g' ${basedir}/dbca.rsp
	
}

####################################################################################
#install rpm that oracle is necessary for installing
####################################################################################
InstallRPM(){
	yum -y install binutils compat-libcap1 compat-libstdc++ compat-libstdc++*.i686 gcc gcc-c++ glibc-2*.i686 glibc glibc-devel*.i686 glibc-devel ksh libgcc libgcc-*.i686 libstdc++*.i686 libstdc++ libstdc++-devel libstdc++devel*.i686 libaio-*.i686 libaio libaio-*.i686 libaio-devel libaio-devel*.i686 make sysstat unixODBC-devel unixODBC*.i686
	# -y localinstall compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm 
	#yum -y localinstall elfutils-libelf-devel-0.168-8.el7.x86_64.rpm
	ls -l compat* elfutils* | awk -v rpmpackage="" '{rpmpackage=$NF" "rpmpackage}END{print "yum -y localinstall "rpmpackage}' | bash 
	while true
	do
		if [ `rpm -q compat-libstdc++-33 elfutils-libelf-devel binutils compat-libcap1 compat-libstdc++ compat-libstdc++*.i686 gcc gcc-c++ glibc-2*.i686 glibc glibc-devel*.i686 glibc-devel ksh libgcc libgcc-*.i686 libstdc++*.i686 libstdc++ libstdc++-devel libstdc++devel*.i686 libaio-*.i686 libaio libaio-*.i686 libaio-devel libaio-devel*.i686 make sysstat unixODBC-devel unixODBC*.i686 --qf '%{name}.%{arch}\n'| grep "not installed" | wc -l` -gt 0 ];then
			rpm -q compat-libstdc++-33 elfutils-libelf-devel binutils compat-libcap1 compat-libstdc++ compat-libstdc++*.i686 gcc gcc-c++ glibc-2*.i686 glibc glibc-devel*.i686 glibc-devel ksh libgcc libgcc-*.i686 libstdc++*.i686 libstdc++ libstdc++-devel libstdc++devel*.i686 libaio-*.i686 libaio libaio-*.i686 libaio-devel libaio-devel*.i686 make sysstat unixODBC-devel unixODBC*.i686 --qf '%{name}.%{arch}\n' | grep "not installed"
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
	orabase="${basedir}/app/oracle"    #set path of oracle_base
	orahome="${basedir}/app/oracle/product/12.2.0/db_1" #set path of oracle_home
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
	if [ `egrep "oinstall|dba|oper" /etc/group | wc -l` -eq 0 ];then
		groupadd -g 1100 oinstall
		groupadd -g 1101 dba
		groupadd -g 1102 oper
	fi
	if [ `egrep "oracle" /etc/passwd | wc -l` -eq 0 ];then
		useradd  -u 1101 -g oinstall -G dba,oper oracle
		if [ $? -ne 0 ];then
			echo "Oracle is not existing."
			exit  93
		fi
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
	su - oracle -c "sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /home/oracle/.bash_profile"
	su - oracle -c "echo \"#OraConfBegin\" /home/oracle/.bash_profile"
	su - oracle -c "echo 'ORACLE_BASE='${orabase} >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'ORACLE_HOME='${orahome} >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'ORACLE_SID=' >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'export ORACLE_BASE ORACLE_HOME ORACLE_SID' >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'export PATH=\$PATH:\$HOME/bin:\$ORACLE_HOME/bin' >> /home/oracle/.bash_profile"
	su - oracle -c "echo 'export NLS_LANG=AMERICAN_AMERICA.AL32UTF8' >> /home/oracle/.bash_profile"           #AL32UTF8,ZHS16GBK
	su - oracle -c "echo 'export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$ORACLE_HOME/lib' >> /home/oracle/.bash_profile"
	su - oracle -c "echo \"#OraConfEnd\" /home/oracle/.bash_profile"
	
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
	if [ `grep ${ipaddr} /etc/hosts | wc -l` -eq 0 ];then
		cp /etc/hosts /etc/hosts.${daytime}
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
	echo 'oracle soft stack 10240' >> /etc/security/limits.conf
	echo 'oracle hard stack 10240' >> /etc/security/limits.conf
	echo "#OraConfEnd" >> /etc/security/limits.conf
	
	####################################################################################
	#edit pam.d/login
	####################################################################################
	#sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' /etc/pam.d/login
	#cp /etc/pam.d/login /etc/pam.d/login.${daytime}
	#echo "#OraConfBegin" >> /etc/pam.d/login
	#echo 'session required /lib64/security/pam_limits.so' >> /etc/pam.d/login
	#echo 'session required pam_limits.so' >> /etc/pam.d/login
	#echo "#OraConfEnd" >> /etc/pam.d/login
}


####################################################################################
#edit rdbms rsp files
####################################################################################
EditRdbmsRspFiles(){
	
	####################################################################################
	#edit responseFile of rdbms
	####################################################################################
		#SELECTED_LANGUAGES:en english,zh_CN:simplified Chinese
	if [ -f "${basedir}/rdbms.rsp" ];then
		rm -f ${basedir}/rdbms.rsp
	fi
	echo 'oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.2.0' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.option=INSTALL_DB_SWONLY' >> ${basedir}/rdbms.rsp
	echo 'UNIX_GROUP_NAME=oinstall' >> ${basedir}/rdbms.rsp
	echo 'INVENTORY_LOCATION='/${basedir}'/app/oraInventory' >> ${basedir}/rdbms.rsp
	echo 'ORACLE_HOME='${orahome} >> ${basedir}/rdbms.rsp
	echo 'ORACLE_BASE='${orabase} >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.InstallEdition=EE' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSDBA_GROUP=dba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSOPER_GROUP=oper' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSBACKUPDBA_GROUP=dba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSDGDBA_GROUP=dba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSKMDBA_GROUP=dba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.OSRACDBA_GROUP=dba' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.rac.configurationType=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.CLUSTER_NODES=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.isRACOneInstall=false' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.racOneServiceName=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.rac.serverpoolName=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.rac.serverpoolCardinality=0' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.type=GENERAL_PURPOSE' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.globalDBName=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.SID=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.ConfigureAsContainerDB=false' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.PDBName=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.characterSet=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.memoryOption=false' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.memoryLimit=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.installExampleSchemas=false' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.ALL=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.SYS=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.SYSTEM=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.DBSNMP=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.password.PDBADMIN=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.managementOption=DEFAULT' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.omsHost=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.omsPort=0' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.emAdminUser=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.emAdminPassword=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.enableRecovery=false' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.storageType=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.fileSystemStorage.dataLocation=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.starterdb.fileSystemStorage.recoveryLocation=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.asm.diskGroup=' >> ${basedir}/rdbms.rsp
	echo 'oracle.install.db.config.asm.ASMSNMPPassword=' >> ${basedir}/rdbms.rsp
	echo 'MYORACLESUPPORT_USERNAME=' >> ${basedir}/rdbms.rsp
	echo 'MYORACLESUPPORT_PASSWORD=' >> ${basedir}/rdbms.rsp
	echo 'SECURITY_UPDATES_VIA_MYORACLESUPPORT=false' >> ${basedir}/rdbms.rsp
	echo 'DECLINE_SECURITY_UPDATES=true' >> ${basedir}/rdbms.rsp
	echo 'PROXY_HOST=' >> ${basedir}/rdbms.rsp
	echo 'PROXY_PORT=' >> ${basedir}/rdbms.rsp
	echo 'PROXY_USER=' >> ${basedir}/rdbms.rsp
	echo 'PROXY_PWD=' >> ${basedir}/rdbms.rsp
	echo 'COLLECTOR_SUPPORTHUB_URL=' >> ${basedir}/rdbms.rsp

	
	####################################################################################
	#change the owner and group of the  responseFile
	####################################################################################
	chown -R oracle:oinstall  ${basedir}
	chmod -R 755  ${basedir}

}


####################################################################################
#edit dbca 122 rsp files
####################################################################################
EditDbca122RspFiles(){
	####################################################################################
	#edit responseFile of instance
	####################################################################################
	#ZHS16GBK
	sga=`free -m | awk '/Mem/{print int($2*('${perusemom}'/100)*0.75)}'`
	pga=`free -m | awk '/Mem/{print int($2*('${perusemom}'/100)*0.25)}'`
	echo 'responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v12.2.0' > ${basedir}/dbca.rsp
	echo 'gdbName='${orasid} >> ${basedir}/dbca.rsp
	echo 'sid='${orasid} >> ${basedir}/dbca.rsp
	echo 'databaseConfigType=SI' >> ${basedir}/dbca.rsp
	echo 'RACOneNodeServiceName=' >> ${basedir}/dbca.rsp
	echo 'policyManaged=false' >> ${basedir}/dbca.rsp
	echo 'createServerPool=false' >> ${basedir}/dbca.rsp
	echo 'serverPoolName=' >> ${basedir}/dbca.rsp
	echo 'cardinality=' >> ${basedir}/dbca.rsp
	echo 'force=false' >> ${basedir}/dbca.rsp
	echo 'pqPoolName=' >> ${basedir}/dbca.rsp
	echo 'pqCardinality=' >> ${basedir}/dbca.rsp
	echo 'createAsContainerDatabase=false' >> ${basedir}/dbca.rsp
	echo 'numberOfPDBs=0' >> ${basedir}/dbca.rsp
	echo 'pdbName=' >> ${basedir}/dbca.rsp
	echo 'useLocalUndoForPDBs=true' >> ${basedir}/dbca.rsp
	echo 'pdbAdminPassword=' >> ${basedir}/dbca.rsp
	echo 'nodelist=' >> ${basedir}/dbca.rsp
	echo 'templateName='${orahome}'/assistants/dbca/templates/New_Database.dbt' >> ${basedir}/dbca.rsp
	echo 'sysPassword=oracle' >> ${basedir}/dbca.rsp
	echo 'systemPassword=oracle' >> ${basedir}/dbca.rsp
	echo 'serviceUserPassword=' >> ${basedir}/dbca.rsp
	echo 'emConfiguration=' >> ${basedir}/dbca.rsp
	echo 'emExpressPort=5500' >> ${basedir}/dbca.rsp
	echo 'runCVUChecks=false' >> ${basedir}/dbca.rsp
	echo 'dbsnmpPassword=' >> ${basedir}/dbca.rsp
	echo 'omsHost=' >> ${basedir}/dbca.rsp
	echo 'omsPort=0' >> ${basedir}/dbca.rsp
	echo 'emUser=' >> ${basedir}/dbca.rsp
	echo 'emPassword=' >> ${basedir}/dbca.rsp
	echo 'dvConfiguration=false' >> ${basedir}/dbca.rsp
	echo 'dvUserName=' >> ${basedir}/dbca.rsp
	echo 'dvUserPassword=' >> ${basedir}/dbca.rsp
	echo 'dvAccountManagerName=' >> ${basedir}/dbca.rsp
	echo 'dvAccountManagerPassword=' >> ${basedir}/dbca.rsp
	echo 'olsConfiguration=false' >> ${basedir}/dbca.rsp
	echo 'datafileJarLocation=' >> ${basedir}/dbca.rsp
	echo 'datafileDestination=' >> ${basedir}/dbca.rsp
	echo 'recoveryAreaDestination=' >> ${basedir}/dbca.rsp
	echo 'storageType=' >> ${basedir}/dbca.rsp
	echo 'diskGroupName=' >> ${basedir}/dbca.rsp
	echo 'asmsnmpPassword=' >> ${basedir}/dbca.rsp
	echo 'recoveryGroupName=' >> ${basedir}/dbca.rsp
	echo 'characterSet=AL32UTF8' >> ${basedir}/dbca.rsp
	echo 'nationalCharacterSet=AL16UTF16' >> ${basedir}/dbca.rsp
	echo 'registerWithDirService=false' >> ${basedir}/dbca.rsp
	echo 'dirServiceUserName=' >> ${basedir}/dbca.rsp
	echo 'dirServicePassword=' >> ${basedir}/dbca.rsp
	echo 'walletPassword=' >> ${basedir}/dbca.rsp
	echo 'listeners=' >> ${basedir}/dbca.rsp
	echo 'variablesFile=' >> ${basedir}/dbca.rsp
	echo 'variables=DB_UNIQUE_NAME='${orasid}',ORACLE_BASE='${orabase}',PDB_NAME=,DB_NAME='${orasid}',ORACLE_HOME='${orahome}',SID='${orasid} >> ${basedir}/dbca.rsp
	echo 'initParams=undo_tablespace=UNDOTBS1,processes=1000,nls_language=AMERICAN,pga_aggregate_target='${pga}'MB,sga_target='${sga}'MB,dispatchers=(PROTOCOL=TCP) (SERVICE=orclXDB),db_block_size=8192BYTES,diagnostic_dest={ORACLE_BASE},audit_file_dest={ORACLE_BASE}/admin/{DB_UNIQUE_NAME}/adump,nls_territory=AMERICA,compatible=12.2.0,control_files=("{ORACLE_BASE}/oradata/{DB_UNIQUE_NAME}/control01.ctl", "{ORACLE_BASE}/oradata/{DB_UNIQUE_NAME}/control02.ctl"),db_name=orcl,audit_trail=db,remote_login_passwordfile=EXCLUSIVE,open_cursors=300' >> ${basedir}/dbca.rsp
	echo 'sampleSchema=false' >> ${basedir}/dbca.rsp
	echo 'memoryPercentage='${perusemom} >> ${basedir}/dbca.rsp
	echo 'databaseType=MULTIPURPOSE' >> ${basedir}/dbca.rsp
	echo 'automaticMemoryManagement=false' >> ${basedir}/dbca.rsp
	echo 'totalMemory=0' >> ${basedir}/dbca.rsp
	chown oracle:oinstall ${basedir}/dbca.rsp
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
#obtain install instance options
####################################################################################
ObtainInstanceOption(){
	echo -e ""
	while true
	do
		read -p "`echo -e "Do you want to install the database instance.${c_yellow}yes/no ${c_end} :"`" installoption
		if [ "${installoption:-None}" == "None" ];then
			echo "Please enter yes or no."
			continue
			
		elif [ "${installoption:-None}" == "no" ];then
			exit 0
		elif [ "${installoption:-None}" == "yes" ];then
			break
		else
			echo "Please enter valid value. yes/no."
			continue
		fi
	done
}

InstallRdbms(){
	su - oracle -c "${basedir}/database/runInstaller -silent -noconfig -ignorePrereq -showProgress -responseFile ${basedir}/rdbms.rsp > ${basedir}/install.log"
	#follow coding are create oracle instance.if you don't want to create install instance,you can use # making coding invalidly
	echo ' '
	echo ' '
	echo -e "you use the command to get information about installation:\e[1;37m tail -f ${basedir}/install.log${c_end}"
	sleep 1m
	echo ' '
	while true
	do
		installRes=`egrep "Successfully Setup Software" ${basedir}/install.log | awk '{print $1}'`
		if [[ "${installRes}" = "Successfully" ]];then
			${basedir}/app/oraInventory/orainstRoot.sh
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
		installRes=`egrep "Successfully Setup Software" ${basedir}/install.log | awk '{print $1}'`
		if [[ "${installRes}" = "Successfully" ]];then
			#create instance
			if [ "${datafiledir}" == "default" ];then
				su - oracle -c "dbca -silent -createDatabase -responseFile ${basedir}/dbca.rsp"
			elif [ -n "${datafiledir}" ];then
				if [ -d ${datafiledir} ];then
					chown oracle:oinstall ${datafiledir}
				else
					mkdir ${datafiledir}
					chown oracle:oinstall ${datafiledir}
				fi
				su - oracle -c "dbca -silent -createDatabase -responseFile ${basedir}/dbca.rsp -datafileDestination ${datafiledir}"
			else
				ObtainDatafileDir
				if [ "${datafiledir:-none}" == "none" ];then
					su - oracle -c "dbca -silent -createDatabase -responseFile ${basedir}/dbca.rsp "
				else
					if [ -d ${datafiledir} ];then
						chown oracle:oinstall ${datafiledir}
					else
						mkdir ${datafiledir}
						chown oracle:oinstall ${datafiledir}
					fi
					su - oracle -c "dbca -silent -createDatabase -responseFile ${basedir}/dbca.rsp  -datafileDestination ${datafiledir}"
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
	InstallRPM
	StopFirewallAndDisableSelinux
	ObtainBasedir
	ObtainIP
	ObtainBasicInfo
	CheckSwap
	CreateGUAndEditprofile
	EditParaFiles
	EditRdbmsRspFiles
	InstallRdbms
	if [ "${installoption}" == "no" ];then
		exit 0
	elif [ "${installoption:-None}" == "None" ];then
		ObtainInstanceOption
	fi
	ObtainMemPerc
	ObtainSID
	EditDbca122RspFiles
	InstallInstance
	ConfigListen
	ConfigTnsnames
	InitialPara
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
			installoption=no
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

