#!/bin/bash
# by ray
# 2017-06-16
#v0.1


. ~/.bash_profile

sqlplus -s /nolog <<-RAY
conn  / as sysdba
set pages 1000
set lines 120
set heading off
column w_proc format a50 tru
column instance format a20 tru
column inst format a28 tru
column wait_event format a50 tru
set pages 1000
set lines 120
set heading off
column w_proc format a50 tru
column instance format a20 tru
column inst format a28 tru
column p1 format a16 tru
column p2 format a16 tru
column p3 format a15 tru
column seconds format a50 tru
column sincelw format a50 tru
column blocker_proc format a50 tru
column waiters format a50 tru
column chain_signature format a100 wra
column blocker_chain format a100 wra
select * from
(
    select
        'Current Process: '||osid W_PROC,
        'SID: '||i.INSTANCE_NAME INSTANCE,
        'INST #: '||wc.INSTANCE INST,
        'Blocking Process: '||decode(wc.BLOCKER_OSID,null,'<none>',wc.BLOCKER_OSID)||' from Instance '||wc.BLOCKER_INSTANCE BLOCKER_PROC,
        'Number of waiters: '||wc.NUM_WAITERS waiters,
        'Wait Event: '||wc.WAIT_EVENT_TEXT wait_event,
        'P1: '||wc.p1 p1,
        'P2: '||wc.p2 p2,
        'P3: '||wc.p3 p3,
        'Seconds in Wait: '||wc.IN_WAIT_SECS Seconds,
        'Seconds Since Last Wait: '||wc.TIME_SINCE_LAST_WAIT_SECS sincelw,
        'Wait Chain: '||CHAIN_ID||' : '||CHAIN_SIGNATURE chain_signature,
        'Blocking Wait Chain: '||decode(wc.BLOCKER_CHAIN_ID,null,'<none>',wc.BLOCKER_CHAIN_ID) blocker_chain
    from v\$wait_chains wc, v\$instance i
    where wc.INSTANCE=i.INSTANCE_NUMBER(+)
        and (wc.NUM_WAITERS > 0
        or (wc.BLOCKER_OSID is not null
        and wc.IN_WAIT_SECS > 10))
    order by wc.CHAIN_ID,NUM_WAITERS desc
)
where rownum < 101;
exit;
RAY