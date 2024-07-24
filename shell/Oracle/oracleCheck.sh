#!/bin/sh
###############################################################################################################
#Script name: oracleCheck.sh
#Script description: Collect Oracle Information.
#Current Release Version: 1.0.0
#Script Owner: He ,Haibo
#Latest editor: He, Haibo
#Support platform:  Linux OS for redhat and centos 6/7.
#Change log:
#Descript:date 2021/12/8
#
#
###############################################################################################################
export LANG=en_US
osbox=`uname`
RELS=$(cat /etc/system-release)
RHversion=$(cat /proc/version | sed 's/[^0-9]//g' | cut -b -3)
OS_VER_PRI=$(echo "${RELS#*release}" | awk '{print $1}' | cut -f 1 -d '.')
gridFlag=0

###打印日志函数
log_info(){
    DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
    USER_N=`whoami`
    echo "${DATE_N} ${USER_N} execute $0 [INFO] $@"  
}

log_error(){
    DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
    USER_N=`whoami`
    echo -e "/033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ /033[0m" 
}

fn_log(){
    if [[ $? -eq 0 ]];then
        log_info "$@ sucessed."
        echo -e "/033[32m $@ sucessed. /033[0m"
    else
        log_error "$@ failed."
        echo -e "/033[41;37m $@ failed. /033[0m"
    fi
}

###Create /tmp/log if not exist.
mkdirLogPath(){
    if [[ ! -d /tmp/log ]];then
        mkdir -p /tmp/log
        chmod 767 /tmp/log
    fi
    LinuxLogPath="/tmp/log"
    getLinuxForOracleFile=${LinuxLogPath}/`hostname`_collectLinuxForOracle_`date "+%Y-%m-%d"`.out
}


checkOracleOrNot(){
    ps -ef | grep ora_ | grep -v grep > /dev/null
    if [[ $? == 0 ]];then
        continue
    else
        echo "Does not have oracle instance open"
        exit 99
    fi
}


checkOracleStartOrNot(){
    echo "select status from v/$instance;" | su - oracle -c "sqlplus / as sysdba" | grep "OPEN" > /dev/null
    if [[ $? == 0 ]];then
        continue
    else
        echo "DataBase is not open,shell will exit."
        exit 99
    fi
}


c1() {
  RED_COLOR='/E[1;31m'
  GREEN_COLOR='/E[1;32m'
  YELLOW_COLOR='/E[1;33m'
  BLUE_COLOR='/E[1;34m'
  PINK_COLOR='/E[1;35m'
  WHITE_BLUE='/E[47;34m'
  DOWN_BLUE='/E[4;36m'
  FLASH_RED='/E[5;31m'
  RES='/E[0m'

  #Here it is judged whether the incoming parameters are not equal to 2, if not equal to 2, prompt and exit
  if [ $# -ne 2 ]; then
    echo "Usage $0 content {red|yellow|blue|green|pink|wb|db|fr}"
    exit
  fi

  case "$2" in
  red | RED)
    echo -e "${RED_COLOR}$1${RES}"
    ;;
  yellow | YELLOW)
    echo -e "${YELLOW_COLOR}$1${RES}"
    ;;
  green | GREEN)
    echo -e "${GREEN_COLOR}$1${RES}"
    ;;
  blue | BLUE)
    echo -e "${BLUE_COLOR}$1${RES}"
    ;;
  pink | PINK)
    echo -e "${PINK_COLOR}$1${RES}"
    ;;
  wb | WB)
    echo -e "${WHITE_BLUE}$1${RES}"
    ;;
  db | DB)
    echo -e "${DOWN_BLUE}$1${RES}"
    ;;
  fr | FR)
    echo -e "${FLASH_RED}$1${RES}"
    ;;
  *)
    echo -e "Please enter the specified color code：{red|yellow|blue|green|pink|wb|db|fr}"
    ;;
  esac
}



logwrite() {
  {
    c1 "####################################################################################" green
    echo
    c1 "# $1" blue
    echo
    c1 "####################################################################################" green
    echo
    echo "$1 :"
    echo
    echo "$2" >"${SOFTWAREDIR}"/ex.sh
    chmod +x "${SOFTWAREDIR}"/ex.sh
    "${SOFTWAREDIR}"/ex.sh
    rm -rf "${SOFTWAREDIR}"/ex.sh
    echo
  } >>"${getLinuxForOracleFile}"
}

checkExecuteUser(){
    uid=`id -u`
    if [[ $uid == 0 ]];then
        continue
    else
        fn_log "Current excute user is not root ,shell will exist."
        exit 1
    fi
}



###Get OS Arch Linux or not
getOsArch(){
    if [[ "$osbox" == "Linux" ]];then
        continue
    else
        fn_log "Current OS is $osbox,shell is exit now."
        echo 0
        exit 0
    fi
}


