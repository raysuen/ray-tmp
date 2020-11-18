#!/bin/bash
#by raysuen
#v01

. ~/.bash_profile

####################################################################################
#install rpm that oracle is necessary for installing
####################################################################################
UnzipPRM(){
	[ `echo "${ORACLE_HOME}" | awk -F"/" '{print $NF}'` ] && rm -rf ${ORACLE_HOME}/ || rm -rf ${ORACLE_HOME}
	[ -f ~/LINUX.X64_193000_grid_home.zip ] && unzip ~/LINUX.X64_193000_grid_home.zip -d ${ORACLE_HOME} || echo "The Grid zip not find in grid home.";exit 99
}


####################################################################################
#create grid rsp file
####################################################################################
CreateGirdRspFile(){
	####################################################################################
	#get scanname
	####################################################################################
	if [ ! ${scanname} ];then
		while true
		do
			read -p "`echo -e "please enter the name for scanName.default \e[1;33mracscan\e[0m: "`" scanname   #get scanname
			echo -e "Your scanNmae is \e[1;33m" ${scanname:=racscan}"\e[0m."
			read -p "`echo -e "please confirm the scanNmae -\e[1;33m${scanname}\e[0m-, yes/no,default \e[1;33myes\e[0m: "`" scanConfirm  #confirm scanmae
			if [ ${scanConfirm:=yes} == "yes" ];then
				break
			elif [ ${scanConfirm:=yes} == "no" ];then
				continue
			else
				echo "Please enter yes or no."
				continue
			fi
		done
	fi
	####################################################################################
	#get cluster name
	####################################################################################
	if [ ! ${clustername} ];then
		while true
		do
			read -p "`echo -e "please enter the name for clusterName.default \e[1;33mserver-cluster\e[0m: "`" clustername       #get cluster name
			echo -e "Your scanNmae is \e[1;33m" ${clustername:=server-cluster}"\e[0m."
			read -p "`echo -e "please confirm the clusterName -\e[1;33m${clustername}\e[0m-, yes/no,default \e[1;33myes\e[0m: "`" clusterConfirm  #onfirm cluster name
			if [ ${clusterConfirm:=yes} == "yes" ];then
				break
			elif [ ${clusterConfirm:=yes} == "no" ];then
				continue
			else
				echo "Please enter yes or no."
				continue
			fi
		done
	fi
	####################################################################################
	#get hostname and hostname-vip
	####################################################################################
	if [ ! ${hostnames} ];then
		exhostnames="`hostname`:`hostname`-vip"
		while true
		do
			echo "please enter the whole nodes's hostname.And you use commas to separated the multiple groups of names。"
			read -p "`echo -e "Example: \e[1;33 ${exhostnames} \e[0m: "`" hostnames
			[ ${hostnames} ] && echo -e "Your hostnames are \e[1;33m " ${hostnames} " \e[0m." || {echo "\e[1;33The hostnames can be empty!!\e[0m";continue}
			read -p "`echo -e "please confirm the hostnames -\e[1;33m${hostnames}\e[0m-, yes/no,default \e[1;33myes\e[0m: "`" hostConfirm
			if [ ${hostConfirm:=yes} == "yes" ];then
				break
			elif [ ${hostConfirm:=yes} == "no" ];then
				continue
			else
				echo "Please enter yes or no."
				continue
			fi
		done
	fi


	####################################################################################
	#get IP Management style
	####################################################################################
	while true
	do
		echo ""
		echo "Enter a number for the specified interface to bind to how the network card is managed."
		echo "InterfaceType stand for the following values"
		echo -e "\e[1;33m   - 1 : PUBLIC\e[0m"
		echo -e "\e[1;33m   - 2 : PRIVATE\e[0m"
		echo -e "\e[1;33m   - 3 : DO NOT USE\e[0m"
		echo -e "\e[1;33m   - 4 : ASM\e[0m"
		echo -e "\e[1;33m   - 5 : ASM & PRIVATE\e[0m"
		unset NetworkMS #clear variable NetworkMS
		for i in `ip addr | egrep "^[2-9]" | awk -F ':' '{print $2}'`  #circuate the interface name
		do
			IPTemp=`/usr/sbin/ifconfig $i | egrep "broadcast|netmaskt" | awk '{print $2}' | sed ':label;N;s/\n//;b label' | sed -e 's/ //g' -e 's/)//g'`   #get IP of the interface 
			BroadTemp=`/usr/sbin/ifconfig $i | egrep "broadcast|netmaskt" | awk '{print $4}' | sed ':label;N;s/\n//;b label' | sed -e 's/ //g' -e 's/)//g'`  ##get broadcast of the interface 
			[ ${BroadTemp} ] || break   #if the broadcast is null then break 
			NetworkTemp=$(ipcalc -n  ${IPTemp} ${BroadTemp} | awk -F"=" '{print $2}')  #get network order ot ip and broadcast
    	    #get interface:network:networkManagement
			while true
			do
				
    	    	NetworkMSTemp=""
    	    	printf "%10s : %-20s: " $i ${NetworkTemp}  #show the interface:network
    	    	read -p "" NetworkMSTemp  #get networkManagement
    	    	#Determine if the input is a number
    	    	if [[ `grep '^[[:digit:]]*$' <<< "${NetworkMSTemp}"` ]] && [[ ${NetworkMSTemp} -le 5 ]];then
    	    		break 
    	    	else
    	    		echo "You must enter a number and the number less than 5！" 
    	    		continue
    	    	fi
			done
			#get the whole interface:network:networkManagement
			[ ${NetworkMS} ] && NetworkMS=`echo ${NetworkMS}","$i":"${NetworkTemp}":"${NetworkMSTemp}` || NetworkMS=`echo $i":"${NetworkTemp}":"${NetworkMSTemp}`
		done
		echo ""
		echo "Your interface management list:"
		NetworkMSArray=(${NetworkMS//,/ })
		for var in ${NetworkMSArray[@]}
		do
   			echo ${var} | awk -F":" '{if($3==1) {printf "    "$1":"$2":PUBLIC\n"} else if($3==2){printf "    "$1":"$2":PRIVATE\n"}else if($3==3){printf "    "$1":"$2":DO NOT USE\n"}else if($3==4){printf "    "$1":"$2":ASM\n"}else if($3==5){printf "    "$1":"$2":ASM & PRIVATE\n"}}'
   		done
   		#confirm the interfaces management
   		while true
   		do
   			read -p "`echo -e "please confirm the interface management, yes/no,default \e[1;33myes\e[0m: "`" interfaceConfirm
   			if [ ${interfaceConfirm:=yes} == "yes" ];then
   				break
   			elif [ ${interfaceConfirm:=yes} == "no" ];then
   				break
   			else
   				echo "You must yes or no."
   				continue
   			fi
   		done
   		[ ${interfaceConfirm} == "yes" ] && break || continue
 
	done
	
	[ -f  ~/grid.rsp ] && su - grid -c "sed -i '/^#OraConfBegin/,/^#OraConfEnd/d' ~/grid.rsp"
	su - grid -c "echo \"#OraConfBegin\" >> /~/grid.rsp"
	su - grid -c "echo \"oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0\" >> ~/grid.rsp"
	su - grid -c "echo \"INVENTORY_LOCATION=/u01/app/grid/oraInventory\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.option=CRS_CONFIG\" >> ~/grid.rsp"
	su - grid -c "echo \"ORACLE_BASE=/u01/app/grid\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.asm.OSDBA=asmdba\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.asm.OSOPER=asmoper\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.asm.OSASM=asmadmin\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.scanType=LOCAL_SCAN\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.SCANClientDataFile=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.gpnp.scanName=\"${scanname} >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.gpnp.scanPort=1521\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.ClusterConfiguration=STANDALONE\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.configureAsExtendedCluster=false\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.memberClusterManifestFile=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.clusterName=\"${clustername} >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.gpnp.configureGNS=false\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.autoConfigureClusterNodeVIP=false\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.gpnp.gnsOption=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.gpnp.gnsClientDataFile=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.gpnp.gnsSubDomain=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.gpnp.gnsVIPAddress=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.sites=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.clusterNodes=\"${hostnames} >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.networkInterfaceList=\"${NetworkMS} >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.configureGIMR=false\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.asm.configureGIMRDataDG=false\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.storageOption=FLEX_ASM_STORAGE\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.sharedFileSystemStorage.votingDiskLocations=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.sharedFileSystemStorage.ocrLocations=\" >> ~/grid.rsp"       	
	su - grid -c "echo \"oracle.install.crs.config.useIPMI=false\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.ipmi.bmcUsername=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.crs.config.ipmi.bmcPassword=\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.asm.SYSASMPassword\" >> ~/grid.rsp"
	su - grid -c "echo \"oracle.install.asm.diskGroup.name=OCR01
	su - grid -c "echo \"oracle.install.asm.diskGroup.redundancy=NORMAL
	su - grid -c "echo \"oracle.install.asm.diskGroup.AUSize=4
	su - grid -c "echo \"oracle.install.asm.diskGroup.FailureGroups=fg_ocr01,fg_ocr02,fg_ocr03,
	su - grid -c "echo \"oracle.install.asm.diskGroup.disksWithFailureGroupNames=/dev/oracleasm/disks/OCR01,fg_ocr01,/dev/oracleasm/disks/OCR02,fg_ocr02,/dev/oracleasm/disks/OCR03,fg_ocr03
	su - grid -c "echo \"oracle.install.asm.diskGroup.disks=/dev/oracleasm/disks/OCR01,/dev/oracleasm/disks/OCR02,/dev/oracleasm/disks/OCR03
	su - grid -c "echo \"oracle.install.asm.diskGroup.quorumFailureGroupNames=
	su - grid -c "echo \"oracle.install.asm.diskGroup.diskDiscoveryString=/dev/oracleasm/disks/*
	su - grid -c "echo \"oracle.install.asm.monitorPassword=
	su - grid -c "echo \"oracle.install.asm.gimrDG.name=
	su - grid -c "echo \"oracle.install.asm.gimrDG.redundancy=
	su - grid -c "echo \"oracle.install.asm.gimrDG.AUSize=1
	su - grid -c "echo \"oracle.install.asm.gimrDG.FailureGroups=
	su - grid -c "echo \"oracle.install.asm.gimrDG.disksWithFailureGroupNames=
	su - grid -c "echo \"oracle.install.asm.gimrDG.disks=
	su - grid -c "echo \"oracle.install.asm.gimrDG.quorumFailureGroupNames=
	su - grid -c "echo \"oracle.install.asm.configureAFD=false
	su - grid -c "echo \"oracle.install.crs.configureRHPS=false
	su - grid -c "echo \"oracle.install.crs.config.ignoreDownNodes=false               	
	su - grid -c "echo \"oracle.install.config.managementOption=NONE
	su - grid -c "echo \"oracle.install.config.omsHost=
	su - grid -c "echo \"oracle.install.config.omsPort=0
	su - grid -c "echo \"oracle.install.config.emAdminUser=
	su - grid -c "echo \"oracle.install.config.emAdminPassword=
	su - grid -c "echo \"oracle.install.crs.rootconfig.executeRootScript=false
	su - grid -c "echo \"oracle.install.crs.rootconfig.configMethod=
	su - grid -c "echo \"oracle.install.crs.rootconfig.sudoPath=
	su - grid -c "echo \"oracle.install.crs.rootconfig.sudoUserName=
	su - grid -c "echo \"oracle.install.crs.config.batchinfo=
	su - grid -c "echo \"oracle.install.crs.app.applicationAddress=
	su - grid -c "echo \"acle.install.crs.deleteNode.nodes=
}



