#!/bin/bash
# by ray
# 2016-09-19
#v0.1

sqlplus -s /nolog <<-RAY
conn / as sysdba
set linesize 300
set pagesize 10000
col TABLESPACE_NAME for a30;
col PCT_FREE for a20;
col PCT_USED for a20;
col USED_MAX% for a20
select  a.tablespace_name,
       round(a.bytes_alloc / 1024 / 1024, 2) megs_alloc,
       round(nvl(b.bytes_free, 0) / 1024 / 1024, 2) megs_free,
       round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024, 2) megs_used,
       round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2)||'%' Pct_Free,
       100 - round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100,2)||'%' Pct_used,
       round(maxbytes/1048576,2) Max,
       round(round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024, 2) / round((case maxbytes when 0 then a.bytes_alloc else maxbytes end)/1048576,2) * 100,2) || '%' "USED_MAX%"
from  ( select  f.tablespace_name,
               sum(f.bytes) bytes_alloc,
               sum(decode(f.autoextensible, 'YES',f.maxbytes,'NO', f.bytes)) maxbytes
        from dba_data_files f
        group by tablespace_name) a,
      ( select  f.tablespace_name,
               sum(f.bytes)  bytes_free
        from dba_free_space f
        group by tablespace_name) b
where a.tablespace_name = b.tablespace_name (+)
union all
select h.tablespace_name,
       round(sum(h.bytes_free + h.bytes_used) / 1048576, 2) megs_alloc,
       round(sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / 1048576, 2) megs_free,
       round(sum(nvl(p.bytes_used, 0))/ 1048576, 2) megs_used,
       round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2)||'%' Pct_Free,
       100 - round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100,2)||'%' pct_used,
       round(sum(f.maxbytes) / 1048576, 2) max,
       round(round(sum(nvl(p.bytes_used, 0))/ 1048576, 2)/round(sum(case f.maxbytes when 0 then (h.bytes_free + h.bytes_used) else f.maxbytes end) / 1048576, 2) * 100,2)||'%' "USED_MAX%"
from   sys.v_\$TEMP_SPACE_HEADER h, sys.v_\$Temp_extent_pool p, dba_temp_files f
where  p.file_id(+) = h.file_id
and    p.tablespace_name(+) = h.tablespace_name
and    f.file_id = h.file_id
and    f.tablespace_name = h.tablespace_name
group by h.tablespace_name
ORDER BY 1;
RAY
