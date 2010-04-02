#!/usr/bin/ksh
#######################################################
#
#       ͨ�õ��û���Shell,������Shell֮ǰ���ȵ���
#
#######################################################

#���û�����������
. /ztesoft/ocs/.profile

#����������ȫ�ֱ����趨
#######################################################
#�趨����
#=====================================================
#��û�������
gvDate_Today=`date +"%Y%m%d"`
gvDate_Today_Month=`date +"%Y%m"`
gvDate_Yesterday=`TZ=EAT+16;date +%Y%m%d`
gvDate_Yesterday_Month=`TZ=EAT+16;date +%Y%m`
gvDate_Tomorrow=`TZ=EAT-16;date +%Y%m%d`
gvDate_Tomorrow_Month=`TZ=EAT-16;date +%Y%m`

#��ȡ��������
#=====================================================
gvHostName=`hostname`

#��ȡ�����·�
#=====================================================
v_year=`date +"%Y"`
v_month=`date +"%m"`
if [[ x${v_month} = x"01" ]]
then
    v_month="12"
    v_year=`expr ${v_year} - 1`
    gvLastMonth=${v_year}${v_month}
else
    gvLastMonth=`expr ${v_year}${v_month} - 1`
fi

#�趨Oracle�Ŀͻ����ַ���
#=====================================================
export NLS_LANG="SIMPLIFIED CHINESE_CHINA.ZHS16GBK"

#�趨��������HOME��ֵ
#=====================================================
if [ x${HOME} = x ]
then
    HOME="/ztesoft/ocs/"
    export HOME
fi

#�趨����·��
#=====================================================
gvScriptHome="/ztesoft/ocs/scripts/"
gvSqlplus="/oracle/product/102/bin/sqlplus"

#����Oracle���Ӵ�
#=====================================================
gvConOra_CC='cc/smart123@cc'
gvConOra_RB='rb/smart123@rb'
gvConOra_OMC='omc/smart@rb'
#�����ڴ����ݿ����Ӵ�
gvConMDB_OCS="uid=ocs;pwd=ocs123;dsn=ocs"

#�����ű�ͨ�õĴ����־·��
gvLogPath="/ztesoft/ocs/log/"

#һ���ԷѺ������Żݵ����ļ�Ŀ¼
gvEventChargePath="/ztesoft/ocs/data/cdrgen/DBCdrToRecurrFile/output/bak"

#�趨�����������·��
#=====================================================
#�������ݷ�������ַ
gvRemoteCdrBakHost="172.31.1.143"
gvRemoteCdrBakUser="cdradm"
gvRemoteCdrBakPasswd="cdradm321!"
#Զ���ϴ���ַ
gvRemoteCdrBakPath="/ftp/backupcdr/"
#���ػ������·��
gvSrcCdrPathVarry[0]="/ztesoft/ocs/data/cdrgen/dcc/output/normal/bak/bak"
#���ر��黰������·��
gvLocalBackPath="/ztesoft/ocs/data/CdrBackUp"
#��������ƥ���ʽ
gvUpCdrFormat="in6_G_*_*_${gvDate_Yesterday}??????.s"

#KPIָ�����·��
#=====================================================
#KPI���·��
gvKpiPath="${HOME}/info/"
#KPIָ���ļ�����ǰ׺
gvKpiPerf="Schedule_"

#���¼���Ϊд��oracle������
#KPI������������
gvKpiTableName="omc_event"
#KPIָ���е�KPI_ID:omc.omc_event.kpi_id
gvKpiTable_KpiId="schedule"
#Kpiָ�������:omc.omc_event.kpi_type
gvKpiTable_KpiType="03"
gvKpiTable_NeId="1"

#��ȡ�����ļ����ʷѰ汾��С
gvRuleCacheSize=`cat ${HOME}/etc/App.config | grep "MemSize" | sed 's/ //g' | cut -d = -f 2`

#ͨ�ú�����
#######################################################
#��ȡ��ǰʱ�亯��
gfGetCurrentTime()
{
    echo `date +"%Y-%m-%d %H:%M:%S"`
}

gfGetCurrentTime2()
{
    echo `date +"%Y%m%d%H%M%S"`
}

#==========================================
#����KPI�ļ�
#����:
#KPI�ļ�����    $1
#KPIָ������    $2
#KPI����        $3
gfWriteKpiFile()
{
    fv_KpiFileName=${1}
    fv_KpiName=${2}
    fv_KpiContent="${3} ${4} ${5} ${6} ${7} ${8} ${9}"

    echo "${fv_KpiName}${fv_KpiContent}"
    echo "${fv_KpiName}${fv_KpiContent}" >> ${gvKpiPath}/${gvKpiPerf}${fv_KpiFileName}
}

