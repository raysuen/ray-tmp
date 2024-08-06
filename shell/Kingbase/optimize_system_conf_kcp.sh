#!/bin/bash

####################################################################################################################                                                                                                                                                 
###                                                                                                                                                                                                                                                                  
### Descipt: this script help us to make a base optimization for system 
### Author : HM
### Create : 2020-04-28
###
### Usage  :
###        ./optimize_system_conf.sh
###
####################################################################################################################

echo "This tool help use to make a base optimization for system"
echo ""


#1.optimize System configuration
optimizeSystemConf(){
conf_exist=$(cat /etc/sysctl.conf|grep kingbase|wc -l)
if [ $conf_exist -eq 0 ]; then
    echo "optimize system core conf"
	cat >> /etc/sysctl.conf <<EOF
#add by kingbase
#/proc/sys/kernel/优化
# 10000 connect remain:
kernel.sem = 250 162500 250 650	 

#notice: shall shmmax is base on 16GB, you may adjust it for your MEM
#for 16GB Mem:
kernel.shmall = 3774873								
kernel.shmmax = 8589934592 

#for 32GB Mem:
#kernel.shmall = 7549747
#kernel.shmmax = 17179869184
#for 64GB Mem:
#kernel.shmall = 15099494
#kernel.shmmax = 34359738368
#for 128GB Mem:
#kernel.shmall = 30198988
#kernel.shmmax = 68719476736
#for 256GB Mem:
#kernel.shmall = 60397977
#kernel.shmmax = 137438953472
#for 512GB Mem:
#kernel.shmall = 120795955
#kernel.shmmax = 274877906944

kernel.shmmni = 4096		

vm.dirty_background_ratio=2 
vm.dirty_ratio = 40			

vm.overcommit_memory = 2	
vm.overcommit_ratio = 90 	

vm.swappiness = 1 				

fs.aio-max-nr = 1048576		
fs.file-max = 6815744		
fs.nr_open = 20480000       

# TCP端口使用范围
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 6000
# 记录的那些尚未收到客户端确认信息的连接请求的最大值
net.ipv4.tcp_max_syn_backlog = 65536
# 每个网络接口接收数据包的速率比内核处理这些包的速率快时，允许送到队列的数据包的最大数目
net.core.somaxconn=1024
net.core.netdev_max_backlog = 32768
net.core.wmem_default = 8388608
net.core.wmem_max = 1048576
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_syn_retries = 2
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_wmem = 8192 436600 873200
net.ipv4.tcp_rmem  = 32768 436600 873200
net.ipv4.tcp_mem = 94500000 91500000 92700000
net.ipv4.tcp_max_orphans = 3276800
EOF
echo "system configuration is optimized."
else
echo "system configuration is already optimized, so we do nothing"
fi
}


#2.Optimize Limit
optimizeLimitConf(){
conf_exist=$(cat /etc/security/limits.conf|grep kingbase|wc -l)
if [ $conf_exist -eq 0 ]; then
	echo "optimize limit configuration"
	cat >> /etc/security/limits.conf <<EOF
#add by kingbase
kingbase soft  nproc   65536
kingbase  hard  nproc   65536
kingbase  soft  nofile  65536
kingbase  hard  nofile  65536
kingbase  soft  stack   10240
kingbase  hard  stack   32768
kingbase soft core unlimited
kingbase hard core unlimited
EOF
echo "limit is optimized."
else
	echo "limit is already optimized, so we do nothing"
fi

# modify nproc.conf
if [ -f /etc/security/limits.d/90-nproc.conf ]; then
	conf_exist=$(cat /etc/security/limits.d/90-nproc.conf |grep kingbase|wc -l)
	if [ $conf_exist -eq 0 ]
	then
		echo "90-nproc modifing" 
		cat >> /etc/security/limits.d/90-nproc.conf <<EOF
kingbase soft nproc 65536
EOF
	else
		echo "90-nproc already modified, so we do nothing" 
	fi
elif [ -f /etc/security/limits.d/20-nproc.conf ]; then
	conf_exist=$(cat /etc/security/limits.d/20-nproc.conf |grep kingbase|wc -l)
	if [ $conf_exist -eq 0 ]
	then
		echo "20-nproc modifing" 
		cat >> /etc/security/limits.d/20-nproc.conf <<EOF
kingbase soft nproc 65536
EOF
	else
		echo "20-nproc already modified, so we do nothing" 
	fi
fi
}

