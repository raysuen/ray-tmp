#!/bin/bash

# 高级fdisk自动分区脚本
# 支持GPT和MBR分区表
# 使用方法: sudo ./fdisk_auto_advanced.sh /dev/sdX [gpt|mbr],defaul mbr

set -e

# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 此脚本需要root权限"
    exit 1
fi

# 默认分区方案 (大小和文件系统类型)
#PARTITIONS=(
#    "5G ext4"
#    "10G xfs"
#    "remaining ext4"
#)
PARTITIONS=(
    "remaining ext4"
)

# 检查参数
if [ $# -lt 1 ]; then
    echo "错误: 请指定磁盘设备，例如 /dev/sdb"
    echo "用法: $0 /dev/sdX [gpt|mbr]"
    exit 1
fi

DISK=$1
PARTITION_TYPE=${2:-"mbr"}  # 默认为MBR

# 确认磁盘存在
if [ ! -b "$DISK" ]; then
    echo "错误: 磁盘设备 $DISK 不存在"
    exit 1
fi

# 显示当前磁盘信息
echo "当前磁盘信息:"
lsblk "$DISK"

# 警告信息
echo -e "\n警告: 此操作将完全擦除 $DISK 上的所有数据!"
echo -n "你确定要继续吗? (输入 'YES' 确认): "
read confirmation

if [ "$confirmation" == "YES" ] || [ "$confirmation" == "Y" ] || [ "$confirmation" == "y" ] || [ "$confirmation" == "yes" ]; then
    continue
else
	echo "操作已取消"
    exit 0
fi

Fdisk_Partions(){
	# 创建分区表
	echo -e "\n创建${PARTITION_TYPE^^}分区表..."
	{
    
    	echo o     # 创建MBR分区表   
    
    	# 创建各分区
    	for i in "${!PARTITIONS[@]}"; do
        	IFS=' ' read -r SIZE FSTYPE <<< "${PARTITIONS[$i]}"
        	echo n     # 新建分区
        	if [ "$PARTITION_TYPE" = "gpt" ]; then
            	echo   # 默认分区类型(主分区)
        	else
            	echo p # 主分区(MBR)
        	fi
        	echo $((i+1))  # 分区号
        
        	echo       # 默认起始扇区
        	if [ "$SIZE" != "remaining" ]; then
            	echo "+${SIZE}"  # 指定分区大小
        	else
            	echo   # 使用剩余空间
        	fi
    	done
    
    	echo w     # 写入并退出
	} | fdisk "$DISK"
}

Parted_GPT(){
	# 创建GPT分区表
	echo -e "\n创建GPT分区表..."
	parted -s "$DISK" mklabel gpt

	# 创建分区
	echo -e "\n创建分区..."
	START="0%"
	for i in "${!PARTITIONS[@]}"; do
    	IFS=' ' read -r SIZE FSTYPE <<< "${PARTITIONS[$i]}"
    	END="$SIZE"
    	if [ "$i" -eq $(( ${#PARTITIONS[@]} - 1 )) ]; then
        	END="100%"
    	fi
    
    	echo "创建分区 $((i+1)): $START-$END 文件系统: $FSTYPE"
    	parted -s "$DISK" mkpart primary "$START" "$END"
    
    	START="$END"
done

}


if [ "$PARTITION_TYPE" = "gpt" ]; then
        echo g     # 创建GPT分区表
    else
        Fdisk_Partions     # 调用创建MBR函数
 fi

# # 格式化分区
# echo -e "\n格式化分区..."
# for i in "${!PARTITIONS[@]}"; do
#     IFS=' ' read -r SIZE FSTYPE <<< "${PARTITIONS[$i]}"
#     PARTITION_NUM=$((i+1))
#     echo "格式化 ${DISK}${PARTITION_NUM} 为 $FSTYPE"
#     "mkfs.$FSTYPE" "${DISK}${PARTITION_NUM}"
# done

# 显示结果
echo -e "\n分区完成! 最终磁盘信息:"
fdisk -l "$DISK"