#==========================================
#����Ϣд����־
gfWriteLogFile()
{
    fv_LogName=${1}
    fv_LogLevel=${2}
    fv_LogContent="${3} ${4} ${5} ${6} ${7} ${8} ${9}"

    fv_LogStr="[`gfGetCurrentTime`][${gvHostName}][LOG_${fv_LogLevel}]${fv_LogContent}"

    echo ${fv_LogStr}
    echo ${fv_LogStr} >> ${gvLogPath}${fv_LogName}
}

#==========================================
#��ȡĳ�յ�����ID,���ܷ��ؿ�
#����:
#   $1      ����(YYYYMMDD)
#   $2      ��������(Ĭ��Ϊ1)
#����:
#   $1      ID
#   $2      ״̬
gfGetCurrCycle()
{
    fv_Date=${1}
    fv_CycleType=${2}

    if [[ x${fv_CycleType} = x ]]
    then
        fv_CycleType="1"
    fi

vSql_GetCurrCycle="                                         \
SELECT BILLING_CYCLE_ID, STATE                              \
  FROM BILLING_CYCLE                                        \
 WHERE BILLING_CYCLE_TYPE_ID = ${fv_CycleType}              \
   AND CYCLE_BEGIN_DATE <= TO_DATE('${fv_Date}', 'yyyymmdd') \
   AND CYCLE_END_DATE > TO_DATE('${fv_Date}', 'yyyymmdd');"

${gvSqlplus} -S ${gvConOra_CC} << END
    set heading off
    set feedback off
    set pagesize 0

    ${vSql_GetCurrCycle}

    exit
END
}

#==========================================
#��ȡOMC_EVENT.EVENT_ID�ı������ֵ
gfGetCurrentMaxEventId()
{
vSql_GetMaxEventId="SELECT max(event_id) FROM ${gvKpiTableName};"
${gvSqlplus} -S ${gvConOra_OMC} << END
    set heading off
    set feedback off
    set pagesize 0

    ${vSql_GetMaxEventId}

    exit
END
}


#��KPI����Ϣд�����ݿ�
#~ Name        Type           Nullable Default Comments
#~ ----------- -------------- -------- ------- --------
#~ EVENT_ID    NUMBER(9)
#~ KPI_ID      VARCHAR2(64)
#~ NE_ID       NUMBER(6)      Y
#~ RESOURCE_ID NUMBER(6)      Y
#~ KPI_TYPE    CHAR(2)
#~ DETAIL      VARCHAR2(2048)
#~ CREATE_DATE DATE
#~ RESULT1     VARCHAR2(256)  Y
#~ RESULT2     VARCHAR2(256)  Y
#~ RESULT3     VARCHAR2(256)  Y
#�������:
#$1     OMC_EVENT.DETAIL
#$2     OMC_EVENT.RESULT1
#$3     OMC_EVENT.RESULT2
#$4     OMC_EVENT.RESULT3
#ע��:����KPI�䲻Ҫ�пո�
gfInsertKpi2Oracle()
{
    if [[ x${1} = x ]];then fv_detail="NULL"; else fv_detail=${1};fi
    if [[ x${2} = x ]];then fv_result1="NULL";else fv_result1=${2};fi
    if [[ x${3} = x ]];then fv_result2="NULL";else fv_result2=${3};fi
    if [[ x${4} = x ]];then fv_result3="NULL";else fv_result3=${4};fi

    gfGetCurrentMaxEventId | read fv_event_id
    fv_event_id=`expr ${fv_event_id} + 1`
    #~ echo "fv_event_id=${fv_event_id}"

    vSql_InsertKpi="insert into ${gvKpiTableName} (EVENT_ID, KPI_ID, NE_ID, KPI_TYPE, DETAIL, CREATE_DATE, RESULT1, RESULT2, RESULT3) \
    values (${fv_event_id}, '${gvKpiTable_KpiId}', ${gvKpiTable_NeId}, '${gvKpiTable_KpiType}', '${fv_detail}', SYSDATE, \
    '${fv_result1}', '${fv_result2}', '${fv_result3}');"

    #~ echo ${vSql_InsertKpi}

${gvSqlplus} -S ${gvConOra_OMC} << END
    set heading off
    set feedback off
    set pagesize 0

    ${vSql_InsertKpi}

    commit;
    exit
END
}

#==========================================
#�ж��û��Ƿ���subs/subs_his���д���
#�������:
#$1     ����86���û�����
#���ز���:
#       ��subs���subs_his���в��ҵ�����������¼�ܺ�
gfJudgeIfOcsUser()
{
    fv_Misdn=${1}

    vSql_JudgeIfOcsUser="select sum(cnt) from ( \
        select count(*) cnt from subs where acc_nbr = '${fv_Misdn}' \
        union all \
        select count(*) cnt from subs_his where acc_nbr = '${fv_Misdn}');"

${gvSqlplus} -S ${gvConOra_CC} << END
    set heading off
    set feedback off
    set pagesize 0

    ${vSql_JudgeIfOcsUser}

    commit;
    exit
END
}