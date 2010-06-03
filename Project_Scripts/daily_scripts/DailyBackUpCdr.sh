#!/usr/bin/ksh
######################################################
#   备份话单脚本
#   备份策略:
#       按照话单文件名称中的日期,按月打包备份到CDR主机
#       1,原书目录只保留当天话单,
#       2,隔日将前一日话单移入对应本机备份目录备查
#       3,将大前天话单目录打包压缩后上传到143主机
#       /ztesoft/ocs/scripts/autoFtp2.pl -c -s 'U|I|cdradm|cdradm321!|172.31.1.143|/ztesoft/ocs/scripts/zdl/AppErr.txt|/ftp/backupcdr/200907/AppErr.txt'
#
#       crontab set:
#           0 4 * * * /ztesoft/ocs/scripts/DailyBackUpCdr.sh
######################################################

. /ztesoft/ocs/scripts/CommonENV.sh

updateExec="${HOME}/scripts/autoFtp2.pl -c -s "
vTarFileName="${gvHostName}_CdrBackUp_${gvDate_Yesterday_Month}.tar"
vGzipFileName="${vTarFileName}.gz"

#KPI相关
v_KpiFileName="DailyBackUpCdr_${gvDate_Today}.kpi"
v_KpiName="DailyBackUpCdr"
#初始化Kpi相关参数
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0

#######################################################
#移动昨日话单到本地备查目录
fMvTomorrowCdr()
{

    if [[ -d ${gvLocalBackPath} ]]
    then
        cd ${gvLocalBackPath}
    else
        mkdir -p ${gvLocalBackPath}
        cd ${gvLocalBackPath}
    fi

    #检查分月备份目录是否存在,不存在则建立
    v_LocalBackPathDir="${gvLocalBackPath}/${gvDate_Yesterday_Month}/${gvDate_Yesterday}/"
    if [[ ! -d ${v_LocalBackPathDir} ]]
    then
        mkdir -p ${v_LocalBackPathDir}
    fi

    if [[ -d ${gvSrcCdrPathVarry} ]]
    then
        for v_Path in ${gvSrcCdrPathVarry}
        do
            cd ${v_Path}
            #查找处理每个符合格式的文件
            for v_File in `ls -1 ${gvUpCdrFormat}`
            do
                mv ${v_File} ${v_LocalBackPathDir}
                v_KpiProcAllNum=`expr ${v_KpiProcAllNum} + 1`
            done
        done
        v_KpiContent=${v_KpiContent}"|BackUpCdrNum=${v_KpiProcAllNum}"
    else
        v_KpiContent=${v_KpiContent}"|BackUpCdrNum=Error"
    fi
}

#压缩上月的话单,会将正月目录都进行打包压缩
fCompressCdr()
{
    cd ${gvLocalBackPath}

    if [[ -f ${vTarFileName} ]]
    then
        mv ${vTarFileName} ${vTarFileName}_`gfGetCurrentTime`
    fi

    tar -cvf ${vTarFileName} ${gvDate_Yesterday_Month}
    v_KpiContent=${v_KpiContent}"|TarCdrDir=ok"

    if [[ -f ${vGzipFileName} ]]
    then
        mv ${vGzipFileName} ${vGzipFileName}_`gfGetCurrentTime`
    fi

    gzip ${vTarFileName}
    v_KpiContent=${v_KpiContent}"|GzipCdrDir=ok"

    v_KpiProcSuccesNum="ok"
}

#将压缩的文件上传到CDR服务器
fUpdatePack()
{
    if [[ -f ${vGzipFileName} ]]
    then
        ${updateExec} "U|I|${gvRemoteCdrBakUser}|${gvRemoteCdrBakPasswd}|${gvRemoteCdrBakHost}|${gvLocalBackPath}/${vGzipFileName}|${gvRemoteCdrBakPath}/${vGzipFileName}"

        v_KpiContent=${v_KpiContent}"|UpdateBackCdrPack=ok"

        v_KpiProcErrorNum="ok"
    fi
}

#删除备份话单的压缩包,删除备份目录
fDeleteLocalBackCdr()
{
    if [[ -f ${vGzipFileName} ]]
    then
        rm -f ${vGzipFileName}
        v_KpiContent=${v_KpiContent}"|RmBackCdrPack=ok"
    fi

    if [[ -d ${gvLocalBackPath}/${gvDate_Yesterday_Month} ]]
    then
        rm -rf ${gvLocalBackPath}/${gvDate_Yesterday_Month}
        v_KpiContent=${v_KpiContent}"|RmBackCdrDir=ok"
    fi
}

#######################################################
#main

#日志文件名称
v_LogFileName="DailyBackUpCdr_${gvDate_Today}.log"
#日志等级,内容....
v_LogLevel="1"
v_LogContent="开始运行每日内部话单备份..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

v_LogLevel="1"
v_LogContent="开始移动昨天话单..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
fMvTomorrowCdr

if [[ ${gvDate_Today_Month} != ${gvDate_Yesterday_Month} ]]
then
    v_LogLevel="1"
    v_LogContent="开始压缩上月话单..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
    
    fCompressCdr

    v_LogLevel="1"
    v_LogContent="开始上传上月话单..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    fUpdatePack
    
    v_LogLevel="1"
    v_LogContent="开始删除本地备份..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
    
    fDeleteLocalBackCdr
fi

#==========================================
#生成KPI文件
gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}

#写入数据库
if [[ ${gvDate_Today_Month} != ${gvDate_Yesterday_Month} ]]
then
    gfInsertKpi2Oracle "每日OCS内部话单备份完成" "共备份话单:${v_KpiProcAllNum}" "压缩话单:${v_KpiProcSuccesNum}" "上传压缩话单:${v_KpiProcErrorNum}"
else
    gfInsertKpi2Oracle "每日OCS内部话单备份完成" "共备份话单:${v_KpiProcAllNum}" "" ""
fi