#!/bin/bash
#by raysuen
#v2.0


#set -e
# BuildPassword(){
# 	while true
# 	do
# 		userpass=`openssl rand -base64 12`
# 		if [ `echo ${userpass} | egrep -o [[:digit:]] | wc -l` -ge 2 ] && [ `echo ${userpass} | egrep -o [[:alpha:]] | wc -l` -ge 2 ] && [ `echo ${userpass} | egrep -o [[:punct:]] | wc -l` -ge 2 ];then
# 			break
# 		fi
# 	done
# }

generate_password() {
    # 参数解析
    local length=$1
    local min_upper=${2:-1}   # 默认至少1个大写
    local min_lower=${3:-1}   # 默认至少1个小写
    local min_digits=${4:-1}  # 默认至少1个数字
    local min_special=${5:-1} # 默认至少1个特殊字符

    # 验证参数
    local min_total=$((min_upper + min_lower + min_digits + min_special))
    if [[ ! $length =~ ^[0-9]+$ ]] || [ $length -lt $min_total ] || [ $length -lt 8 ]; then
        echo "错误：密码长度必须≥8且≥各字符类型最小数量之和($min_total)" >&2
        return 1
    fi

    # 定义字符集（排除易混淆字符）
    local upper="ABCDEFGHJKLMNPQRSTUVWXYZ"  # 排除 I,O
    local lower="abcdefghjkmnpqrstuvwxyz"   # 排除 i,l,o
    local digits="23456789"                # 排除 0,1
    local special='@#()%^&*_+=-~`?!'         # 安全特殊字符
    
    # 生成满足最小数量要求的字符
    local password=""
    
    # 生成大写字母
    for ((i=0; i<min_upper; i++)); do
        password+="${upper:$(( RANDOM % ${#upper} )):1}"
    done
    
    # 生成小写字母
    for ((i=0; i<min_lower; i++)); do
        password+="${lower:$(( RANDOM % ${#lower} )):1}"
    done
    
    # 生成数字
    for ((i=0; i<min_digits; i++)); do
        password+="${digits:$(( RANDOM % ${#digits} )):1}"
    done
    
    # 生成特殊字符
    for ((i=0; i<min_special; i++)); do
        password+="${special:$(( RANDOM % ${#special} )):1}"
    done
    
    # 生成剩余随机字符
    local all_chars="${upper}${lower}${digits}${special}"
    local remaining=$((length - min_upper - min_lower - min_digits - min_special))
    
    if [ $remaining -gt 0 ]; then
        # 兼容性更好的随机字符串生成
        local rand_chars=$(LC_ALL=C tr -dc "$all_chars" < /dev/urandom | head -c $remaining)
        password+="$rand_chars"
    fi
    
    # 替代 shuf 的随机打乱方案
    {
        # 将字符串拆分为单个字符
        fold -w1 <<< "$password" | 
        # 使用 awk 添加随机数前缀
        awk 'BEGIN{srand()} {print rand(), $0}' | 
        # 按随机数排序
        sort -k1,1n | 
        # 移除随机数前缀
        cut -d' ' -f2- | 
        # 合并为一行
        tr -d '\n'
    } 2>/dev/null
    
    # echo # 添加换行符
}

#userpass=`generate_password 12 1 1 2 2`

ModifyPassword(){
	userpass=`generate_password 12 1 1 2 2`
	date_tmp=`date +"%Y%m%d%H%M"`
	kingbase_path=`ps -ef | grep "bin/kingbase" | grep -v grep | awk '{print $8}'`
	bin_path=${kingbase_path%/*}
	export KINGBASE_PORT=`ps -ef | grep "bin/kingbase" |egrep -v "grep" | awk '{print "netstat -lantup 2> /dev/null | egrep "$2" |egrep tcp | egrep -v \"tcp6\" | awk -F'\''[ :]+'\'' '\''{print $5}'\''"}' | bash`
# 	export KINGBASE_PASSWORD="12345678ab"
	[ -f /home/kingbase/.encpwd ]&& cp /home/kingbase/.encpwd /home/kingbase/.encpwd_${date_tmp}
	${bin_path}/sys_encpwd -H \* -P \* -D \* -U sso -W "12345678ab"
	${bin_path}/sys_encpwd -H \* -P \* -D \* -U sao -W "12345678ab"
	${bin_path}/ksql -U sso -d test -c "alter user sso password '${userpass}';"
	sso_res=`echo $?`
	${bin_path}/ksql -U sao -d test -c "alter user sao password '${userpass}';"
	sao_res=`echo $?`
# 	unset KINGBASE_PASSWORD
	if [ -f /home/kingbase/.encpwd_${date_tmp} ];then
		rm -f /home/kingbase/.encpwd && cp /home/kingbase/.encpwd_${date_tmp} /home/kingbase/.encpwd
	else
		rm -f /home/kingbase/.encpwd
	fi
	if [ ${sso_res} -eq 0 ] && [ ${sso_res} -eq 0 ];then
		echo -e "sso and sao passwords have been changed to \e[1;31m\""${userpass}"\"\e[0m"
	fi
}

ModifyPassword
