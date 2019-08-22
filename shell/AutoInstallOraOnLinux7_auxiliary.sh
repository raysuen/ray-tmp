#!/bin/bash
#by raysuen
#v01

if [ $# -eq 1 ];then
	orahome=$1/oracle/product/11.2.0/db_1
else
	orahome=/u01/oracle/product/11.2.0/db_1
fi



while true
do
	if [ -f ${orahome}/sysman/lib/ins_emagent.mk ];then
		sed -i 's/$(MK_EMAGENT_NMECTL)/$(MK_EMAGENT_NMECTL)-lnnz11/g' $orahome/sysman/lib/ins_emagent.mk
		break
	fi
done

################help#################
#AutoInstalllOraOnLinux7_auxiliary.sh basedir
#default /u01
################help#################