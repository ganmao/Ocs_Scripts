#!/usr/bin/ksh
#################################################################
#
#   每天自动导出前一天一次性费扣费话单
#   在每天0点后运行
#       crontab set:
#           30 0 * * * /ztesoft/ocs/scripts/ExportEventRateOneOnlyCdr.sh
#
#   程序功能:
#       1,按照天可以导出一次性费话单(从EVENT_CHARGE表中导出)
#           举例: DbCdrToRecurrFile -d (YYYYMMDD)  -t all
#       2,按照帐期可以导出帐务优惠话单(从ACCT_TIEM_BILLING_XXX表中导出)
#           举例: DbCdrToRecurrFile -c cycle_id
#           注意: 因为ACCT_TIEM_BILLING_XXX表中还有合帐的记录,故只导出SRC_APP_ID=0的话单
#################################################################

. /ztesoft/ocs/scripts/CommonENV.sh

#==========================================
#本脚本文件全局变量

#日志文件名称
v_LogFileName="ExportEventRateOneOnlyCdr_${gvDate_Today}.log"
#日志等级,内容....
v_LogLevel="1"
v_LogContent="开始执行一次性费话单导出程序..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

#KPI相关
v_KpiFileName="ExportEventRateOneOnlyCdr_${gvDate_Today}.kpi"
v_KpiName="ExportEventRateOneOnlyCdr"
#初始化Kpi相关参数
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0

#==========================================
#函数

#获取表中应该导出数据量
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

#从导出文件中计算已经导出的数据量
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

#导出前一天一次性费用的话单
${HOME}/bin/DbCdrToRecurrFile -d ${gvDate_Yesterday} -t all -l 5

#等待话单转换程序处理之后放入bak目录
sleep 600

v_LogLevel="1"
v_LogContent="执行一次性费话单导出程序结束!"
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

fCountExportCdrNum | read v_KpiProcSuccesNum
v_KpiContent=${v_KpiContent}"|ExportEventCdrSuccesNum=${v_KpiProcSuccesNum}"

v_KpiProcErrorNum=`expr ${v_KpiProcAllNum} - ${v_KpiProcSuccesNum}`
v_KpiContent=${v_KpiContent}"|ExportEventCdrErrorNum=${v_KpiProcSuccesNum}"

#==========================================
#生成KPI文件
gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}

#写入数据库
gfInsertKpi2Oracle "导出一次性费话单完成" "共需要导出数据:${v_KpiProcAllNum}" "已经导出数据:${v_KpiProcSuccesNum}" "未导出数据:${v_KpiProcErrorNum}"