###Get redhat or centos
getOsCentosOrRedhat(){
    cat /proc/version | grep -iE "redhat|centos" > /dev/null
    if [[ $? == 0 ]];then
        continue
    else
        echo "Current OS is not centos or redhat."
        echo 1
        exit 1
    fi
}

getLinuxVersion(){
    if [[ -f /etc/system-release ]];then
        cat /etc/system-release > /dev/null
    else
        echo "/etc/system-release does not exist."
    fi

    if [[ "$OS_VER_PRI" -eq 7 ]];then
        OS_VERSION=linux7
    elif [[ "$OS_VER_PRI" -eq 6 ]];then
        OS_VERSION=linux6
    elif [[ "$OS_VER_PRI" -eq 8 ]];then
        OS_VERSION=linux8
        fn_log "Current OS does not support."
        exit 99
    else
        fn_log "Current OS does not support."
        exit 99
    fi
}

checkOracleVersion(){
    OraVersion=`su - oracle -c "sqlplus -V | grep -i 'Version'" | awk -F ' ' {'print $2'} | awk -F '.' {'print $1'}`
    if [[ ${OraVersion} == 19 ]];then
        continue
    else
        echo "Current Oracle Version does not support."
        exit 99
    fi
}


getAsmcmdDg(){
    id grid > /dev/null 2>&1
    if [[ $? == 0 ]];then
        echo "No.2 Get asmcmd lsdg command." >> ${getLinuxForOracleFile}
        su - grid -c "asmcmd lsdg" >> ${getLinuxForOracleFile}
    else
        echo "Does not have grid user in current System." >> ${getLinuxForOracleFile}
    fi

} 


getOracleCommonInfo(){
    echo "No.1 ##########Get OS Common Information.##########" > ${getLinuxForOracleFile}
    echo "hostname:`hostname`" >> ${getLinuxForOracleFile}
    echo "OS Version:`cat /etc/redhat-release`" >> ${getLinuxForOracleFile}
    echo "CPU:`cat /proc/cpuinfo| grep "processor"| wc -l`" >> ${getLinuxForOracleFile}
    free -m >> ${getLinuxForOracleFile}
    df -Th >> ${getLinuxForOracleFile}
}

checkCommanInfo(){
    echo "No.2 ##########ntpq -p ##########" >> ${getLinuxForOracleFile}
    which ntpq > /dev/null 2>&1
    if [[ $? == 0 ]];then
        ntpq -p >> ${getLinuxForOracleFile}
    else
        echo "Current OS does not have ntpq command. check failed." >> ${getLinuxForOracleFile}
    fi

    echo "No.3 ##########chronyc sources -v##########" >> ${getLinuxForOracleFile}
    chronyd=`systemctl list-unit-files | grep chronyd | awk -F ' ' {'print $2'}`
        if [[ ${chronyd} == "disabled" ]];then
            echo "chronyd is disabled,check success."  >> ${getLinuxForOracleFile}
        elif [[ ${chronyd} == "enabled" ]];then
            which chronyc > /dev/null 2>&1
            if [[ $? == 0 ]];then
                chronyc sources -v >> ${getLinuxForOracleFile}
            else
                echo "Command chronyc does not exists." >> ${getLinuxForOracleFile}
            fi
        else
            echo "chronyd does not exist,check success." >> ${getLinuxForOracleFile}
        fi
}

checkOracleBaseInfo(){
    echo "#############################No.3 Get show sga and show parameter##################### " >> ${getLinuxForOracleFile}
    cat <<EOF > /home/oracle/oracleCheck.sql
set heading off
select '1.Oracle Show sga' from dual;
set heading on
show sga;

set heading off
select '2.Oracle Show parameter' from dual;
set heading on
show parameter;

EOF
}

checkGridStatus(){
    id grid > /dev/null 2&>1
    if [[ $? == 0 ]];then
        echo "No.4 ##########crsctl check cluster#############" >> ${getLinuxForOracleFile}
        su - grid -c "crsctl check cluster" >> ${getLinuxForOracleFile}

        echo "No.5 ##########crsctl status resource##########" >> ${getLinuxForOracleFile}
        su - grid -c "crsctl status resource" >> ${getLinuxForOracleFile}

        echo "No.6##########crsctl query css votedisk##########" >> ${getLinuxForOracleFile}
        su - grid -c "crsctl query css votedisk" >> ${getLinuxForOracleFile}

        echo "No.7########## opatch lsinventory###########" >> ${getLinuxForOracleFile}
        su - grid -c " opatch lsinventory" >> ${getLinuxForOracleFile}

        echo "No.8##########$ORACLE_HOME/OPatch/opatch lsinventory##########" >> ${getLinuxForOracleFile}
        su - grid -c "$ORACLE_HOME/OPatch/opatch lsinventory" >> ${getLinuxForOracleFile}

        echo "No.9########### srvctl status LISTENER######################## " >> ${getLinuxForOracleFile}
        su - grid -c "srvctl status LISTENER" >> ${getLinuxForOracleFile}
    else
        echo "Does not have grid user in current System." >> ${getLinuxForOracleFile}
    fi
}


