#!/bin/bash
#by raysuen
#v 1.0

#close firewalld
systemctl stop firewalld 
systemctl disable firewalld

#close selunux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
getenforce

#close numa
if [[ `egrep numa=off /etc/default/grub | wc -l` -eq 1 ]];then
	pass
elif [[ `egrep numa=on /etc/default/grub | wc -l` -eq 1 ]];then
	sed -i 's/numa=on/numa=off/g' /etc/default/grub
elif [[ `egrep numa /etc/default/grub | wc -l` -eq 0 ]];then
	sed -is "/^GRUB_CMDLINE_LINUX/s/\"/ numa=off\"/2" /etc/default/grub
fi

#禁用透明大页
echo never > /sys/kernel/mm/transparent_hugepage/enabled

#创建用户
groupadd dinstall -g 2001
groupadd dmdba -g 2002
useradd  -g dinstall -G dmdba -m -d /home/dmdba -s /bin/bash -u 2001 dmdba


#编辑limits.conf
cat <<EOF > /etc/security/limits.conf
* soft nproc 65536
* hard nproc 65536
* soft nofile 65536
* hard nofile 65536


dmdba soft nice 65536
dmdba hard nice 65536
dmdba soft as unlimited
dmdba hard as unlimited
dmdba soft fsize unlimited
dmdba hard fsize unlimited
dmdba soft nproc 65536
dmdba hard nproc 65536
dmdba soft nofile 65536
dmdba hard nofile 65536
dmdba soft core unlimited
dmdba hard core unlimited
dmdba soft data unlimited
dmdba hard data unlimited
EOF

sysctl -p
