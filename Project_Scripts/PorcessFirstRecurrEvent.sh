#!/usr/bin/ksh
#################################################################
#   自动运行首月租程序
#   请在每天0点过后运行,收取前一天生效用户的月租
#       crontab set:
#           40 0 * * * /ztesoft/ocs/scripts/PorcessFirstRecurrEvent.sh
#
#研发备注：
#1.首月月租问题只是个性化需求，没有推广价值，仔细考虑后不能单独开发一个程序，
#   因为涉及TT操作，必须单条提交，所以仍然采用事件生成和事件算费的模式，
#   否则必须记录断点，事件生成和事件算费的好处是不需要记录断点;
#2. 首月租程序目前只支持处理预收类型的个性化资费计划的月租费，每日执行，
#   包括首月租周期费事件生成程序和首月租周期费事件算费程序，其中首月租周期费
#   事件生成程序的输入参数包含一个算费日期(-d RateDate)，执行时如果算费日期
#   等于订户定购的个性化资费计划的预约日期则计算该个性化资费计划的费用，
#   要求现场在 CRONTAB 配置每日执行首月租周期费事件生成程序时需要根据
#   当前日期减1天作为首月租周期费事件生成程序的输入日期参数，这个比较特别，
#   主要是避免用于用户当日预约导致资料延迟刷新的问题，因为取资料是根据23点59分59秒取的，
#   正常的预收是根据0点0分0秒，所以要推迟一天算费;
#3.对于用户预约正好是每月的开始时间的0点0分0秒时刻，此时正常租费算费程序和
#   首月租算费程序都可能执行一次算费，导致重复算费，所以首月租算费程序必须过滤
#   subs_upp_inst中的生效时间为每月的开始时间的0点0分0秒时刻的资费计划，
#   因为正常租费算费程序预收是根据周期的开始时间（0点0分0秒时刻）获取资料算费的;
#4.由于用户预约时间可能是某日任意时刻，首月租预收租费算费获取用户资料、
#   获取用户余额的时间点都取预约日期当天的23点59分59秒;
#5. 首月租的周期费算费逻辑与非首月租的周期费算费逻辑类似，目前分拣配置一样
#   （都是作为正常算费场景配置），暂时不需要在分拣中区分首月租和非首月租，
#   只需要在PYTHON中区分，PYTHON中可以取到首月租的预约时间(EA::EVENT_BEGIN_TIME)
#   和周期结束时间 (EA::CYCLE_END_TIME)以及资费计划使用状态(EA::PRICE_PLAN_INST_STATE)，
#   根据这些计费内部属性可以计算首月租;
#6.通过subs_upp_inst表的create_date和eff_date是否是同一天可以区分是首月租
#   预约生效还是首月租立即生效，对于立即生效首月租周期费事件生成程序需要过滤，
#   不处理，由一次性费用接口处理，对于预约生效的首月租一次性费用接口必须保证不能收取；
#7.正常周期费事件生成和算费程序不能计算立即生效的首月租，这是通过产品实例(prod)的
#    created_date 和 eff_date 以及周期开始时间是否是同一天判断是否是立即生效的首月租，
#   如果是立即生效的首月租正常算费不处理。
#################################################################

. /ztesoft/ocs/scripts/CommonENV.sh

cd ${HOME}/bin

#本脚本文件全局变量
#==========================================
#日志文件名称
v_LogFileName="PorcessFirstRecurrEvent_${gvDate_Today}.log"
#日志等级,内容....
v_LogLevel="1"
v_LogContent="开始执行首月租收取程序..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#KPI相关
v_KpiFileName="PorcessFirstRecurrEvent_${gvDate_Today}.kpi"
v_KpiName="PorcessFirstRecurrEvent"
#初始化Kpi相关参数
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0

gfGetCurrCycle ${gvDate_Today} | read v_CurrCycleId v_CurrCycleStat

if [[ x${v_CurrCycleId} = x ]]
then
    v_LogLevel="ERROR"
    v_LogContent="执行首月租收取程序失败- 无法获取本日帐期ID!"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    exit -1
fi

if [[ ${v_CurrCycleStat} != "A" ]]
then
    v_LogLevel="ERROR"
    v_LogContent="执行首月租收取程序失败- 获取帐期状态非'A'![${v_CurrCycleStat}]"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    exit -1
fi

#~ echo "v_CurrCycleId=${v_CurrCycleId}"
#~ echo "v_CurrCycleStat=${v_CurrCycleStat}"

v_LogLevel="4"
v_LogContent="获取帐期ID:${v_CurrCycleId};获取帐期状态:${v_CurrCycleStat}"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#==========================================
#获取用户当天所生成的首月租事件
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

#获取用户当天所生成的首月租事件
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
#运行首月租事件生成进程,跑昨日生效的用户
v_LogLevel="1"
v_LogContent="开始运行首月租事件生成进程..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
${HOME}/bin/FirstCycleRecurrEventGen -e 1 -d ${gvDate_Yesterday} -l 5

v_LogLevel="1"
v_LogContent="运行首月租事件生成进程结束!开始运行手月租批价进程..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#运行首月租批价进程
${HOME}/bin/FirstCycleRecurrEventRate -e 1 -c ${v_CurrCycleId} -l 5
v_LogLevel="1"
v_LogContent="运行首月租批价进程结束!"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#==========================================
#生成日志和Kpi文件

#休眠10分钟,等待处理程序入库
sleep 600

fGetTodayOriNumber      | read v_KpiProcAllNum
fGetTodayIndbNumber     | read v_KpiProcSuccesNum
fGetTodayOriNumberError | read v_KpiProcErrorNum

v_KpiContent=${v_KpiContent}"|FirstRecurrEventNum=${v_KpiProcAllNum}|FirstRecurrEventSuccesNum=${v_KpiProcSuccesNum}|FirstRecurrEventErrorNum=${v_KpiProcErrorNum}"

gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}

gfInsertKpi2Oracle "处理首月租任务执行结束" "共需要处理的事件有:${v_KpiProcAllNum}" "已经入库的事件有:${v_KpiProcSuccesNum}" "处理错误的事件有:${v_KpiProcErrorNum}"
