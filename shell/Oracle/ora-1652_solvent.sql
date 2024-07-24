set termout       off;
set echo          off;
set feedback      off;
set verify        off;
set heading off;
set wrap          on;
set trimspool     on;
set serveroutput  on;
set escape        on;
set pagesize 50000;
set long     2000000000;
set linesize 300;
spool /tmp/kill_session_temptablespace.sql;
SELECT 'alter system kill session '||chr(39)||S.sid || ',' || S.serial#||chr(39)||';' sid_serial
FROM v$sort_usage T, v$session S, v$sqlarea Q, dba_tablespaces TBS
WHERE T.session_addr = S.saddr
   AND T.sqladdr = Q.address(+)
   AND T.tablespace = TBS.tablespace_name and T.blocks * TBS.block_size / 1024 / 1024 >=300
ORDER BY S.sid;
spool off
