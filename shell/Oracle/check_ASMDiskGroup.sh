#!/bin/bash
# by ray
# 2016-09-19
#v0.1

sqlplus -s /nolog <<-RAY
conn / as sysdba
set linesize 300
select NAME,TOTAL_MB/1024 "TOTAL/G",FREE_MB/1024 "FREE/G",round(FREE_MB/TOTAL_MB*100)||'%' Per_Free  from v\$asm_diskgroup;
RAY
