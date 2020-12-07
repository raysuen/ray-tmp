#!/bin/bash
#by raysuen
#v01
#################################################################################
#执行脚本前：
#	1. 创建实力前确认存储数据的磁盘组存在
#	2. 安装包放在oracle家目录内
#
#################################################################################


. ~/.bash_profile

####################################################################################
#unzip oracle rdbms software and install rdbms
####################################################################################
UnzipAndInstallRdbms(){
	echo "${ORACLE_HOME}" | awk -F"/" '{if($NF=="") {print "rm -rf "$0"*"} else {print "rm -rf "$0"/*"}}' | bash
	if [ -f ~/LINUX.X64_193000_db_home.zip ];then
		unzip ~/LINUX.X64_193000_db_home.zip -d ${ORACLE_HOME}
		[ $? -ne 0 ] && exit 98
	else
		echo "The DB zip not find in oracle home."
		exit 99
	fi
	NodeList=`sed -n '/^#public ip/,/^#private ip/p' /etc/hosts | egrep "^[[:digit:]]" | awk '{printf $2","}' | awk '{print substr($0,1,length($0)-1)}'`
	${ORACLE_HOME}/runInstaller -ignorePrereq -waitforcompletion -silent \
   		-responseFile ${ORACLE_HOME}/install/response/db_install.rsp \
   		oracle.install.option=INSTALL_DB_SWONLY \
   		UNIX_GROUP_NAME=oinstall \
   		INVENTORY_LOCATION=${ORACLE_BASE}/oraInventory \
   		SELECTED_LANGUAGES=en,en_GB \
   		ORACLE_HOME=${ORACLE_HOME} \
   		ORACLE_BASE=${ORACLE_BASE} \
   		oracle.install.db.InstallEdition=EE \
		oracle.install.db.OSDBA_GROUP=dba \
		oracle.install.db.OSOPER_GROUP=oper \
		oracle.install.db.OSBACKUPDBA_GROUP=backupdba \
		oracle.install.db.OSDGDBA_GROUP=dgdba \
		oracle.install.db.OSKMDBA_GROUP=kmdba \
		oracle.install.db.OSRACDBA_GROUP=racdba \
		oracle.install.db.rootconfig.executeRootScript=false \
		oracle.install.db.CLUSTER_NODES=${NodeList}
		oracle.install.db.config.starterdb.type=GENERAL_PURPOSE \
		oracle.install.db.ConfigureAsContainerDB=false \
		oracle.install.db.config.starterdb.memoryOption=false \
		oracle.install.db.config.starterdb.installExampleSchemas=false \
		oracle.install.db.config.starterdb.managementOption=DEFAULT \
		oracle.install.db.config.starterdb.omsPort=0 \
		oracle.install.db.config.starterdb.enableRecovery=false
}

####################################################################################
#entrance of script
####################################################################################
UnzipAndInstallRdbms






