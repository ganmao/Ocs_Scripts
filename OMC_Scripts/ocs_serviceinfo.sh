#!/bin/ksh
###############################################################################
#功能说明
# 用户量采集
#
# 用法：
# ocs_serviceinfo.sh CC库
# $1 rb库用户名
# 环境变量
# OMC_SCRIPTPATH=/ztesoft/omcagent/r11/script
# OMC_DB_CC="cc611/smart@tcc"  (用CC库)
# 输出格式:单行名值对，以"|"分割
###############################################################################

#测试
#OMC_DB_CC="cc611/smart@tcc";

#检查参数 , 输入参数
v_sShellPath=$OMC_SCRIPTPATH;
v_rbUser=$1;
v_nIntervalTime=$2;

if [ x"$v_sShellPath" = x -o ! -x "$v_sShellPath" ];then
	echo "param error";
	exit;
fi

if [ -z "$OMC_DB_CC" ]; then
	echo "OMC_DB_CC env is not configed";
	exit 1;
fi

if [ -z "$v_rbUser" ]; then
	v_rbUser="rb";
fi
#default 15min
if [ -z "$v_nIntervalTime" ]; then
	v_nIntervalTime="15";
fi
#加载配置文件
cd $v_sShellPath;

get_ocs_service_info(){
	sConnStr=$OMC_DB_CC;
	szUID=uid$$_`date +%Y%m%d%H%M%S`;
	get_ocs_service_data;
}
###############################################################################
#OCS业务量统计
#输入: 
#输出:| 分开的kpi
get_ocs_service_data(){
	sSqlFile=./work/ocs_service.sql.$szUID;
	sResultFile=./work/ocs_service_result.txt.$szUID;
cat <<End>$sSqlFile
set heading OFF;
set pagesize 10000;
set linesize 10000;
set serveroutput on;
set serveroutput on size 10000
declare
v_currDate date;
v_cycleId number;
v_querySql VARCHAR2(32767) := '';

v_currTime DATE;
v_dBeginTime DATE;
v_sBeginTime varchar2(20) := '';
v_sEndTime varchar2(20) := '';
v_dIntervalTime NUMBER(9) := $v_nIntervalTime;

IN_total number;
IN_duration number;
IN_charge number;
SMS_total number;
SMS_charge number;
ISMP_total number;
ISMP_charge number;
PS_total number;
PS_stream number;
PS_charge number;
Recurring_total number;
Recurring_charge number;
EventCharge_total number;
EventCharge_charge number;
ReCharge_total number;
ReCharge_charge number;
ReversionalCharge_total number;
ReversionalCharge_charge number;
Regulate_total number;
Regulate_charge number;
NewProdNum number;
ActiveProdNum number;
OneWayProdNum number;
ReactivationNum number;
ReActiveProdNum number;
RemoveNum number;

begin
v_currDate := TRUNC(sysdate);
--endTime=sysdate
v_currTime := sysdate;
v_sEndTime := TO_CHAR(v_currTime, 'YYYYMMDDHH24MISS');
v_sBeginTime := TO_CHAR( (v_currTime-v_dIntervalTime/(24*60)), 'YYYYMMDDHH24MISS');

select c.billing_cycle_id into v_cycleId from billing_cycle c where c.cycle_begin_date <= v_currDate and c.cycle_end_date > v_currDate
and c.billing_cycle_type_id = (select t.billing_cycle_type_id from billing_cycle_type t,system_param p 
where p.mask='DEFAULT_BILLING_CYCLE_TYPE' and t.billing_cycle_type_id= p.current_value);
--dbms_output.put_line('billing_cycle_id='||v_cycleId );

--统计语音
v_querySql := 'SELECT COUNT(*) TOTAL, nvl(SUM(DURATION),0) DURATION, NVL(SUM(NVL(CHARGE1, 0) + NVL(CHARGE2, 0) + NVL(CHARGE3, 0) + NVL(CHARGE4, 0)),0) CHARGE'
||'          FROM (SELECT EU.DURATION DURATION,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID1 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE1'
||'                       END CHARGE1,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID2 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE2'
||'                       END CHARGE2,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID3 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE3'
||'                       END CHARGE3,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID4 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE4'
||'                       END CHARGE4'
||'                  FROM EVENT_USAGE_'||v_cycleId||'@LINK_RB EU'
||'                 WHERE EU.SERVICE_TYPE = 2'
||'                   AND START_TIME between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')'
||'                )';

execute immediate v_querySql into IN_total, IN_duration, IN_charge;
commit;

--统计短信业务
v_querySql := 'SELECT COUNT(*) TOTAL, NVL(SUM(NVL(CHARGE1, 0) + NVL(CHARGE2, 0) + NVL(CHARGE3, 0) + NVL(CHARGE4, 0)),0) CHARGE'
||'          FROM (SELECT CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID1 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE1'
||'                       END CHARGE1,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID2 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE2'
||'                       END CHARGE2,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID3 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE3'
||'                       END CHARGE3,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID4 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE4'
||'                       END CHARGE4'
||'                  FROM EVENT_USAGE_'||v_cycleId||'@LINK_RB EU'
||'                 WHERE EU.SERVICE_TYPE = 4'
||'                   AND START_TIME between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')'
||'                )';

