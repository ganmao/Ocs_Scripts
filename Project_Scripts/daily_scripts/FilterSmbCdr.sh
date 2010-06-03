#!/usr/bin/ksh
######################################################
#
#       过滤短信网关话单中的非OCS用户,重组短信网关补款文件
#       脚本执行后为无限循环执行,请在脚本中设置停顿时间间隔
#
#######################################################

. /ztesoft/ocs/scripts/CommonENV.sh

#短信网关处理路径配置
#=====================================================
#短信网关补款话单路径
vSmbSrcPath="/ztesoft/ocs/scripts/backcdr/src"
#短信网关备份话单路径
vSmbBakPath="/ztesoft/ocs/scripts/backcdr"
#短信网关话单处理临时路径,处理的临时文件都会放在这个目录
vSmbWorkPath="/ztesoft/ocs/scripts/backcdr/tmp"
#短信网关处理后话单输出路径
vSmbOutputPath="/ztesoft/ocs/scripts/backcdr/out"

#停顿时间间隔,单位为秒
vSleepTime=10

#建立的临时文件,其中包含处理的文件名称,处理到第多少条的信息,
#程序运行之前先检查是否有这个文件,如果有则接着处理
vTmpInfoFile="${vSmbWorkPath}/FileterSmbCdr_TmpInfoFile.txt"
vTmpCdrFile="${vSmbWorkPath}/FileterSmbCdr_TmpCdr.txt"

#=====================================================
vHeadNetType="G"
vHeadFileVersion="00"
vHeadFileTime=`gfGetCurrentTime2`
vHeadFileCount=0

vCdrNetBridge=0
vCdrMisdn=0
vCdrMsgId=0

#==========================================
#字符长度不足,以0在右侧补足长度
#输入:
#   $1      需要补足足的字符串
#   $2      需要补足多少位
#输出:
#   $1      不足后的字符串
fAddRightZero()
{
    fv_str=${1}
    fv_Length=${2}

    fv_strLength=`expr length ${fv_str}`
    if (( ${fv_strLength} < ${fv_Length} ))
    then
        fv_diffLength=`expr ${fv_Length} - ${fv_strLength}`
        while (( ${fv_diffLength} > 0 ))
        do
            fv_str="0"${fv_str}
            fv_diffLength=`expr ${fv_diffLength} - 1`
        done
    fi

    echo ${fv_str}
}

#==========================================
#去掉字符串右侧补足的0,遇到非0则停止
#判断时如果字符串全部是0,则不进行不去0
#输入:
#   $1      需要去掉0的字符串
#输出:
#   $1      去掉0后的字符串
fTrimRightZero()
{
    fv_str=${1}

    fv_strLength=`expr length ${fv_str}`
    fv_RegxResult=`echo ${fv_str} | grep "0\{${fv_strLength}\}" | wc -l`

    if (( ${fv_RegxResult} == 0 ))
    then
        while (( ${fv_strLength} > 0 ))
        do
            fv_RigthChar=`echo ${fv_str} | cut -c 1`
            if [[ ${fv_RigthChar} = "0" ]]
            then
                fv_str=`echo ${fv_str} | cut -c 2-`
            fi
            fv_strLength=`expr ${fv_strLength} - 1`
        done
    fi

    echo ${fv_str}
}

#==========================================
#解析话单头
#输入:
#   $1      话单文件头
#输出:
#   $1      网络类型
#   $2      文件版本号
#   $3      文件产生时间
#   $4      总记录数
fParseCdrHead()
{
    fv_headStr=${1}

    fv_NetType=`echo ${fv_headStr} | cut -c 1`
    fv_Version=`echo ${fv_headStr} | cut -c 2-3`
    fv_FileTIme=`echo ${fv_headStr} | cut -c 4-17`
    fv_Counts=`echo ${fv_headStr} | cut -c 18-`

    echo ${fv_NetType} ${fv_Version} ${fv_FileTIme} ${fv_Counts}
}

#==========================================
#解析话单
#输入:
#   $1      一条话单内容
#返回:
#   $1      网桥标志
#   $2      计费用户号码(注意号码前带86,并且以0右补足21位)
#   $3      短消息ID
fParseCdrRows()
{
    fv_str=${1}

    fv_netFlag=`echo ${fv_str} | cut -c 1-21`
    fv_misdn=`echo ${fv_str} | cut -c 22-42`
    fv_msgid=`echo ${fv_str} | cut -c 43-`

    echo ${fv_netFlag} ${fv_misdn} ${fv_msgid}
}

