#!/bin/bash
#by raysuen
#v1.0


# generate_password() {
#     # 参数验证
#     if [[ ! $1 =~ ^[0-9]+$ ]] || [ $1 -lt 8 ]; then
#         echo "错误：密码长度必须为至少8位的正整数" >&2
#         return 1
#     fi

#     # 定义密码字符集
#     local upper="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
#     local lower="abcdefghijklmnopqrstuvwxyz"
#     local numbers="0123456789"
#     local special='@#$%^&*_+=-~`?!'
    
#     # 组合基础字符集（排除易混淆字符）
#     local base_chars="ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789"
    
#     # 生成密码
#     local pass=$(head /dev/urandom | LC_ALL=C tr -dc "$base_chars$special" | head -c $(( $1 - 4 )))
    
#     # 确保包含所有字符类别
#     pass+="${upper:$(( RANDOM % ${#upper} )):1}"
#     pass+="${lower:$(( RANDOM % ${#lower} )):1}"
#     pass+="${numbers:$(( RANDOM % ${#numbers} )):1}"
#     pass+="${special:$(( RANDOM % ${#special} )):1}"
    
#     # 随机打乱密码
#     echo "$pass" | fold -w1 | shuf | tr -d '\n'
#     echo # 添加换行符
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
    
    echo # 添加换行符
}


help_fun(){
	echo "random.sh usage:
	    -L      Specify the length of strings,default 12.
		-u：		Specify the number of capital letters,default 1.
		-l:		Specify the number of lowercase letters,default 1.
		-d:		Specify the number of digit,default 1.
		-s:		Specify the number of special characters,default 1.
	example:
		random.sh -L 10
		random.sh -L 10 -u 2
		random.sh -L 10 -u 2 -l 2 
		random.sh -L 10 -u 2 -l 2  -d 2 -s 2

	"
	
}

# generate_password $1

# # 生成12位密码（各类型至少1个）
# generate_password 12

# # 生成16位密码（3大写/2小写/3数字/2特殊）
# generate_password 16 3 2 3 2

# # 生成10位密码（无特殊字符）
# generate_password 10 2 2 2 0

##################################################################
#脚本的执行入口，获取参数
##################################################################
main(){
	str_len=12 #默认字符串长度12
	str_upper=1 #默认大写字符数量最少1
	str_lower=1 #默认小写字符数量最少1
	str_digit=1 #默认数字数量最少1
	str_spical=1 #默认特殊字符数量最少1
	# if [ $# -eq 0 ];then
	# 	echo "Please using -h to get helping." 
	# 	exit 0
	# fi
	while (($#>=1))   #循环获取脚本参数
	do
    	case `echo $1 | sed s/-//g ` in
    	    H)        #-h获取帮助
    	        help_fun          #执行帮助函数
    	        exit 0
    	    ;;
    	    h)          #-h获取帮助
    	        shelp_fun          #执行帮助函数
    	        exit 0
    	    ;;
    	    L)    #获取字符串商都
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify a right parameter."
    	        	echo "You can use -h or -H to get help."
    	        	exit 98
    	    	else
    	    		str_len=$1
    	    	fi
    	    	shift
    	    ;;
    	    u)    #获取大写字符数量
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify a right parameter."
    	        	echo "You can use -h or -H to get help."
    	        	exit 97
    	    	else
    	    		str_upper=$1
    	    	fi
    	    	shift
    	    ;;
    	    l)    #获取小写字符长度
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify a right parameter."
    	        	echo "You can use -h or -H to get help."
    	        	exit 97
    	    	else
    	    		str_lower=$1
    	    	fi
    	    	shift

    	    ;;
    	    d)   #获取数字数量
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify a right parameter."
    	        	echo "You can use -h or -H to get help."
    	        	exit 97
    	    	else
    	    		str_digit=$1
    	    	fi
    	    	shift

    	    ;;
			s)   #获取特殊字符数量
    	    	shift
    	    	if [ $# -eq 0 ];then
    	    		echo "You must specify a right parameter."
    	        	echo "You can use -h or -H to get help."
    	        	exit 97
    	    	else
    	    		str_spical=$1
    	    	fi
    	    	shift

    	    ;;
    	    *)
    	        echo "You must specify a right parameter."
    	        echo "You can use -h or -H to get help."
    	        exit 95
    	    ;;
    	esac
	done

	generate_password 	${str_len} ${str_upper} ${str_lower} ${str_digit} ${str_spical}
}


main $*
