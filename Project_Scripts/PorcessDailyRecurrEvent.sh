#!/usr/bin/ksh
#################################################################
#
#   �Զ������������
#   ����ÿ��0���������,��ȡ��������
#       crontab set:
#           0 1 * * * /ztesoft/ocs/scripts/PorcessDailyRecurrEvent.sh
#
#################################################################

. /ztesoft/ocs/scripts/CommonENV.sh

cd ${HOME}/bin

#���ű��ļ�ȫ�ֱ���
#==========================================
#��־�ļ�����
v_LogFileName="PorcessDailyRecurrEvent_${gvDate_Today}.log"
#��־�ȼ�,����....
v_LogLevel="1"
v_LogContent="��ʼִ��������ȡ����..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#KPI���
v_KpiFileName="PorcessDailyRecurrEvent_${gvDate_Today}.kpi"
v_KpiName="PorcessDailyRecurrEvent"
#��ʼ��Kpi��ز���
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0


gfGetCurrCycle ${gvDate_Today} | read v_CurrCycleId v_CurrCycleStat

if [[ x${v_CurrCycleId} = x ]]
then
    v_LogLevel="ERROR"
    v_LogContent="ִ��������ȡ����ʧ��- �޷���ȡ��������ID!"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    exit -1
fi

if [[ ${v_CurrCycleStat} != "A" ]]
then
    v_LogLevel="ERROR"
    v_LogContent="ִ��������ȡ����ʧ��- ��ȡ����״̬��'A'![${v_CurrCycleStat}]"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    exit -1
fi

#~ echo "v_CurrCycleId=${v_CurrCycleId}"
#~ echo "v_CurrCycleStat=${v_CurrCycleStat}"

v_LogLevel="4"
v_LogContent="��ȡ����ID:${v_CurrCycleId};��ȡ����״̬:${v_CurrCycleStat}"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#==========================================
#��ȡ�û����������ɵ������¼�
fGetTodayOriNumber()
{
vSql_GetTodayOriNumber="
SELECT count(*)                                 \
  FROM event_recurring_ori_${v_CurrCycleId}     \
 WHERE TRUNC (created_date) = TRUNC (SYSDATE)   \
   AND recurring_re_type = 3;"

${gvSqlplus} -S ${gvConOra_RB} << END
    set heading off
    set feedback off
    set pagesize 0

    ${vSql_GetTodayOriNumber}

    exit
END
}

fGetTodayIndbNumber()
{
vSql_GetTodayIndbNumber="
SELECT count(*)                                 \
  FROM event_recurring_${v_CurrCycleId}         \
 WHERE TRUNC (created_date) = TRUNC (SYSDATE)   \
   AND recurring_re_type = 3;"

${gvSqlplus} -S ${gvConOra_RB} << END
    set heading off
    set feedback off
    set pagesize 0

    ${vSql_GetTodayIndbNumber}

    exit
END
}

#��ȡ�û����������ɵ������¼�
fGetTodayOriNumberError()
{
vSql_GetTodayOriNumberError="
SELECT count(*)                                 \
  FROM event_recurring_ori_${v_CurrCycleId}     \
 WHERE TRUNC (created_date) = TRUNC (SYSDATE)   \
   AND recurring_re_type = 3
   AND STATE = 'A';"

${gvSqlplus} -S ${gvConOra_RB} << END
    set heading off
    set feedback off
    set pagesize 0

    ${vSql_GetTodayOriNumberError}

    exit
END
}
#==========================================
#main
#���������¼����ɽ���,��������Ч���û�
v_LogLevel="1"
v_LogContent="��ʼ���������¼����ɽ���..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
${HOME}/bin/RecurrEventGen -e 3 -d ${gvDate_Today} -p 2 -l 0

v_LogLevel="1"
v_LogContent="���������¼����ɽ��̽���!��ʼ�������������۽���..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#�����������۽���
${HOME}/bin/RecurrEventRate -e 3 -c ${v_CurrCycleId} -l 0
v_LogLevel="1"
v_LogContent="�����������۽��̽���!"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#==========================================
#������־��Kpi�ļ�

#����10����,�ȴ�����������
sleep 600

fGetTodayOriNumber      | read v_KpiProcAllNum
fGetTodayIndbNumber     | read v_KpiProcSuccesNum
fGetTodayOriNumberError | read v_KpiProcErrorNum

v_KpiContent="|DailyRecurrEventNum=${v_KpiProcAllNum}|DailyRecurrEventSuccesNum=${v_KpiProcSuccesNum}|DailyRecurrEventErrorNum=${v_KpiProcErrorNum}"

gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}

gfInsertKpi2Oracle "������������ִ�н���" "����Ҫ������¼���:${v_KpiProcAllNum}" "�Ѿ������¼���:${v_KpiProcSuccesNum}" "���������¼���:${v_KpiProcErrorNum}"
