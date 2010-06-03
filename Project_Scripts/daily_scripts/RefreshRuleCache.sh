#!/usr/bin/ksh
######################################################
#
#       每天夜里刷新各个进程的RuleCache版本
#       crontab set:
#           1 0 * * * /ztesoft/ocs/scripts/RefreshRuleCache.sh
#
#######################################################

. /ztesoft/ocs/scripts/CommonENV.sh

cd ${HOME}/bin/

#刷新一些进程需要时间较长的等待时间
v_LongSleepTime=300

#刷新一些进程需要时间较短的等待时间
v_ShortSleepTime=10

#日志文件名称
v_LogFileName="RefreshRuleCache_${gvDate_Today}.log"

v_LogLevel="1"
v_LogContent="开始运行RuleCache刷新进程..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#分别设定间隔时间长和短的Pno
#注意:请在配置的时候一定注意间隔时间的长短,不要造成多个进程同时刷新
v_LongSleepProc="320 304 308 309 100 112 108"
v_ShortSleepProc="110 350 251 252 254 261 262 263"

#KPI相关
v_KpiFileName="RefreshRuleCache_${gvDate_Today}.kpi"
v_KpiName="RefreshRuleCache"
#初始化Kpi相关参数
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0

#==========================================
#后台消息刷新资费
#输入:  $1      间隔休息时间
#       $2      需要刷新的PNO
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
        v_LogContent="开始刷新进程: Pno=[${fv_SendPno}]..."
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

        ostool send ${fv_SendPno} 65006
        v_KpiContent=${v_KpiContent}"|RefreshProcPno=${fv_SendPno}"
        v_KpiProcSuccesNum=`expr ${v_KpiProcSuccesNum} + 1`
    fi
}

#==========================================
#实际运行程序运行部分

#建立一个新的资费版本
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
v_LogContent="已经创建最新资费版本[${v_CurrentRuleCacheVersion}]!"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

v_KpiContent=${v_KpiContent}"|CreateRuleCache=${v_CurrentRuleCacheVersion}"


#先刷新间隔时间较短的进程
for v_Proc in ${v_ShortSleepProc}
do
    #print "Begin Refresh RuleCache proc Pno=${v_Proc}"
    fRefreshRuleCache ${v_ShortSleepTime} ${v_Proc}
done

#再刷新间隔时间较长的进程
for v_Proc in ${v_LongSleepProc}
do
    #print "Begin Refresh RuleCache proc Pno=${v_Proc}"
    fRefreshRuleCache ${v_LongSleepTime} ${v_Proc}
done

#将系统中无用的资费版本删除掉
RuleCache -u
RuleCache -u

RuleCache -d all
v_KpiContent=${v_KpiContent}"|DeleteInvalidatedRuleCache=ok"

#调用生成KPI文件
gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}


v_KpiProcErrorNum=`expr ${v_KpiProcAllNum} - ${v_KpiProcSuccesNum}`

#将KPI结果写入数据库
gfInsertKpi2Oracle "刷新RuleCache进程维护结束" "共需要刷新数据:${v_KpiProcAllNum}" "刷新正确数据:${v_KpiProcSuccesNum}" "刷新错误数据:${v_KpiProcErrorNum}"