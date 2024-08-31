set linesize 300
column name format a30
column machine format a20
SELECT NAME, VALUE/1024/1024 VALUE_MB
FROM   V$PGASTAT
WHERE NAME IN ( 'aggregate PGA target parameter',
'total PGA allocated',
'total PGA inuse')
union all
SELECT NAME, VALUE
FROM   V$PGASTAT
WHERE NAME IN ('over allocation count');

SELECT name profile, cnt, decode(total, 0, 0, round(cnt*100/total)) percentage
FROM (SELECT name, value cnt, (sum(value) over ()) total
FROM V$SYSSTAT WHERE name like 'workarea exec%');

col client_info for a20
SELECT *
  FROM (  SELECT p.spid,
                 s.sid,
                 s.serial#,
                                 s.machine,
                                 s.client_info,
                 DECODE (s.program, NULL, p.program, s.program) AS "Program",
                 p.pga_used_mem,
                 p.pga_alloc_mem,
                 p.pga_max_mem
            FROM v$process p, v$session s
           WHERE s.paddr = p.addr
        ORDER BY p.pga_used_mem DESC)
WHERE ROWNUM <= &1;