#==========================================
#处理一个文件
#输入:
#   $1      文件名称
fProcOneFile()
{
    fv_FileName=${1}

    #话单的处理行数,因为话单有头,故第0行为头
    fv_RowsNumber=0

    #重组文件的话单条数
    fv_HeadFileCount=0

    #文件中话单总条数,不含文件头
    fv_AllFileCount=0

    #记录文件体内容的临时文件
    fv_TmpFileName="p_${fv_FileName}"
    echo "" > ${fv_TmpFileName}

    while read fv_rows
    do
        echo "${fv_FileName}|${fv_AllFileCount}" > ${vTmpInfoFile}
        if (( ${fv_AllFileCount} == 0 ))
        then
            fParseCdrHead ${fv_rows} | read vHeadNetType vHeadFileVersion vHeadFileTime vHeadFileCount

            fTrimRightZero ${vHeadFileCount} | read fv_HeadFileCount

            fv_AllFileCount=`expr ${fv_AllFileCount} + 1`
        elif (( ${fv_AllFileCount} > 0 ))
        then
            fParseCdrRows ${fv_rows} | read vCdrNetBridge vCdrMisdn vCdrMsgId

            fTrimRightZero ${vCdrMisdn} | read fv_CdrMisdn

            fv_CdrMisdnPer=`echo ${fv_CdrMisdn} | cut -c 1-2`
            if [[ ${fv_CdrMisdnPer} = "86" ]]
            then
                gfJudgeIfOcsUser `echo ${fv_CdrMisdn} | cut -c 3-` | read fv_UserCount
                if (( ${fv_UserCount} > 0 ))
                then
                    echo ${fv_rows} >> ${vTmpCdrFile}
                    fv_RowsNumber=`expr ${fv_RowsNumber} + 1`
                fi
            fi

            fv_AllFileCount=`expr ${fv_AllFileCount} + 1`
        fi
    done < ${fv_FileName}

    #校验文件话单数与话单头中标识是否一致
    fv_AllFileCount=`expr ${fv_AllFileCount} - 1`
    if (( ${fv_AllFileCount} != ${fv_HeadFileCount} ))
    then
        v_LogLevel="3"
        v_LogContent="文件[${fv_FileName}]头中标识的话单条数与实际不符!"
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
        v_LogContent="话单头中话单条数为:[${fv_HeadFileCount}]"
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
        v_LogContent="实际文件中话单条数为:[${fv_AllFileCount}]"
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
    fi

    fAddRightZero ${fv_RowsNumber} "12" | read fv_HeadFileCount

    #将筛选出来的OCS话单重新打包为短信网关补款文件
    echo "${vHeadNetType}${vHeadFileVersion}${vHeadFileTime}${fv_HeadFileCount}" > ${fv_TmpFileName}

    while read v_outRows
    do
        echo ${v_outRows} >> ${fv_TmpFileName}
    done < ${vTmpCdrFile}

    #将原始文件备份到备份目录
    mv ${fv_FileName} "${vSmbBakPath}/."

    #将重新打包后的短信网关文件放入输出目录,同时删除临时文件和临时信息文件
    mv ${fv_TmpFileName} "${vSmbOutputPath}/${fv_FileName}"
    rm -f ${vTmpInfoFile}
    rm -f ${vTmpCdrFile}
}

#######################################################
#main

#日志文件名称
v_LogFileName="FilterSmbCdr_${gvDate_Today}.log"
#日志等级,内容....
v_LogLevel="1"
v_LogContent="开始运行短信网关补款话单过滤程序..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

if [[ -d ${vSmbWorkPath} ]]
then
    cd ${vSmbWorkPath}
else
    mkdir ${vSmbWorkPath}
    cd ${vSmbWorkPath}
    v_LogLevel="1"
    v_LogContent="程序工作目录\[${${vSmbWorkPath}}\]不存在,已经创建"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
fi

#异常中断后处理流程
#第一次启动的时候,如果存在临时信息文件
if [[ -f ${vTmpInfoFile} ]]
then
    v_LogLevel="3"
    v_LogContent="存在上次处理中异常退出,正在重新处理..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    fv_LastFile=`cat ${vTmpInfoFile} | cut -d '|' -f 1`

    rm -f ${vTmpInfoFile}
    rm -f ${vTmpCdrFile}

    v_LogLevel="3"
    v_LogContent="开始处理上次未处理完的文件:[${fv_LastFile}]"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    fProcOneFile ${fv_LastFile}
fi

#正常处理流程
while true
do
    #获取文件列表
    for v_FilePath in `ls -1 ${vSmbSrcPath}`
    do
        v_LogLevel="3"
        v_LogContent="开始处理文件:${v_FilePath}..."
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

        #将需要处理的文件移动到工作目录
        mv "${vSmbSrcPath}/${v_FilePath}" "${vSmbWorkPath}/."

        fProcOneFile ${v_FilePath}
    done
    v_LogLevel="3"
    v_LogContent="Sleeping [${vSleepTime}] second ..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
    sleep ${vSleepTime}
done
