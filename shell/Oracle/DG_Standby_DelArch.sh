#!/bin/bash
#by raysuen
#v1.0
# 功能：删除Oracle每个THREAD中排行>3的归档日志，支持本地登录（用户密码为空时）
# 函数模块：环境初始化、登录判断、SQL查询、RMAN删除

# -------------------------- 配置参数（根据实际环境修改） --------------------------
DB_USER=""           # 数据库用户（为空时尝试本地登录）
DB_PASS=""           # 数据库密码（与用户同时为空时启用本地登录）
DB_HOST="localhost"  # 主机地址（本地登录可忽略）
DB_PORT="1521"       # 端口（本地登录可忽略）
ORACLE_SID="orcl"    # 数据库SID（必填）
ORACLE_HOME="/u01/app/oracle/product/19c/dbhome_1"
LOG_FILE="./delete_arch_rn3_$(date +%Y%m%d).log"  # 执行日志
# ---------------------------------------------------------------------------------


# 函数1：初始化环境变量和日志
init_env() {
  echo "===== 环境初始化：$(date +'%Y-%m-%d %H:%M:%S') =====" >> "$LOG_FILE"
  
  # 设置Oracle环境变量
  export ORACLE_SID="$ORACLE_SID"
  [ -n "$ORACLE_HOME" ] || export ORACLE_HOME="/u01/app/oracle/product/19c/dbhome_1"  # 默认安装路径
  export PATH="$ORACLE_HOME/bin:$PATH"
  
  # 验证sqlplus和rman是否可用
  if ! command -v sqlplus &> /dev/null; then
    echo "ERROR：未找到sqlplus，请检查ORACLE_HOME配置" >> "$LOG_FILE"
    exit 1
  fi
  if ! command -v rman &> /dev/null; then
    echo "ERROR：未找到rman，请检查ORACLE_HOME配置" >> "$LOG_FILE"
    exit 1
  fi
  
  echo "环境变量：ORACLE_SID=$ORACLE_SID，ORACLE_HOME=$ORACLE_HOME" >> "$LOG_FILE"
}


# 函数2：生成数据库连接字符串（根据用户密码是否为空返回不同连接方式）
get_connect_string() {
  if [ -z "$DB_USER" ] && [ -z "$DB_PASS" ]; then
    # 本地登录（操作系统认证）
    echo "/ as sysdba"
    echo "使用本地操作系统认证登录" >> "$LOG_FILE"
  else
    # 密码登录（支持本地/远程）
    echo "$DB_USER/$DB_PASS@//$DB_HOST:$DB_PORT/$ORACLE_SID as sysdba"
    echo "使用密码认证登录：用户=$DB_USER，主机=$DB_HOST:$DB_PORT" >> "$LOG_FILE"
  fi
}


# 函数3：查询每个THREAD中RN=3对应的序列号（返回格式：THREAD#|SEQUENCE#）
query_rn3_sequence() {
  echo -e "\n===== 执行SQL查询RN=3序列号：$(date +'%Y-%m-%d %H:%M:%S') =====" >> "$LOG_FILE"
  
  # 获取连接字符串
  local connect_str=$(get_connect_string)
  
  # SQL语句（修正原SQL的"whre"为"where"）
  local sql_query="
  SET HEADING OFF
  SET FEEDBACK OFF
  SET PAGESIZE 0
  SELECT THREAD# || '|' || SEQUENCE# 
  FROM (
    SELECT 
      SEQUENCE#,
      THREAD#,
      ROW_NUMBER() OVER (PARTITION BY THREAD# ORDER BY FIRST_TIME DESC) AS RN
    FROM v\$archived_log 
    WHERE APPLIED = 'YES'
  ) 
  WHERE RN = 3
  ORDER BY THREAD#;
  "
  
  echo "执行SQL：$sql_query" >> "$LOG_FILE"
  
  # 执行SQL查询
  local result=$(
    sqlplus -S "$connect_str" <<EOF 2>> "$LOG_FILE"
$sql_query
EXIT;
EOF
  )
  
  # 清理结果（去除空行和空格）
  result=$(echo "$result" | sed '/^$/d' | tr -d ' ')
  
  if [ -z "$result" ]; then
    echo "查询结果为空：所有THREAD的归档日志可能均不足3条" >> "$LOG_FILE"
  else
    echo "查询结果（THREAD#|SEQUENCE#）：$result" >> "$LOG_FILE"
  fi
  
  echo "$result"  # 返回查询结果
}


# 函数4：通过RMAN删除指定THREAD的归档日志（参数：THREAD，目标SEQUENCE）
delete_archivelog() {
  local thread=$1
  local seq=$2
  
  echo -e "\n===== 处理THREAD $thread：$(date +'%Y-%m-%d %H:%M:%S') =====" >> "$LOG_FILE"
  
  # 验证参数
  if [ -z "$thread" ] || [ -z "$seq" ]; then
    echo "ERROR：THREAD或SEQUENCE参数为空，跳过" >> "$LOG_FILE"
    return 1
  fi
  
  # 获取RMAN连接字符串
  local rman_connect
  if [ -z "$DB_USER" ] && [ -z "$DB_PASS" ]; then
    rman_connect="target /"  # 本地登录
  else
    rman_connect="target $DB_USER/$DB_PASS@//$DB_HOST:$DB_PORT/$ORACLE_SID as sysdba"  # 密码登录
  fi
  
  # RMAN删除命令
  local rman_cmd="
  connect $rman_connect;
  run {
    delete noprompt archivelog until sequence $seq thread $thread;
  }
  exit;
  "
  
  echo "执行RMAN命令：$rman_cmd" >> "$LOG_FILE"
  
  # 执行RMAN操作
  rman cmdfile /dev/stdin <<< "$rman_cmd" 2>> "$LOG_FILE"
  
  # 检查执行结果
  if [ $? -eq 0 ]; then
    echo "THREAD $thread 成功：删除序列号<$seq的归档日志" >> "$LOG_FILE"
  else
    echo "ERROR：THREAD $thread 失败，请查看RMAN输出" >> "$LOG_FILE"
  fi
}


# 主函数：串联流程
main() {
  # 初始化环境
  init_env
  
  # 查询RN=3的序列号
  local query_result=$(query_rn3_sequence)
  
  # 若查询结果为空，退出
  if [ -z "$query_result" ]; then
    echo -e "\n===== 执行结束（无操作）：$(date +'%Y-%m-%d %H:%M:%S') =====" >> "$LOG_FILE"
    exit 0
  fi
  
  # 循环处理每个THREAD
  echo -e "\n===== 开始删除操作：$(date +'%Y-%m-%d %H:%M:%S') =====" >> "$LOG_FILE"
  echo "$query_result" | while IFS="|" read -r thread seq; do
    delete_archivelog "$thread" "$seq"
  done
  
  echo -e "\n===== 所有操作完成：$(date +'%Y-%m-%d %H:%M:%S') =====" >> "$LOG_FILE"
}


# 启动主函数
main