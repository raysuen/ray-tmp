#!/bin/bash
#############################脚本描述，区域开始##############################
## Filename : 
## Write by lpb
## Descript : 寻找集群中确认监视器所在服务器IP，本脚本必须以dmdba用户执行
#############################脚本描述，区域结束##############################


#############################配置数据库信息-必填##############################
USER=SYSDBA                #用户名
PASSWORD=SYSDBA         #密码
HOST=localhost          #主机名，默认使用localhost
PORT=5236                  #端口号，默认5236
#############################配置数据库信息-必填##############################


#############################内部逻辑处理##############################
# 检查是否为dmdba用户  
if [ ! "x$(whoami)" = "xdmdba" ]; then    
  echo "必须以dmdba用户执行此脚本！" >&2    
  exit 1    
fi

# 检查dmmonitor进程是否存在  
if pgrep -x dmmonitor > /dev/null; then   
    DMMONITOR_EXIST=true  
else    
    DMMONITOR_EXIST=false  
fi  
  
# 检查dmserver进程是否存在  
if pgrep -x dmserver > /dev/null; then   
    DMSERVER_EXIST=true  
else   
    DMSERVER_EXIST=false  
fi  


# 逻辑判断
if [ "$DMMONITOR_EXIST" = "false" ] && [ "$DMSERVER_EXIST" = "false" ]; then  
    # 打印结果
    echo "此节点不存在dmmonitor和dmserver服务，或dmmonitor和dmserver服务未启动，请更换节点执行此脚本！"
    
    # 根据需要设置退出状态,0正常退出，1异常退出
    exit 0
fi


# 逻辑判断 
if [ "$DMSERVER_EXIST" == "true" ]; then
    # 执行 disql 命令并捕获输出
    result=$(disql "/:${PORT} as sysdba" -E "SELECT MON_IP FROM "SYS"."v\$dmmonitor" WHERE MON_CONFIRM='TRUE';")
    
    # 可以使用更简单的 grep 和 sed 组合  
    ip_address=$(echo "${result}" | grep -oP '::ffff:([0-9.]+)' | head -n 1) 
    
    # 检查ip_address变量是否为空  
    if [ -z "$ip_address" ]; then  
        # 打印结果
        echo "集群内没有确认监视器！"  
    else  
        # 打印 IP 地址
        echo "确认监视器 IP 地址为: ${ip_address}"  
    fi
    
    # 根据需要设置退出状态,0正常退出，1异常退出
    exit 0 
fi
#disql命令可以直接在命令行中执行SQL查询并返回结果  
#等价于： disql SYSDBA/SYSDBA@localhost:5236 -E "SELECT MON_IP FROM "SYS"."v\$dmmonitor" WHERE MON_CONFIRM='TRUE';"
#disql "${USER}/${PASSWORD}@${HOST}:${PORT}" -E "SELECT MON_IP FROM "SYS"."v\$dmmonitor" WHERE MON_CONFIRM='TRUE';"


# 逻辑判断  
if [ "$DMMONITOR_EXIST" == "true" ] && [ "$DMSERVER_EXIST" == "false" ]; then
    # 打印 IP 地址
    echo "本机疑似存在确认监视器，请通过 ps -ef|grep '[d]mmonitor' 进一步确认！" 

    # 根据需要设置退出状态,0正常退出，1异常退出
    exit 0 
fi