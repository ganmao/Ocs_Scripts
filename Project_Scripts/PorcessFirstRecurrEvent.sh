#!/usr/bin/ksh
#################################################################
#   �Զ��������������
#   ����ÿ��0���������,��ȡǰһ����Ч�û�������
#       crontab set:
#           40 0 * * * /ztesoft/ocs/scripts/PorcessFirstRecurrEvent.sh
#
#�з���ע��
#1.������������ֻ�Ǹ��Ի�����û���ƹ��ֵ����ϸ���Ǻ��ܵ�������һ������
#   ��Ϊ�漰TT���������뵥���ύ��������Ȼ�����¼����ɺ��¼���ѵ�ģʽ��
#   ��������¼�ϵ㣬�¼����ɺ��¼���ѵĺô��ǲ���Ҫ��¼�ϵ�;
#2. ���������Ŀǰֻ֧�ִ���Ԥ�����͵ĸ��Ի��ʷѼƻ�������ѣ�ÿ��ִ�У�
#   �������������ڷ��¼����ɳ�������������ڷ��¼���ѳ����������������ڷ�
#   �¼����ɳ���������������һ���������(-d RateDate)��ִ��ʱ����������
#   ���ڶ��������ĸ��Ի��ʷѼƻ���ԤԼ���������ø��Ի��ʷѼƻ��ķ��ã�
#   Ҫ���ֳ��� CRONTAB ����ÿ��ִ�����������ڷ��¼����ɳ���ʱ��Ҫ����
#   ��ǰ���ڼ�1����Ϊ���������ڷ��¼����ɳ�����������ڲ���������Ƚ��ر�
#   ��Ҫ�Ǳ��������û�����ԤԼ���������ӳ�ˢ�µ����⣬��Ϊȡ�����Ǹ���23��59��59��ȡ�ģ�
#   ������Ԥ���Ǹ���0��0��0�룬����Ҫ�Ƴ�һ�����;
#3.�����û�ԤԼ������ÿ�µĿ�ʼʱ���0��0��0��ʱ�̣���ʱ���������ѳ����
#   ��������ѳ��򶼿���ִ��һ����ѣ������ظ���ѣ�������������ѳ���������
#   subs_upp_inst�е���Чʱ��Ϊÿ�µĿ�ʼʱ���0��0��0��ʱ�̵��ʷѼƻ���
#   ��Ϊ���������ѳ���Ԥ���Ǹ������ڵĿ�ʼʱ�䣨0��0��0��ʱ�̣���ȡ������ѵ�;
#4.�����û�ԤԼʱ�������ĳ������ʱ�̣�������Ԥ�������ѻ�ȡ�û����ϡ�
#   ��ȡ�û�����ʱ��㶼ȡԤԼ���ڵ����23��59��59��;
#5. ����������ڷ�����߼��������������ڷ�����߼����ƣ�Ŀǰ�ּ�����һ��
#   ��������Ϊ������ѳ������ã�����ʱ����Ҫ�ڷּ�������������ͷ������⣬
#   ֻ��Ҫ��PYTHON�����֣�PYTHON�п���ȡ���������ԤԼʱ��(EA::EVENT_BEGIN_TIME)
#   �����ڽ���ʱ�� (EA::CYCLE_END_TIME)�Լ��ʷѼƻ�ʹ��״̬(EA::PRICE_PLAN_INST_STATE)��
#   ������Щ�Ʒ��ڲ����Կ��Լ���������;
#6.ͨ��subs_upp_inst���create_date��eff_date�Ƿ���ͬһ�����������������
#   ԤԼ��Ч����������������Ч������������Ч���������ڷ��¼����ɳ�����Ҫ���ˣ�
#   ��������һ���Է��ýӿڴ�������ԤԼ��Ч��������һ���Է��ýӿڱ��뱣֤������ȡ��
#7.�������ڷ��¼����ɺ���ѳ����ܼ���������Ч�������⣬����ͨ����Ʒʵ��(prod)��
#    created_date �� eff_date �Լ����ڿ�ʼʱ���Ƿ���ͬһ���ж��Ƿ���������Ч�������⣬
#   �����������Ч��������������Ѳ�����
#################################################################

