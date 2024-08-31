set linesize 150;
select 'dynamic SGA components size and free part' from dual;
select name, bytes/1024/1024, resizeable from v$sgainfo;

select '#################' from dual;
select 'dynamic SGA components size' from dual;
select component, current_size/1024/1024 from v$sga_dynamic_components;

select 'SGA当前可以用于调整各个组件的剩余大小' from dual;
select * from v$sga_dynamic_free_memory;

select '#################' from dual;
select '记录已完成的近期850次SGA组件重定义大小的操作' from dual;
SELECT start_time,
      component,
      oper_type,
      oper_mode,
      initial_size / 1024 / 1024 "INITIAL",
      final_size / 1024 / 1024  "FINAL",
      end_time
FROM  v$sga_resize_ops
WHERE component IN ( 'DEFAULT buffer cache', 'shared pool' )
       AND status = 'COMPLETE'
ORDER  BY start_time,
         component;
         
select '当前正在操作中的SGA组件重定义操作' from dual;
select * from v$sga_current_resize_ops;

select '#################' from dual;
select '其它如share pool等组件剩余空间大小' from dual;
SELECT pool,name,bytes/1024/1024 FROM v$sgastat WHERE name LIKE '%free memory%';