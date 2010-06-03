#!/usr/bin/ksh
#################################################################
#
#   自动运行日租程序
#   请在每天0点过后运行,收取当天日租
#       crontab set:
#           0 1 * * * /ztesoft/ocs/scripts/PorcessDailyRecurrEvent.sh
#
#################################################################

. /ztesoft/ocs/scripts/CommonENV.sh

cd ${HOME}/bin

#本脚本文件全局变量
#==========================================
#日志文件名称
v_LogFileName="PorcessDailyRecurrEvent_${gvDate_Today}.log"
#日志等级,内容....
v_LogLevel="1"
v_LogContent="开始执行日租收取程序..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#KPI相关
v_KpiFileName="PorcessDailyRecurrEvent_${gvDate_Today}.kpi"
v_KpiName="PorcessDailyRecurrEvent"
#初始化Kpi相关参数
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0


gfGetCurrCycle ${gvDate_Today} | read v_CurrCycleId v_CurrCycleStat

if [[ x${v_CurrCycleId} = x ]]
then
    v_LogLevel="ERROR"
    v_LogContent="执行日租收取程序失败- 无法获取本日帐期ID!"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    exit -1
fi

if [[ ${v_CurrCycleStat} != "A" ]]
then
    v_LogLevel="ERROR"
    v_LogContent="执行日租收取程序失败- 获取帐期状态非'A'![${v_CurrCycleStat}]"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    exit -1
fi

#~ echo "v_CurrCycleId=${v_CurrCycleId}"
#~ echo "v_CurrCycleStat=${v_CurrCycleStat}"

v_LogLevel="4"
v_LogContent="获取帐期ID:${v_CurrCycleId};获取帐期状态:${v_CurrCycleStat}"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#==========================================
#获取用户当天所生成的日租事件
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

#获取用户当天所生成的日租事件
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
#运行日租事件生成进程,跑昨日生效的用户
v_LogLevel="1"
v_LogContent="开始运行日租事件生成进程..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
${HOME}/bin/RecurrEventGen -e 3 -d ${gvDate_Today} -p 2 -l 0

v_LogLevel="1"
v_LogContent="运行日租事件生成进程结束!开始运行手日租批价进程..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#运行日租批价进程
${HOME}/bin/RecurrEventRate -e 3 -c ${v_CurrCycleId} -l 0
v_LogLevel="1"
v_LogContent="运行日租批价进程结束!"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#==========================================
#生成日志和Kpi文件

#休眠10分钟,等待处理程序入库
sleep 600

fGetTodayOriNumber      | read v_KpiProcAllNum
fGetTodayIndbNumber     | read v_KpiProcSuccesNum
fGetTodayOriNumberError | read v_KpiProcErrorNum

v_KpiContent="|DailyRecurrEventNum=${v_KpiProcAllNum}|DailyRecurrEventSuccesNum=${v_KpiProcSuccesNum}|DailyRecurrEventErrorNum=${v_KpiProcErrorNum}"

gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}

gfInsertKpi2Oracle "处理日租任务执行结束" "共需要处理的事件有:${v_KpiProcAllNum}" "已经入库的事件有:${v_KpiProcSuccesNum}" "处理错误的事件有:${v_KpiProcErrorNum}"