execute immediate v_querySql into SMS_total, SMS_charge;
commit;

--统计数据业务
v_querySql := 'SELECT COUNT(*) TOTAL, SUM(NVL(BYTE_UP, 0) + NVL(BYTE_DOWN, 0)) DATA_BYTE, NVL(SUM(NVL(CHARGE1, 0) + NVL(CHARGE2, 0) + NVL(CHARGE3, 0) + NVL(CHARGE4, 0)),0) CHARGE'
||'          FROM (SELECT EU.BYTE_UP BYTE_UP,'
||'                       EU.BYTE_DOWN BYTE_DOWN,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID1 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE1'
||'                       END CHARGE1,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID2 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE2'
||'                       END CHARGE2,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID3 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE3'
||'                       END CHARGE3,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID4 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE4'
||'                       END CHARGE4'
||'                  FROM EVENT_USAGE_C_'||v_cycleId||'@LINK_RB EU'
||'                 WHERE EU.SERVICE_TYPE = 1'
||'                   AND START_TIME between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')'
||'                )';

execute immediate v_querySql into PS_total, PS_stream, PS_charge;
commit;

--统计增值业务
v_querySql := 'SELECT COUNT(*) TOTAL, NVL(SUM(NVL(CHARGE1, 0) + NVL(CHARGE2, 0) + NVL(CHARGE3, 0) + NVL(CHARGE4, 0)),0) CHARGE'
||'          FROM (SELECT CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID1 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE1'
||'                       END CHARGE1,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID2 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE2'
||'                       END CHARGE2,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID3 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE3'
||'                       END CHARGE3,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID4 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE4'
||'                       END CHARGE4'
||'                  FROM EVENT_USAGE_C_'||v_cycleId||'@LINK_RB EU'
||'                 WHERE EU.SERVICE_TYPE = 8'
||'                   AND START_TIME between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')'
||'                )';

execute immediate v_querySql into ISMP_total, ISMP_charge;
commit;

--统计周期费
v_querySql := 'SELECT COUNT(*) TOTAL, NVL(SUM(NVL(CHARGE1, 0) + NVL(CHARGE2, 0) + NVL(CHARGE3, 0) + NVL(CHARGE4, 0)),0) CHARGE'
||'          FROM (SELECT EU.CREATED_DATE START_TIME,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID1 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE1'
||'                       END CHARGE1,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID2 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE2'
||'                       END CHARGE2,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID3 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE3'
||'                       END CHARGE3,'
||'                       CASE'
||'                         WHEN EU.ACCT_ITEM_TYPE_ID4 IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          EU.CHARGE4'
||'                       END CHARGE4'
||'                  FROM EVENT_RECURRING_'||v_cycleId||'@LINK_RB EU)'
||'         WHERE START_TIME between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')';

execute immediate v_querySql into Recurring_total, Recurring_charge;
commit;

--统计一次性费
v_querySql := 'SELECT COUNT(*) TOTAL, NVL(SUM(NVL(CHARGE, 0)),0) CHARGE'
||'          FROM (SELECT A.STATE_DATE START_TIME,'
||'                       CASE'
||'                         WHEN A.ACCT_ITEM_ID IN (SELECT CU_AIT_ID FROM ACCT_ITEM_TYPE WHERE ACCT_RES_ID IN (SELECT ACCT_RES_ID FROM ACCT_RES WHERE IS_CURRENCY = ''Y'')) THEN'
||'                          A.CHARGE'
||'                       END CHARGE'
||'                  FROM EVENT_CHARGE A)'
||'         WHERE START_TIME between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')';

execute immediate v_querySql into EventCharge_total, EventCharge_charge;
commit;

--统计充值费用
v_querySql := 'SELECT COUNT(*) TOTAL, NVL(SUM(NVL(CHARGE, 0)),0) CHARGE'
||'          FROM ACCT_BOOK'
||'         WHERE ACCT_BOOK_TYPE = ''P'''
||'           AND CHARGE < 0'
||'           AND CREATED_DATE between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')';

execute immediate v_querySql into ReCharge_total, ReCharge_charge;
commit;

--统计冲正
v_querySql := 'SELECT COUNT(*) TOTAL, NVL(SUM(NVL(CHARGE, 0)),0) CHARGE'
||'          FROM ACCT_BOOK'
||'         WHERE ACCT_BOOK_TYPE = ''P'''
||'           AND CHARGE >= 0'
||'           AND CREATED_DATE between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')';

execute immediate v_querySql into ReversionalCharge_total, ReversionalCharge_charge;
commit;

--统计调帐
v_querySql := 'SELECT COUNT(*) TOTAL, NVL(SUM(ABS(NVL(CHARGE, 0))),0) CHARGE'
||'          FROM ACCT_BOOK'
||'         WHERE ACCT_BOOK_TYPE = ''H'''
||'           AND CREATED_DATE between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')';

