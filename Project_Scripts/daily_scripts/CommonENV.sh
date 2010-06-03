#!/usr/bin/ksh
#######################################################
#
#       通用调用环境Shell,在所有Shell之前首先调用
#
#######################################################

#调用基本环境变量
. /ztesoft/ocs/.profile

#环境变量和全局变量设定
#######################################################
#设定日期
#=====================================================
#获得基本日期
gvDate_Today=`date +"%Y%m%d"`
gvDate_Today_Month=`date +"%Y%m"`
gvDate_Yesterday=`TZ=EAT+16;date +%Y%m%d`
gvDate_Yesterday_Month=`TZ=EAT+16;date +%Y%m`
gvDate_Tomorrow=`TZ=EAT-16;date +%Y%m%d`
gvDate_Tomorrow_Month=`TZ=EAT-16;date +%Y%m`

#获取本机名称
#=====================================================
gvHostName=`hostname`

#获取上月月份
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

#设定Oracle的客户端字符集
#=====================================================
export NLS_LANG="SIMPLIFIED CHINESE_CHINA.ZHS16GBK"

#设定环境变量HOME的值
#=====================================================
if [ x${HOME} = x ]
then
    HOME="/ztesoft/ocs/"
    export HOME
fi

#设定常用路径
#=====================================================
gvScriptHome="/ztesoft/ocs/scripts/"
gvSqlplus="/oracle/product/102/bin/sqlplus"

#设置Oracle链接串
#=====================================================
gvConOra_CC='cc/smart123@cc'
gvConOra_RB='rb/smart123@rb'
gvConOra_OMC='omc/smart@rb'
#设置内存数据库连接串
gvConMDB_OCS="uid=ocs;pwd=ocs123;dsn=ocs"

#各个脚本通用的存放日志路径
gvLogPath="/ztesoft/ocs/log/"

#一次性费和帐务优惠导出文件目录
gvEventChargePath="/ztesoft/ocs/data/cdrgen/DBCdrToRecurrFile/output/bak"

#设定话单备份相关路径
#=====================================================
#话单备份服务器地址
gvRemoteCdrBakHost="172.31.1.143"
gvRemoteCdrBakUser="cdradm"
gvRemoteCdrBakPasswd="cdradm321!"
#远程上传地址
gvRemoteCdrBakPath="/ftp/backupcdr/"
#本地话单存放路径
gvSrcCdrPathVarry[0]="/ztesoft/ocs/data/cdrgen/dcc/output/normal/bak/bak"
#本地备查话单备份路径
gvLocalBackPath="/ztesoft/ocs/data/CdrBackUp"
#话单备份匹配格式
gvUpCdrFormat="in6_G_*_*_${gvDate_Yesterday}??????.s"

#KPI指标相关路径
#=====================================================
#KPI存放路径
gvKpiPath="${HOME}/info/"
#KPI指标文件名称前缀
gvKpiPerf="Schedule_"

#以下几项为写入oracle的配置
#KPI结果插入表名称
gvKpiTableName="omc_event"
#KPI指标中的KPI_ID:omc.omc_event.kpi_id
gvKpiTable_KpiId="schedule"
#Kpi指标的类型:omc.omc_event.kpi_type
gvKpiTable_KpiType="03"
gvKpiTable_NeId="1"

#获取配置文件中资费版本大小
gvRuleCacheSize=`cat ${HOME}/etc/App.config | grep "MemSize" | sed 's/ //g' | cut -d = -f 2`

#通用函数库
#######################################################
#获取当前时间函数
gfGetCurrentTime()
{
    echo `date +"%Y-%m-%d %H:%M:%S"`
}

gfGetCurrentTime2()
{
    echo `date +"%Y%m%d%H%M%S"`
}

#==========================================
#生成KPI文件
#输入:
#KPI文件名称    $1
#KPI指标名称    $2
#KPI内容        $3
gfWriteKpiFile()
{
    fv_KpiFileName=${1}
    fv_KpiName=${2}
    fv_KpiContent="${3} ${4} ${5} ${6} ${7} ${8} ${9}"

    echo "${fv_KpiName}${fv_KpiContent}"
    echo "${fv_KpiName}${fv_KpiContent}" >> ${gvKpiPath}/${gvKpiPerf}${fv_KpiFileName}
}

#==========================================
#将信息写入日志
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
#获取某日的帐期ID,可能返回空
#输入:
#   $1      日期(YYYYMMDD)
#   $2      帐期类型(默认为1)
#返回:
#   $1      ID
#   $2      状态
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
#获取OMC_EVENT.EVENT_ID的表中最大值
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


#将KPI的信息写入数据库
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
#输入参数:
#$1     OMC_EVENT.DETAIL
#$2     OMC_EVENT.RESULT1
#$3     OMC_EVENT.RESULT2
#$4     OMC_EVENT.RESULT3
#注意:各个KPI间不要有空格
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
#判断用户是否在subs/subs_his表中存在
#输入参数:
#$1     不含86的用户号码
#返回参数:
#       在subs表和subs_his表中查找到的这个号码记录总和
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