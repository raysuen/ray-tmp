#!/bin/bash

data_path=`ps -ef | grep "bin/kingbase" | grep -v grep | awk '{print $10}'`
kingbase_path=`ps -ef | grep "bin/kingbase" | grep -v grep | awk '{print $8}'`
bin_path=${kingbase_path%/*}
export KINGBASE_PORT=`ps -ef | grep "bin/kingbase" |egrep -v "grep" | awk '{print "netstat -lantup 2> /dev/null | egrep "$2" |egrep tcp | egrep -v \"tcp6\" | awk -F'\''[ :]+'\'' '\''{print $5}'\''"}' | bash`

sed -i "s/^local   all/#local   all/g" ${data_path}/sys_hba.conf
sed -i '/#local   all.*/i local    all    all    trust' ${data_path}/sys_hba.conf
${bin_path}/sys_ctl -D ${data_path} reload
${bin_path}/ksql test sso -c "alter user sso password '12345678ab';"
${bin_path}/ksql test sao -c "alter user sao password '12345678ab';"

sed -i '/^local    all    all    trust/d' ${data_path}/sys_hba.conf
sed -i "s/^#local   all/local   all/g" ${data_path}/sys_hba.conf
${bin_path}/sys_ctl -D ${data_path} reload
#${bin_path}/ksql test sso -c "select now();"
