CREATE OR REPLACE procedure dropPartitions
(
    t_name varchar2,        --指定删除分区的表
    beforedays number       --指定删除多久之前的天数
)
is
  l_date_to_drop DATE DEFAULT (sysdate-beforedays);--获取指定的时间，这里指删除多少时间之前的时间，to_date('2019-08-11','yyyy-mm-dd');
  l_date_partition        DATE;  --获取对应的high_value时间格式的值
  l_date_str    VARCHAR2(128);  --获取对应的high_value值
  l_drop_stmt    VARCHAR2(128);  --生成的对应sql
  CURSOR c_partitions
  IS
    SELECT table_name,partition_name,
      HIGH_VALUE
    FROM all_tab_partitions
    WHERE table_name = t_name and partition_position <> 1;--获取相关表的分区信息 ;
BEGIN
  FOR row_ IN c_partitions
  LOOP
    l_date_str    := SUBSTR(row_.HIGH_VALUE,1,128);
    l_date_partition       := to_date(SUBSTR(l_date_str,11,10),'yyyy-mm-dd');
    IF l_date_partition <= l_date_to_drop THEN
      l_drop_stmt := 'alter table '||row_.table_name||' drop partition '||row_.partition_name||' update global indexes';
      --dbms_output.put_line(SUBSTR(l_date_str,11,10));
      --dbms_output.put_line(l_drop_stmt||',    '||l_date_str);
      execute immediate l_drop_stmt;
    END IF;
  END LOOP;
END;