. /ztesoft/ocs/scripts/CommonENV.sh

cd ${HOME}/bin

#���ű��ļ�ȫ�ֱ���
#==========================================
#��־�ļ�����
v_LogFileName="PorcessFirstRecurrEvent_${gvDate_Today}.log"
#��־�ȼ�,����....
v_LogLevel="1"
v_LogContent="��ʼִ����������ȡ����..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#KPI���
v_KpiFileName="PorcessFirstRecurrEvent_${gvDate_Today}.kpi"
v_KpiName="PorcessFirstRecurrEvent"
#��ʼ��Kpi��ز���
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0

gfGetCurrCycle ${gvDate_Today} | read v_CurrCycleId v_CurrCycleStat

if [[ x${v_CurrCycleId} = x ]]
then
    v_LogLevel="ERROR"
    v_LogContent="ִ����������ȡ����ʧ��- �޷���ȡ��������ID!"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    exit -1
fi

if [[ ${v_CurrCycleStat} != "A" ]]
then
    v_LogLevel="ERROR"
    v_LogContent="ִ����������ȡ����ʧ��- ��ȡ����״̬��'A'![${v_CurrCycleStat}]"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    exit -1
fi

#~ echo "v_CurrCycleId=${v_CurrCycleId}"
#~ echo "v_CurrCycleStat=${v_CurrCycleStat}"

v_LogLevel="4"
v_LogContent="��ȡ����ID:${v_CurrCycleId};��ȡ����״̬:${v_CurrCycleStat}"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#==========================================
#��ȡ�û����������ɵ��������¼�
fGetTodayOriNumber()
{
vSql_GetTodayOriNumber="
SELECT count(*)                                 \
  FROM event_recurring_ori_${v_CurrCycleId}     \
 WHERE TRUNC (created_date) = TRUNC (SYSDATE)   \
   AND recurring_re_type = 1;"

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
   AND recurring_re_type = 1;"

${gvSqlplus} -S ${gvConOra_RB} << END
    set heading off
    set feedback off
    set pagesize 0

    ${vSql_GetTodayIndbNumber}

    exit
END
}

#��ȡ�û����������ɵ��������¼�
fGetTodayOriNumberError()
{
vSql_GetTodayOriNumberError="
SELECT count(*)                                 \
  FROM event_recurring_ori_${v_CurrCycleId}     \
 WHERE TRUNC (created_date) = TRUNC (SYSDATE)   \
   AND recurring_re_type = 1
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
#�����������¼����ɽ���,��������Ч���û�
v_LogLevel="1"
v_LogContent="��ʼ�����������¼����ɽ���..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
${HOME}/bin/FirstCycleRecurrEventGen -e 1 -d ${gvDate_Yesterday} -l 5

v_LogLevel="1"
v_LogContent="�����������¼����ɽ��̽���!��ʼ�������������۽���..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#�������������۽���
${HOME}/bin/FirstCycleRecurrEventRate -e 1 -c ${v_CurrCycleId} -l 5
v_LogLevel="1"
v_LogContent="�������������۽��̽���!"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#==========================================
#������־��Kpi�ļ�

#����10����,�ȴ�����������
sleep 600

fGetTodayOriNumber      | read v_KpiProcAllNum
fGetTodayIndbNumber     | read v_KpiProcSuccesNum
fGetTodayOriNumberError | read v_KpiProcErrorNum

v_KpiContent=${v_KpiContent}"|FirstRecurrEventNum=${v_KpiProcAllNum}|FirstRecurrEventSuccesNum=${v_KpiProcSuccesNum}|FirstRecurrEventErrorNum=${v_KpiProcErrorNum}"

gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}

gfInsertKpi2Oracle "��������������ִ�н���" "����Ҫ������¼���:${v_KpiProcAllNum}" "�Ѿ������¼���:${v_KpiProcSuccesNum}" "���������¼���:${v_KpiProcErrorNum}"