checkDatabaseInfo(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '3.Oracle Common Information' from dual;
set heading on
set linesize 200 
column "DB Name" format a15
column "Open Mode" format a10
column "Global Name" format a50
column "Host Name"  format a20
column "Instance Name"  format a20
column "Restricted Mode" format a10
column "Archive Log Mode" format a10
SELECT a.NAME "DB Name",a.OPEN_MODE "Open Mode", e.GLOBAL_NAME "Global Name", c.host_name "Host Name",
       c.instance_name "Instance Name",
       DECODE (c.logins, 'RESTRICTED', 'YES', 'NO') "Restricted Mode",
       a.log_mode "Archive Log Mode"
  FROM v/$database a, v/$version b, v/$instance c, GLOBAL_NAME e
WHERE b.banner LIKE '%Oracle%';

EOF
}


checkDatabaseCharset(){
    cat <<EOF >>/home/oracle/oracleCheck.sql
set heading off
select '4.Oracle Charset' from dual;
set heading on
set linesize 100
column PARAMETER format a30
column value format a30
select * from nls_database_parameters;
select userenv('language') from dual;    

EOF
}


checkDatabaseVersion(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '5.Oracle Version' from dual;
set heading on
Set linesize 100
Select * from v/$version;    

EOF

    id grid > /dev/null 2&>1
    if [[ $? == 0 ]];then
        su - grid -c "crsctl query crs softwareversion" >> ${getLinuxForOracleFile}
    fi
}



checkDatabaseControlFile(){
    cat <<EOF >>/home/oracle/oracleCheck.sql
set heading off
select '6.Oracle Control File' from dual;
set heading on
set linesize 150
column NAME format a100
column status format a30
SELECT NAME, status FROM v/$controlfile;

EOF
}

checkRedoLog(){
    cat << EOF >>/home/oracle/oracleCheck.sql
set heading off
select '7.Oracle Redo Log' from dual;
set heading on
set linesize 150
column group# format 9999999
column "Redo File" format a80
column TYPE format a10
column status format a10
column "Size(MB)" format 9999999999
SELECT f.group#, f.MEMBER "Redo File", f.TYPE, l.status,
       l.BYTES / 1024 / 1024 "Size(MB)"
  FROM v/$log l, v/$logfile f
 WHERE l.group# = f.group#;

EOF
}

check24HoursReDoLog(){
    cat << EOF >>/home/oracle/oracleCheck.sql
set heading off
select '8.Oracle 24 hours Redo Log' from dual;
set heading on
set pages 999 lines 400
col h0 format 999
col h1 format 999
col h2 format 999
col h3 format 999
col h4 format 999
col h5 format 999
col h6 format 999
col h7 format 999
col h8 format 999
col h9 format 999
col h10 format 999
col h11 format 999
col h12 format 999
col h13 format 999
col h14 format 999
col h15 format 999
col h16 format 999
col h17 format 999
col h18 format 999
col h19 format 999
col h20 format 999
col h21 format 999
col h22 format 999
col h23 format 999
SELECT TRUNC (first_time) "Date", inst_id, TO_CHAR (first_time, 'Dy') "Day",
 COUNT (1) "Total",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '00', 1, 0)) "h0",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '01', 1, 0)) "h1",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '02', 1, 0)) "h2",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '03', 1, 0)) "h3",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '04', 1, 0)) "h4",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '05', 1, 0)) "h5",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '06', 1, 0)) "h6",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '07', 1, 0)) "h7",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '08', 1, 0)) "h8",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '09', 1, 0)) "h9",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '10', 1, 0)) "h10",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '11', 1, 0)) "h11",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '12', 1, 0)) "h12",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '13', 1, 0)) "h13",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '14', 1, 0)) "h14",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '15', 1, 0)) "h15",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '16', 1, 0)) "h16",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '17', 1, 0)) "h17",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '18', 1, 0)) "h18",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '19', 1, 0)) "h19",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '20', 1, 0)) "h20",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '21', 1, 0)) "h21",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '22', 1, 0)) "h22",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '23', 1, 0)) "h23",
 ROUND (COUNT (1) / 24, 2) "Avg"
FROM gv/$log_history
WHERE thread# = inst_id
AND first_time > sysdate -7
GROUP BY TRUNC (first_time), inst_id, TO_CHAR (first_time, 'Dy')
ORDER BY 1,2;

EOF
}



checkDataFileStatus(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '9.Oracle Data Files' from dual;
set heading on
set linesize 150
column  tablespace_name format a20
column file_name format a80
column "Total Size(MB)" format 999999999999
column  "Auto" format a10
SELECT   tablespace_name, file_name, BYTES / 1024 / 1024 "Total Size(MB)",
         autoextensible "Auto"
    FROM dba_data_files
ORDER BY tablespace_name, file_id;
set linesize 150
column file# format 9999999
column name format a100
column status format a10
select file#,name , status from v/$datafile;

EOF
}



