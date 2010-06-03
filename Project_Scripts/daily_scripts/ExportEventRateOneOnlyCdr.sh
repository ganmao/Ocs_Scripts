#!/usr/bin/ksh
#################################################################
#
#   ÿ���Զ�����ǰһ��һ���Էѿ۷ѻ���
#   ��ÿ��0�������
#       crontab set:
#           30 0 * * * /ztesoft/ocs/scripts/ExportEventRateOneOnlyCdr.sh
#
#   ������:
#       1,��������Ե���һ���Էѻ���(��EVENT_CHARGE���е���)
#           ����: DbCdrToRecurrFile -d (YYYYMMDD)  -t all
#       2,�������ڿ��Ե��������Żݻ���(��ACCT_TIEM_BILLING_XXX���е���)
#           ����: DbCdrToRecurrFile -c cycle_id
#           ע��: ��ΪACCT_TIEM_BILLING_XXX���л��к��ʵļ�¼,��ֻ����SRC_APP_ID=0�Ļ���
#################################################################

. /ztesoft/ocs/scripts/CommonENV.sh

#==========================================
#���ű��ļ�ȫ�ֱ���

#��־�ļ�����
v_LogFileName="ExportEventRateOneOnlyCdr_${gvDate_Today}.log"
#��־�ȼ�,����....
v_LogLevel="1"
v_LogContent="��ʼִ��һ���Էѻ�����������..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#KPI���
v_KpiFileName="ExportEventRateOneOnlyCdr_${gvDate_Today}.kpi"
v_KpiName="ExportEventRateOneOnlyCdr"
#��ʼ��Kpi��ز���
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0

#==========================================
#����

#��ȡ����Ӧ�õ���������
fGetAllExportNum()
{
vSql_GetAllExportNum="SELECT COUNT(*) FROM acct_item_billing_12 WHERE src_app_id = 0;"

${gvSqlplus} -S ${gvConOra_RB} << END
    set heading off
    set feedback off
    set pagesize 0

    ${vSql_GetAllExportNum}

    exit
END
}

#�ӵ����ļ��м����Ѿ�������������
fCountExportCdrNum()
{
    cd ${gvEventChargePath}
    grep '{' internalService_${gvDate_Yesterday}_* | wc -l
}

#==========================================
#main

cd ${HOME}/bin

fGetAllExportNum | read v_KpiProcAllNum
v_KpiContent=${v_KpiContent}"|ExportEventCdrAllNum=${v_KpiProcAllNum}"

#����ǰһ��һ���Է��õĻ���
${HOME}/bin/DbCdrToRecurrFile -d ${gvDate_Yesterday} -t all -l 5

#�ȴ�����ת��������֮�����bakĿ¼
sleep 600

v_LogLevel="1"
v_LogContent="ִ��һ���Էѻ��������������!"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

fCountExportCdrNum | read v_KpiProcSuccesNum
v_KpiContent=${v_KpiContent}"|ExportEventCdrSuccesNum=${v_KpiProcSuccesNum}"

v_KpiProcErrorNum=`expr ${v_KpiProcAllNum} - ${v_KpiProcSuccesNum}`
v_KpiContent=${v_KpiContent}"|ExportEventCdrErrorNum=${v_KpiProcSuccesNum}"

#==========================================
#����KPI�ļ�
gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}

#д�����ݿ�
gfInsertKpi2Oracle "����һ���Էѻ������" "����Ҫ��������:${v_KpiProcAllNum}" "�Ѿ���������:${v_KpiProcSuccesNum}" "δ��������:${v_KpiProcErrorNum}"
