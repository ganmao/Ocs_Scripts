#!/usr/bin/ksh
######################################################
#
#       ÿ��ҹ��ˢ�¸������̵�RuleCache�汾
#       crontab set:
#           1 0 * * * /ztesoft/ocs/scripts/RefreshRuleCache.sh
#
#######################################################

. /ztesoft/ocs/scripts/CommonENV.sh

cd ${HOME}/bin/

#ˢ��һЩ������Ҫʱ��ϳ��ĵȴ�ʱ��
v_LongSleepTime=300

#ˢ��һЩ������Ҫʱ��϶̵ĵȴ�ʱ��
v_ShortSleepTime=10

#��־�ļ�����
v_LogFileName="RefreshRuleCache_${gvDate_Today}.log"

v_LogLevel="1"
v_LogContent="��ʼ����RuleCacheˢ�½���..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#�ֱ��趨���ʱ�䳤�Ͷ̵�Pno
#ע��:�������õ�ʱ��һ��ע����ʱ��ĳ���,��Ҫ��ɶ������ͬʱˢ��
v_LongSleepProc="320 304 308 309 100 112 108"
v_ShortSleepProc="110 350 251 252 254 261 262 263"

#KPI���
v_KpiFileName="RefreshRuleCache_${gvDate_Today}.kpi"
v_KpiName="RefreshRuleCache"
#��ʼ��Kpi��ز���
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0

#==========================================
#��̨��Ϣˢ���ʷ�
#����:  $1      �����Ϣʱ��
#       $2      ��Ҫˢ�µ�PNO
fRefreshRuleCache()
{
    v_KpiProcAllNum=`expr ${v_KpiProcAllNum} + 1`
    fv_SleepTime=$1
    fv_SendPno=$2

    v_PorcNum=`ps -fu ocs|grep -v grep|awk '{print $10}'|grep ${fv_SendPno}|wc -l`
    if (( ${v_PorcNum} == "1" || ${v_PorcNum} > "1" ))
    then
        sleep ${fv_SleepTime}

        v_LogLevel="4"
        v_LogContent="��ʼˢ�½���: Pno=[${fv_SendPno}]..."
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

        ostool send ${fv_SendPno} 65006
        v_KpiContent=${v_KpiContent}"|RefreshProcPno=${fv_SendPno}"
        v_KpiProcSuccesNum=`expr ${v_KpiProcSuccesNum} + 1`
    fi
}

#==========================================
#ʵ�����г������в���

#����һ���µ��ʷѰ汾
if [[ x${gvRuleCacheSize} = x ]]
then
    RuleCache -c 200
else
    RuleCache -c ${gvRuleCacheSize}
    #echo "RuleCache -c ${gvRuleCacheSize}"
fi
sleep ${v_ShortSleepTime}
v_CurrentRuleCacheVersion=`${HOME}/bin/RuleCache -v | grep 'Current Version' | awk '{print $7}'`
v_LogLevel="1"
v_LogContent="�Ѿ����������ʷѰ汾[${v_CurrentRuleCacheVersion}]!"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

v_KpiContent=${v_KpiContent}"|CreateRuleCache=${v_CurrentRuleCacheVersion}"


#��ˢ�¼��ʱ��϶̵Ľ���
for v_Proc in ${v_ShortSleepProc}
do
    #print "Begin Refresh RuleCache proc Pno=${v_Proc}"
    fRefreshRuleCache ${v_ShortSleepTime} ${v_Proc}
done

#��ˢ�¼��ʱ��ϳ��Ľ���
for v_Proc in ${v_LongSleepProc}
do
    #print "Begin Refresh RuleCache proc Pno=${v_Proc}"
    fRefreshRuleCache ${v_LongSleepTime} ${v_Proc}
done

#��ϵͳ�����õ��ʷѰ汾ɾ����
RuleCache -u
RuleCache -u

RuleCache -d all
v_KpiContent=${v_KpiContent}"|DeleteInvalidatedRuleCache=ok"

#��������KPI�ļ�
gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}


v_KpiProcErrorNum=`expr ${v_KpiProcAllNum} - ${v_KpiProcSuccesNum}`

#��KPI���д�����ݿ�
gfInsertKpi2Oracle "ˢ��RuleCache����ά������" "����Ҫˢ������:${v_KpiProcAllNum}" "ˢ����ȷ����:${v_KpiProcSuccesNum}" "ˢ�´�������:${v_KpiProcErrorNum}"