execute immediate v_querySql into Regulate_total, Regulate_charge;
commit;

--统计开户数
v_querySql := 'SELECT COUNT(*) TOTAL'
||'          FROM PROD'
||'         WHERE PROD.INDEP_PROD_ID IS NULL'
||'           AND CREATED_DATE between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')';

execute immediate v_querySql into NewProdNum;
commit;

--统计激活用户数
v_querySql := 'SELECT COUNT(*) TOTAL'
||'          FROM PROD'
||'         WHERE PROD.INDEP_PROD_ID IS NULL'
||'           AND CREATED_DATE between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')';

execute immediate v_querySql into ActiveProdNum;
commit;

--统计充值期用户数
v_querySql := 'SELECT COUNT(*) TOTAL'
||'          FROM PROD P'
||'         WHERE P.PROD_STATE = ''D'''
||'           AND P.PROD_STATE_DATE between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')'
||'           AND P.INDEP_PROD_ID IS NULL';

execute immediate v_querySql into OneWayProdNum;
commit;

--统计锁定期用户数
v_querySql := 'SELECT COUNT(*) TOTAL'
||'          FROM PROD P'
||'         WHERE P.PROD_STATE = ''E'''
||'           AND P.PROD_STATE_DATE between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')'
||'           AND P.INDEP_PROD_ID IS NULL';

execute immediate v_querySql into ReactivationNum;
commit;

--统计复机用户数
v_querySql := 'SELECT COUNT(*) TOTAL'
||'          FROM PROD P,'
||'               (SELECT *'
||'                  FROM PROD_HIS A, (SELECT MAX(SEQ) PROD_TEMP_SEQ, PROD_ID PROD_TEMP_ID FROM PROD_HIS PDH WHERE PDH.INDEP_PROD_ID IS NULL GROUP BY PROD_ID) B'
||'                 WHERE A.PROD_ID = B.PROD_TEMP_ID'
||'                   AND A.SEQ = B.PROD_TEMP_SEQ) PHS'
||'         WHERE P.PROD_STATE = ''A'''
||'           AND PHS.PROD_ID = P.PROD_ID'
||'           AND (PHS.PROD_STATE = ''D'' OR PHS.PROD_STATE = ''E'')'
||'           AND P.PROD_STATE_DATE between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')'
||'           AND P.INDEP_PROD_ID IS NULL';

execute immediate v_querySql into ReActiveProdNum;
commit;

--统计删除期用户数
v_querySql := 'SELECT COUNT(*) TOTAL'
||'          FROM PROD P'
||'         WHERE P.PROD_STATE = ''B'''
||'           AND P.PROD_STATE_DATE between TO_DATE('''||v_sBeginTime||''', ''YYYYMMDDHH24MISS'') and TO_DATE('''||v_sEndTime||''', ''YYYYMMDDHH24MISS'')'
||'           AND P.INDEP_PROD_ID IS NULL';

execute immediate v_querySql into RemoveNum;
commit;

dbms_output.put_line('IN_total='||IN_total||'|IN_duration='||IN_duration||'|IN_charge='||IN_charge||'|SMS_total='||SMS_total||'|SMS_charge='||SMS_charge
                      ||'|PS_total='||PS_total||'|PS_stream='||PS_stream||'|PS_charge='||PS_charge||'|ISMP_total='||ISMP_total||'|ISMP_charge='||ISMP_charge
                      ||'|Recurring_total='||Recurring_total||'|Recurring_charge='||Recurring_charge||'|EventCharge_total='||EventCharge_total||'|EventCharge_charge='||EventCharge_charge
                      ||'|ReCharge_total='||ReCharge_total||'|ReCharge_charge='||ReCharge_charge
                      ||'|ReversionalCharge_total='||ReversionalCharge_total||'|ReversionalCharge_charge='||ReversionalCharge_charge
                      ||'|Regulate_total='||Regulate_total||'|Regulate_charge='||Regulate_charge
                      ||'|NewProdNum='||NewProdNum||'|ActiveProdNum='||ActiveProdNum||'|OneWayProdNum='||OneWayProdNum||'|ReactivationNum='||ReactivationNum
                      ||'|ReActiveProdNum='||ReActiveProdNum||'|RemoveNum='||RemoveNum);
exception
when others then
rollback;

dbms_output.put_line('ERROR: '||SQLERRM(SQLCODE) );

end;
/
exit;
End

	sqlplus $sConnStr @$sSqlFile > $sResultFile;
	if [ `grep ERROR $sResultFile|wc -l` -ne 0 ];then
		echo ERROR DBConnStr=$sConnStr;
		exit;
	fi
	
	#去掉表中单个字段的空格
	tmp1=`cat $sResultFile|grep IN_total`;
	#返回结果
	echo $tmp1;
	
	mv -f $sSqlFile ./work/ocs_service.sql;
	mv -f $sResultFile ./work/ocs_service_result.txt;
}
get_ocs_service_info;