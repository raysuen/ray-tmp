var old_name varchar2(20)
var old_dbid number
var new_name varchar2(20)
var new_dbid number

exec select name, dbid -
       into :old_name,:old_dbid -
       from v$database

print old_name

accept new_name prompt "Enter the new Database Name:"

accept new_dbid prompt "Enter the new Database ID:"

exec :new_name:='&&new_name'
exec :new_dbid:=&&new_dbid

set serveroutput on
exec dbms_output.put_line('Convert '||:old_name||  -
     '('||to_char(:old_dbid)||') to '||:new_name|| -
     '('||to_char(:new_dbid)||')')
         
declare
  v_chgdbid   binary_integer;
  v_chgdbname binary_integer;
  v_skipped   binary_integer;
begin
  dbms_backup_restore.nidbegin(:new_name,
       :old_name,:new_dbid,:old_dbid,0,0,10);
  dbms_backup_restore.nidprocesscf(
       v_chgdbid,v_chgdbname);
  dbms_output.put_line('ControlFile: ');
  dbms_output.put_line('  => Change Name:'
       ||to_char(v_chgdbname));
  dbms_output.put_line('  => Change DBID:'
       ||to_char(v_chgdbid));
  for i in (select file#,name from v$datafile)
     loop
     dbms_backup_restore.nidprocessdf(i.file#,0,
       v_skipped,v_chgdbid,v_chgdbname);
     dbms_output.put_line('DataFile: '||i.name);
     dbms_output.put_line('  => Skipped:'
       ||to_char(v_skipped));
     dbms_output.put_line('  => Change Name:'
       ||to_char(v_chgdbname));
     dbms_output.put_line('  => Change DBID:'
       ||to_char(v_chgdbid));
     end loop;
  for i in (select file#,name from v$tempfile)
     loop
     dbms_backup_restore.nidprocessdf(i.file#,1,
       v_skipped,v_chgdbid,v_chgdbname);
     dbms_output.put_line('DataFile: '||i.name);
     dbms_output.put_line('  => Skipped:'
       ||to_char(v_skipped));
     dbms_output.put_line('  => Change Name:'
       ||to_char(v_chgdbname));
     dbms_output.put_line('  => Change DBID:'
       ||to_char(v_chgdbid));
     end loop;
  dbms_backup_restore.nidend;
end;
/   