checkCDBOrNot(){
    CBDOrNOT=$(echo "select cdb from v/$database;" | su - oracle -c "sqlplus / as sysdba" | egrep "YES|NO" | sed 's/[ /t]//g')
}



checkTableSpaceStatus(){
    if [[ ${CBDOrNOT} == "YES" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '10.Oracle TableSpaces' from dual;
set heading on
REM
REM Script: ts_used.sql
REM
REM Function: Display tablespace usage with graph
REM
REM
clear columns
column tablespace format a20
column total_mb format 999,999,999,999.99
column used_mb format 999,999,999,999.99
column free_mb format 999,999,999.99
column pct_used format 999.99
column graph format a25 heading "GRAPH (X=5%)"
column status format a10
compute sum of total_mb on report
compute sum of used_mb on report
compute sum of free_mb on report
break on report 
set lines 200 pages 100
select  total.ts tablespace,
        DECODE(total.mb,null,'OFFLINE',dbat.status) status,
    total.mb total_mb,
    NVL(total.mb - free.mb,total.mb) used_mb,
    NVL(free.mb,0) free_mb,
        DECODE(total.mb,NULL,0,NVL(ROUND((total.mb - free.mb)/(total.mb)*100,2),100)) pct_used,
    CASE WHEN (total.mb IS NULL) THEN '['||RPAD(LPAD('OFFLINE',13,'-'),20,'-')||']'
    ELSE '['|| DECODE(free.mb,
                             null,'XXXXXXXXXXXXXXXXXXXX',
                             NVL(RPAD(LPAD('X',trunc((100-ROUND( (free.mb)/(total.mb) * 100, 2))/5),'X'),20,'-'),
        '--------------------'))||']' 
         END as GRAPH
from
    (select tablespace_name ts, sum(bytes)/1024/1024 mb from dba_data_files group by tablespace_name) total,
    (select tablespace_name ts, sum(bytes)/1024/1024 mb from dba_free_space group by tablespace_name) free,
        dba_tablespaces dbat
where total.ts=free.ts(+) and
      total.ts=dbat.tablespace_name
UNION ALL
select  sh.tablespace_name, 
        'TEMP',
    SUM(sh.bytes_used+sh.bytes_free)/1024/1024 total_mb,
    SUM(sh.bytes_used)/1024/1024 used_mb,
    SUM(sh.bytes_free)/1024/1024 free_mb,
        ROUND(SUM(sh.bytes_used)/SUM(sh.bytes_used+sh.bytes_free)*100,2) pct_used,
        '['||DECODE(SUM(sh.bytes_free),0,'XXXXXXXXXXXXXXXXXXXX',
              NVL(RPAD(LPAD('X',(TRUNC(ROUND((SUM(sh.bytes_used)/SUM(sh.bytes_used+sh.bytes_free))*100,2)/5)),'X'),20,'-'),
                '--------------------'))||']'
FROM v/$temp_space_header sh
GROUP BY tablespace_name
order by 1
/
ttitle off
 clear columns

EOF

    elif [[ ${CBDOrNOT} == "NO" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '10.Oracle TableSpaces' from dual;
set heading on
REM
REM Script: ts_used.sql
REM
REM Function: Display tablespace usage with graph
REM
REM
clear columns
column CON_NAME format a15
column con_id format 999
column tablespace format a15
column total_mb format 999,999,999,999.99
column used_mb format 999,999,999,999.99
column free_mb format 999,999,999.99
column pct_used format 999.99
column graph format a25 heading "GRAPH (X=5%)"
column status format a10
compute sum of total_mb on CON_NAME
compute sum of used_mb on CON_NAME
compute sum of free_mb on CON_NAME
break on CON_NAME skip 2
set lines 200 pages 100
WITH CONNAME AS(select sys_context('USERENV','CON_NAME') CON_NAME,
to_number(sys_context('USERENV','CON_ID')) CON_ID
from DUAL
UNION ALL
select NAME AS CON_NAME,CON_ID from v/$pdbs),
TBS_USAGE AS(
select total.con_id,
        total.ts tablespace,
        DECODE(total.mb,null,'OFFLINE',dbat.status) status,
         total.mb total_mb,
    NVL(total.mb - free.mb,total.mb) used_mb,
    NVL(free.mb,0) free_mb,
        DECODE(total.mb,NULL,0,NVL(ROUND((total.mb - free.mb)/(total.mb)*100,2),100)) pct_used,
    CASE WHEN (total.mb IS NULL) THEN '['||RPAD(LPAD('OFFLINE',13,'-'),20,'-')||']'
    ELSE '['|| DECODE(free.mb,
                             null,'XXXXXXXXXXXXXXXXXXXX',
                             NVL(RPAD(LPAD('X',trunc((100-ROUND( (free.mb)/(total.mb) * 100, 2))/5),'X'),20,'-'),
        '--------------------'))||']' 
         END as GRAPH
from
    (select con_id,tablespace_name ts, sum(bytes)/1024/1024 mb from cdb_data_files group by con_id,tablespace_name) total,
    (select con_id,tablespace_name ts, sum(bytes)/1024/1024 mb from cdb_free_space group by con_id,tablespace_name) free,
        cdb_tablespaces dbat
where total.ts=free.ts(+) and
total.con_id=free.con_id(+) and
      total.con_id=dbat.con_id and
      total.ts=dbat.tablespace_name
UNION ALL
select  sh.con_id,
        sh.TABLESPACE_NAME tablespace, 
        'TEMP',
    SUM(sh.TABLESPACE_SIZE)/1024/1024 total_mb,
    SUM(sh.TABLESPACE_SIZE-sh.FREE_SPACE)/1024/1024 used_mb,
    SUM(sh.FREE_SPACE)/1024/1024 free_mb,
        ROUND(SUM(sh.TABLESPACE_SIZE-sh.FREE_SPACE)/SUM(sh.TABLESPACE_SIZE)*100,2) pct_used,
        '['||DECODE(SUM(sh.FREE_SPACE),0,'XXXXXXXXXXXXXXXXXXXX',
              NVL(RPAD(LPAD('X',(TRUNC(ROUND((SUM(sh.TABLESPACE_SIZE-sh.FREE_SPACE)/SUM(sh.TABLESPACE_SIZE))*100,2)/5)),'X'),20,'-'),
                '--------------------'))||']'
FROM CDB_TEMP_FREE_SPACE sh
GROUP BY con_id,tablespace_name
order by con_id)
select CONNAME.CON_NAME,TBS_USAGE.*
from CONNAME,TBS_USAGE
where CONNAME.CON_ID=TBS_USAGE.CON_ID
/
ttitle off
 clear columns

EOF

    else
        echo "Can't Get CBD Or Not." >> ${getLinuxForOracleFile}
    fi

}

getEtcSysctlConf(){
    echo "##########No.8 get /etc/sysctl.conf status##########"  >> ${getLinuxForOracleFile}
    if [[ -f /etc/sysctl.conf ]];then
        cat /etc/sysctl.conf | grep -v "^[[:space:]]*#" | grep -v "^[[:space:]]*$" >> ${getLinuxForOracleFile}
    else
        echo "Does not have /etc/sysctl.conf file."  >> ${getLinuxForOracleFile}
    fi
}





checkListenStatus(){
    id grid > /dev/null 2&>1
    if [[ $? == 0 ]];then
        su - grid -c "srvctl status LISTENER" >> ${getLinuxForOracleFile}
    else
        su - oracle -c "lsnrctl status" >> ${getLinuxForOracleFile}
    fi

}





checkTableSpaceObject(){
    if [[ ${CBDOrNOT} == "YES" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '11.Oracle TableSpaces Objects' from dual;
set heading on
set lines 200 pages 100
column con_id format 999
column con_name  format a20
column owner format a30
column segment_name format a80
column segment_type format a30
select t.con_id,nvl(x.name,'CDB$ROOT') as con_name,t.owner, t.segment_name, t.segment_type
from cdb_segments t,v/$pdbs x
where t.con_id=x.con_id 
and t.tablespace_name = 'SYSTEM'
and t.owner not in ('SYS','SYSTEM','OUTLN','OJVMSYS');

EOF

    elif [[ ${CBDOrNOT} == "NO" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '11.Oracle TableSpaces Objects' from dual;
set heading on
set linesize 150
column owner format a30
column segment_name format a80
column segment_type format a30
select owner, segment_name, segment_type
from dba_segments
where tablespace_name = 'SYSTEM'
and owner not in ('SYS','SYSTEM','OUTLN','OJVMSYS');

EOF

    else
        echo "Can't Get CBD Or Not." >> ${getLinuxForOracleFile}
    fi
}






checkTempTableSpaceUser(){
    if [[ ${CBDOrNOT} == "YES" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '12.Oracle Temp TableSpaces' from dual;
set heading on
set linesize 100
column con_id format 999
column con_name format a20
column tablespace_name format a30
column CONTENTS format a50
SELECT t.con_id,nvl(x.name, 'CDB$ROOT') as con_name,t.tablespace_name, t.CONTENTS
  FROM cdb_tablespaces t,v/$pdbs x
 WHERE t.con_id=x.con_id and 
      t.CONTENTS = 'TEMPORARY'
   AND t.tablespace_name NOT IN (SELECT tablespace_name
                                 FROM cdb_temp_files);

EOF

    elif [[ ${CBDOrNOT} == "NO" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '12.Oracle Temp TableSpaces' from dual;
set heading on
set linesize 100
column username format a30
SELECT username
  FROM dba_users
 WHERE temporary_tablespace = 'SYSTEM';

set linesize 100
column tablespace_name format a30
column CONTENTS format a50
SELECT tablespace_name, CONTENTS
  FROM dba_tablespaces
 WHERE CONTENTS = 'TEMPORARY'
   AND tablespace_name NOT IN (SELECT tablespace_name
                                 FROM dba_temp_files);

EOF

    else
        echo "Can't Get CBD Or Not." >> ${getLinuxForOracleFile}
    fi
}

checkRmanStatus(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '13.Oracle RMAN STATUS' from dual;
set heading on
set linesize 100
column START_TIME format a15
column END_TIME format a15
column OUTPUT_DEVICE_TYPE format a10
column STATUS format a15
column ELAPSED_SECONDS format 99999999
column COMPRESSION_RATIO format 999999
column INPUT_BYTES_DISPLAY format a15
column OUTPUT_BYTES_DISPLAY format a15
SELECT
START_TIME,END_TIME,OUTPUT_DEVICE_TYPE,STATUS,ELAPSED_SECONDS,COMPRESSION_RATIO,INPUT_BYTES_DISPLAY,OUTPUT_BYTES_DISPLAY
FROM V/$RMAN_BACKUP_JOB_DETAILS where START_TIME>=trunc(sysdate)-1 ORDER BY START_TIME DESC;

EOF
}


checkInitialParameter(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '14.Oracle Initial PARAMETER' from dual;
set heading on
set linesize 100
Show parameter sga
Show parameter pga
Show parameter session_cached_cursor
Show parameter undo_retention
Show parameter processes

EOF
}

checkModuleStatus(){
    if [[ ${CBDOrNOT} == "YES" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '15.Oracle module status' from dual;
set heading on
clear columns
column con_id format 999
column comp_id format a10
column comp_name format a30
column version format a30
column status format  a12
set lines 200 pages 100
select con_id,comp_id,comp_name,version,status from cdb_registry;
clear columns

EOF

    elif [[ ${CBDOrNOT} == "NO" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '15.Oracle module status' from dual;
set heading on
clear columns
column comp_id format a10
column comp_name format a30
column version format a30
column status format  a12
set lines 200 pages 100
select comp_id,comp_name,version,status from dba_registry;
clear columns

EOF

    else
        echo "Can't Get CBD Or Not." >> ${getLinuxForOracleFile}
    fi
}


checkfailureObject(){
    if [[ ${CBDOrNOT} == "YES" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '16.Oracle failure object' from dual;
set heading on
clear columns
set linesize 200
set tab off
column CON_ID format 999
column owner format a20
column OBJECT_TYPE format a23
column status format  a19
select CON_ID,OWNER,OBJECT_NAME ,OBJECT_TYPE,STATUS from cdb_objects where status='INVALID';
clear columns

EOF

    elif [[ ${CBDOrNOT} == "NO" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '16.Oracle failure object' from dual;
set heading on
clear columns
column owner format a10
column OBJECT_NAME format a50
column OBJECT_TYPE format a23
column status format  a19
set lines 200 pages 100
select owner,OBJECT_NAME , OBJECT_TYPE,status from dba_invalid_objects;
clear columns

EOF

    else
        echo "Can't Get CBD Or Not." >> ${getLinuxForOracleFile}
    fi
}



checkFlashStatus(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '17.Oracle Flash Status' from dual;
set heading on
Show parameter recyclebin
Show parameter db_recovery
select  FLASHBACK_ON from v/$database;

EOF
}


checkStatisticsStatus(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '18.Oracle Statistics Status' from dual;
set heading on    
set linesize 200
select max(end_time) LATEST, operation from DBA_OPTSTAT_OPERATIONS
where operation in ('gather_dictionary_stats', 'gather_fixed_objects_stats')
group by operation;
SELECT 'TABLE' object_type,owner, table_name object_name, last_analyzed, stattype_locked, stale_stats
FROM all_tab_statistics
WHERE (last_analyzed IS NULL OR stale_stats = 'YES') and stattype_locked IS NULL
and owner NOT IN ('ANONYMOUS', 'CTXSYS', 'DBSNMP', 'EXFSYS','LBACSYS','MDSYS','MGMT_VIEW','OLAPSYS','OWBSYS','ORDPLUGINS','ORDSYS','OUTLN','SI_INFORMTN_SCHEMA','SYS', 'SYSMAN','SYSTEM','TSMSYS','WK_TEST','WKSYS','WKPROXY','WMSYS','XDB' ,'ORDDATA','AUDSYS','GSMADMIN_INTERNAL','DVSYS')
AND owner NOT LIKE 'FLOW%'
UNION ALL
SELECT 'INDEX' object_type,owner, index_name object_name,  last_analyzed, stattype_locked, stale_stats
FROM all_ind_statistics
WHERE (last_analyzed IS NULL OR stale_stats = 'YES') and stattype_locked IS NULL
AND owner NOT IN ('ANONYMOUS', 'CTXSYS', 'DBSNMP', 'EXFSYS','LBACSYS','MDSYS','MGMT_VIEW','OLAPSYS','OWBSYS','ORDPLUGINS','ORDSYS','OUTLN','SI_INFORMTN_SCHEMA','SYS', 'SYSMAN','SYSTEM','TSMSYS','WK_TEST','WKSYS','WKPROXY','WMSYS','XDB','ORDDATA','AUDSYS','GSMADMIN_INTERNAL','DVSYS' )
AND owner NOT LIKE 'FLOW%'
ORDER BY object_type desc, owner, object_name
/

EOF

}



checkDBLinkStatus(){
    if [[ ${CBDOrNOT} == "YES" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '19.Oracle DBLINK Status' from dual;
set heading on    
set linesize 100
column con_id format 999
column owner format a20
column object_name  format a30
select con_id,owner,object_name from cdb_objects where object_type='DATABASE LINK';

EOF

    elif [[ ${CBDOrNOT} == "NO" ]];then
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '19.Oracle DBLINK Status' from dual;
set heading on    
set linesize 100
column owner format a20
column object_name  format a30
select owner,object_name from dba_objects where object_type='DATABASE LINK';

EOF
    else
        echo "Can't Get CBD Or Not." >> ${getLinuxForOracleFile}
    fi
}


checkSCNStatus(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '20.Oracle SCN Status' from dual;
set heading on    
Rem
Rem $Header: rdbms/admin/scnhealthcheck.sql apfwkr_blr_backport_13498243_12.1.0.2.0/1 2015/05/26 22:44:51 apfwkr Exp $
Rem
Rem scnhealthcheck.sql
Rem
Rem Copyright (c) 2012, 2015, Oracle and/or its affiliates. 
Rem All rights reserved.
Rem
Rem    NAME
Rem      scnhealthcheck.sql - Scn Health check
Rem
Rem    DESCRIPTION
Rem      Checks scn health of a DB
Rem
Rem    NOTES
Rem      .
Rem
Rem    MODIFIED   (MM/DD/YY)
Rem    tbhukya     01/11/12 - Created
Rem
Rem

define LOWTHRESHOLD=10
define MIDTHRESHOLD=62
define VERBOSE=FALSE

set veri off;
set feedback off;

set serverout on
DECLARE
 verbose boolean:=&&VERBOSE;
BEGIN
 For C in (
  select 
   version, 
   date_time,
   dbms_flashback.get_system_change_number current_scn,
   indicator
  from
  (
   select
   version,
   to_char(SYSDATE,'YYYY/MM/DD HH24:MI:SS') DATE_TIME,
   ((((
    ((to_number(to_char(sysdate,'YYYY'))-1988)*12*31*24*60*60) +
    ((to_number(to_char(sysdate,'MM'))-1)*31*24*60*60) +
    (((to_number(to_char(sysdate,'DD'))-1))*24*60*60) +
    (to_number(to_char(sysdate,'HH24'))*60*60) +
    (to_number(to_char(sysdate,'MI'))*60) +
    (to_number(to_char(sysdate,'SS')))
    ) * (16*1024)) - dbms_flashback.get_system_change_number)
   / (16*1024*60*60*24)
   ) indicator
   from v/$instance
  ) 
 ) LOOP
  dbms_output.put_line( '-----------------------------------------------------'
                        || '---------' );
  dbms_output.put_line( 'ScnHealthCheck' );
  dbms_output.put_line( '-----------------------------------------------------'
                        || '---------' );
  dbms_output.put_line( 'Current Date: '||C.date_time );
  dbms_output.put_line( 'Current SCN:  '||C.current_scn );
  if (verbose) then
    dbms_output.put_line( 'SCN Headroom: '||round(C.indicator,2) );
  end if;
  dbms_output.put_line( 'Version:      '||C.version );
  dbms_output.put_line( '-----------------------------------------------------'
                        || '---------' );

  IF C.version > '10.2.0.5.0' and 
     C.version NOT LIKE '9.2%' THEN
    IF C.indicator>&MIDTHRESHOLD THEN 
      dbms_output.put_line('Result: A - SCN Headroom is good');
      dbms_output.put_line('Apply the latest recommended patches');
      dbms_output.put_line('based on your maintenance schedule');
      IF (C.version < '11.2.0.2') THEN
        dbms_output.put_line('AND set _external_scn_rejection_threshold_hours='
                             || '24 after apply.');
      END IF;
    ELSIF C.indicator<=&LOWTHRESHOLD THEN
      dbms_output.put_line('Result: C - SCN Headroom is low');
      dbms_output.put_line('If you have not already done so apply' );
      dbms_output.put_line('the latest recommended patches right now' );
      IF (C.version < '11.2.0.2') THEN
        dbms_output.put_line('set _external_scn_rejection_threshold_hours=24 '
                             || 'after apply');
      END IF;
      dbms_output.put_line('AND contact Oracle support immediately.' );
    ELSE
      dbms_output.put_line('Result: B - SCN Headroom is low');
      dbms_output.put_line('If you have not already done so apply' );
      dbms_output.put_line('the latest recommended patches right now');
      IF (C.version < '11.2.0.2') THEN
        dbms_output.put_line('AND set _external_scn_rejection_threshold_hours='
                             ||'24 after apply.');
      END IF;
    END IF;
  ELSE
    IF C.indicator<=&MIDTHRESHOLD THEN
      dbms_output.put_line('Result: C - SCN Headroom is low');
      dbms_output.put_line('If you have not already done so apply' );
      dbms_output.put_line('the latest recommended patches right now' );
      IF (C.version >= '10.1.0.5.0' and 
          C.version <= '10.2.0.5.0' and 
          C.version NOT LIKE '9.2%') THEN
        dbms_output.put_line(', set _external_scn_rejection_threshold_hours=24'
                             || ' after apply');
      END IF;
      dbms_output.put_line('AND contact Oracle support immediately.' );
    ELSE
      dbms_output.put_line('Result: A - SCN Headroom is good');
      dbms_output.put_line('Apply the latest recommended patches');
      dbms_output.put_line('based on your maintenance schedule ');
      IF (C.version >= '10.1.0.5.0' and
          C.version <= '10.2.0.5.0' and
          C.version NOT LIKE '9.2%') THEN
       dbms_output.put_line('AND set _external_scn_rejection_threshold_hours=24'
                             || ' after apply.');
      END IF;
    END IF;
  END IF;
  dbms_output.put_line(
    'For further information review MOS document id 1393363.1');
  dbms_output.put_line( '-----------------------------------------------------'
                        || '---------' );
 END LOOP;
end;
/

EOF
}


checkSecurityStatus(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '21.Oracle Security Status' from dual;
set heading on
select username from dba_users where username not in
('SYS'
,'SYSTEM'
,'OUTLN'
,'LBACSYS'
,'FLOWS_FILES'
,'DBSFWUSER'
,'GGSYS'
,'DVSYS'
,'DVF'
,'GSMADMIN_INTERNAL'
,'GSMCATUSER'
,'GSMUSER'
,'GSMROOTUSER'
,'SYSRAC'
,'SYSBACKUP'
,'OJVMSYS'
,'AUDSYS'
,'SYSKM'
,'SYS$UMF'
,'REMOTE_SCHEDULER_AGENT'
,'MDSYS'
,'ORDSYS'
,'EXFSYS'
,'DBSNMP'
,'WMSYS'
,'APPQOSSYS'
,'APEX_030200'
,'ORDDATA'
,'CTXSYS'
,'ANONYMOUS'
,'XDB'
,'ORDPLUGINS'
,'SI_INFORMTN_SCHEMA'
,'OLAPSYS'
,'ORACLE_OCM'
,'XS$NULL'
,'MDDATA'
,'DIP'
,'APEX_PUBLIC_USER'
,'SPATIAL_CSW_ADMIN_USR'
,'SPATIAL_WFS_ADMIN_USR'
,'SYSDG');

EOF
}


checkGrantDBA(){
    cat <<EOF >> /home/oracle/oracleCheck.sql
set heading off
select '22.Oracle Grant DBA' from dual;
set heading on
set linesize 100
column GRANTEE  format a20
column GRANTED_ROLE  format a10
select * from dba_role_privs where granted_role='DBA';
quit
EOF
}

executeSQL(){
    su - oracle -c "sqlplus / as sysdba @/home/oracle/oracleCheck.sql" >> ${getLinuxForOracleFile}
}

main(){
    checkExecuteUser
    checkOracleOrNot
    checkOracleStartOrNot
    getOsArch
    getOsCentosOrRedhat
    getLinuxVersion
    checkOracleVersion
    mkdirLogPath    
    getOracleCommonInfo
    getAsmcmdDg
    checkCommanInfo
    getEtcSysctlConf
    checkOracleBaseInfo
    checkGridStatus
    checkDatabaseInfo
    checkDatabaseCharset
    checkDatabaseVersion
    checkListenStatus
    checkDatabaseControlFile
    checkRedoLog
    check24HoursReDoLog
    checkDataFileStatus
    checkCDBOrNot
    checkTableSpaceStatus
    checkTableSpaceObject
    checkTempTableSpaceUser
    checkRmanStatus
    checkInitialParameter
    checkModuleStatus
    checkfailureObject
    checkFlashStatus
    checkStatisticsStatus
    checkDBLinkStatus
    checkSCNStatus
    checkSecurityStatus
    checkGrantDBA
    executeSQL
}


main