#3.optimize selinux
optimizeSelinux(){
if [ -f /etc/selinux/config ]; then
	conf_exist=$(cat /etc/selinux/config|grep SELINUX=enforcing|wc -l)
	if [ $conf_exist -eq 1 ]; then
	sed -ie 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
		echo "SELinux is disabled."
	else
		echo "SELinux is already disabled, so we do nothing"
	fi
fi
}

#4.optimize RemoveIPC
optimizeRemoveIPC(){
if [ -f /etc/systemd/logind.conf ]; then
        conf_exist=$(cat /etc/systemd/logind.conf|grep -i -E '^RemoveIPC'|wc -l)
        if [ $conf_exist -eq 1 ]; then
                sed -ie 's/RemoveIPC=yes/RemoveIPC=no/g' /etc/systemd/logind.conf
		echo "RemoveIPC is set to no."
        else
                echo "RemoveIPC=no" >> /etc/systemd/logind.conf
                echo "RemoveIPC is set to no."
        fi
fi
}


#5.optimize sshd_confg
optimizesshd_config(){
if [ -f /etc/ssh/sshd_config ]; then
        conf_exist=$(cat /etc/ssh/sshd_config|grep -i -E '^PermitRootLogin'|wc -l)
        if [ $conf_exist -eq 1 ]; then
                sed -ie 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
        else
                echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
        fi
	conf_exist=$(cat /etc/ssh/sshd_config|grep -i -E '^GSSAPIAuthentication'|wc -l)
	if [ $conf_exist -eq 1 ]; then
                sed -ie 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
        else
                echo "GSSAPIAuthentication no" >> /etc/ssh/sshd_config
        fi
	conf_exist=$(cat /etc/ssh/sshd_config|grep -i -E '^UseDNS'|wc -l)
	if [ $conf_exist -eq 1 ]; then
        	sed -ie 's/UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
	else
        	echo "UseDNS no" >> /etc/ssh/sshd_config
	fi
	echo "/etc/ssh/sshd_config is optimized."
fi
}

#6.optimize system.conf
optimizesystemconf(){
if [ -f /etc/systemd/system.conf ]; then
        conf_exist=$(cat /etc/systemd/system.conf|grep -i -E '^DefaultTasksAccounting'|wc -l)
        if [ $conf_exist -eq 1 ]; then
                sed -ie 's/DefaultTasksAccounting=yes/DefaultTasksAccounting=no/g' /etc/systemd/system.conf
                echo "DefaultTasksAccounting is set to no."
        else
                echo "DefaultTasksAccounting=no" >> /etc/systemd/system.conf
                echo "DefaultTasksAccounting is set to no."
        fi
fi
}

#7.off firwalld 

#8.create user:username kingbase; password kingbase
#create user if not exists
create_kingbase_user_if_not_exist(){
egrep "^kingbase" /etc/passwd >& /dev/null
if [ $? -ne 0 ]
then
	useradd -m -U kingbase
	echo kingbase|passwd --stdin kingbase
	echo "kingbase user is created."
fi
}

#main:

#1.create kingbase user if not exists
echo "1.create kingbase user if not exists:"
create_kingbase_user_if_not_exist
echo ""

#2.optimize System configuration
echo "1.optimize system core configuration:"
optimizeSystemConf
sysctl -p >>/dev/null 2>&1
echo ""

#3.Optimize Limit
echo "2.optimize limit:"
optimizeLimitConf
echo ""

#4.Check Limit
echo "3.check limit:"
su - kingbase -c 'ulimit -a'|grep -E 'open files|max user processes'
echo ""

#5.optimize RemoveIPC
echo "4.optimize RemoveIPC"
optimizeRemoveIPC
echo ""

#6.optimize sshd_config
echo "6.optimize sshd_config:"
optimizesshd_config
echo ""

#7.optimize DefaultTasksAccounting
echo "7.optimize DefaultTasksAccounting"
optimizesystemconf
echo ""

#8.disable selinux
echo "5.disable selinux:"
optimizeSelinux
echo ""
#getenforce not support for UOS
#echo "5.check selinux:"
#getenforce
#echo ""

#9.disable firwalld
echo "7.disable firewall"
systemctl stop firewalld.service
systemctl disable firewalld.service
echo "firewall is disabled."

#10.device scheduler -- optimize by kingbase DBA

#11.DBA must manually check and set the date.

