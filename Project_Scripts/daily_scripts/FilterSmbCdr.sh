#!/usr/bin/ksh
######################################################
#
#       ���˶������ػ����еķ�OCS�û�,����������ز����ļ�
#       �ű�ִ�к�Ϊ����ѭ��ִ��,���ڽű�������ͣ��ʱ����
#
#######################################################

. /ztesoft/ocs/scripts/CommonENV.sh

#�������ش���·������
#=====================================================
#�������ز����·��
vSmbSrcPath="/ztesoft/ocs/scripts/backcdr/src"
#�������ر��ݻ���·��
vSmbBakPath="/ztesoft/ocs/scripts/backcdr"
#�������ػ���������ʱ·��,�������ʱ�ļ�����������Ŀ¼
vSmbWorkPath="/ztesoft/ocs/scripts/backcdr/tmp"
#�������ش���󻰵����·��
vSmbOutputPath="/ztesoft/ocs/scripts/backcdr/out"

#ͣ��ʱ����,��λΪ��
vSleepTime=10

#��������ʱ�ļ�,���а���������ļ�����,�����ڶ���������Ϣ,
#��������֮ǰ�ȼ���Ƿ�������ļ�,���������Ŵ���
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
#�ַ����Ȳ���,��0���Ҳಹ�㳤��
#����:
#   $1      ��Ҫ��������ַ���
#   $2      ��Ҫ�������λ
#���:
#   $1      �������ַ���
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
#ȥ���ַ����Ҳಹ���0,������0��ֹͣ
#�ж�ʱ����ַ���ȫ����0,�򲻽��в�ȥ0
#����:
#   $1      ��Ҫȥ��0���ַ���
#���:
#   $1      ȥ��0����ַ���
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
#��������ͷ
#����:
#   $1      �����ļ�ͷ
#���:
#   $1      ��������
#   $2      �ļ��汾��
#   $3      �ļ�����ʱ��
#   $4      �ܼ�¼��
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
#��������
#����:
#   $1      һ����������
#����:
#   $1      ���ű�־
#   $2      �Ʒ��û�����(ע�����ǰ��86,������0�Ҳ���21λ)
#   $3      ����ϢID
fParseCdrRows()
{
    fv_str=${1}

    fv_netFlag=`echo ${fv_str} | cut -c 1-21`
    fv_misdn=`echo ${fv_str} | cut -c 22-42`
    fv_msgid=`echo ${fv_str} | cut -c 43-`

    echo ${fv_netFlag} ${fv_misdn} ${fv_msgid}
}

#==========================================
#����һ���ļ�
#����:
#   $1      �ļ�����
fProcOneFile()
{
    fv_FileName=${1}

    #�����Ĵ�������,��Ϊ������ͷ,�ʵ�0��Ϊͷ
    fv_RowsNumber=0

    #�����ļ��Ļ�������
    fv_HeadFileCount=0

    #�ļ��л���������,�����ļ�ͷ
    fv_AllFileCount=0

    #��¼�ļ������ݵ���ʱ�ļ�
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

    #У���ļ��������뻰��ͷ�б�ʶ�Ƿ�һ��
    fv_AllFileCount=`expr ${fv_AllFileCount} - 1`
    if (( ${fv_AllFileCount} != ${fv_HeadFileCount} ))
    then
        v_LogLevel="3"
        v_LogContent="�ļ�[${fv_FileName}]ͷ�б�ʶ�Ļ���������ʵ�ʲ���!"
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
        v_LogContent="����ͷ�л�������Ϊ:[${fv_HeadFileCount}]"
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
        v_LogContent="ʵ���ļ��л�������Ϊ:[${fv_AllFileCount}]"
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
    fi

    fAddRightZero ${fv_RowsNumber} "12" | read fv_HeadFileCount

    #��ɸѡ������OCS�������´��Ϊ�������ز����ļ�
    echo "${vHeadNetType}${vHeadFileVersion}${vHeadFileTime}${fv_HeadFileCount}" > ${fv_TmpFileName}

    while read v_outRows
    do
        echo ${v_outRows} >> ${fv_TmpFileName}
    done < ${vTmpCdrFile}

    #��ԭʼ�ļ����ݵ�����Ŀ¼
    mv ${fv_FileName} "${vSmbBakPath}/."

    #�����´����Ķ��������ļ��������Ŀ¼,ͬʱɾ����ʱ�ļ�����ʱ��Ϣ�ļ�
    mv ${fv_TmpFileName} "${vSmbOutputPath}/${fv_FileName}"
    rm -f ${vTmpInfoFile}
    rm -f ${vTmpCdrFile}
}

#######################################################
#main

#��־�ļ�����
v_LogFileName="FilterSmbCdr_${gvDate_Today}.log"
#��־�ȼ�,����....
v_LogLevel="1"
v_LogContent="��ʼ���ж������ز�������˳���..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

if [[ -d ${vSmbWorkPath} ]]
then
    cd ${vSmbWorkPath}
else
    mkdir ${vSmbWorkPath}
    cd ${vSmbWorkPath}
    v_LogLevel="1"
    v_LogContent="������Ŀ¼\[${${vSmbWorkPath}}\]������,�Ѿ�����"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
fi

#�쳣�жϺ�������
#��һ��������ʱ��,���������ʱ��Ϣ�ļ�
if [[ -f ${vTmpInfoFile} ]]
then
    v_LogLevel="3"
    v_LogContent="�����ϴδ������쳣�˳�,�������´���..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    fv_LastFile=`cat ${vTmpInfoFile} | cut -d '|' -f 1`

    rm -f ${vTmpInfoFile}
    rm -f ${vTmpCdrFile}

    v_LogLevel="3"
    v_LogContent="��ʼ�����ϴ�δ��������ļ�:[${fv_LastFile}]"
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    fProcOneFile ${fv_LastFile}
fi

#������������
while true
do
    #��ȡ�ļ��б�
    for v_FilePath in `ls -1 ${vSmbSrcPath}`
    do
        v_LogLevel="3"
        v_LogContent="��ʼ�����ļ�:${v_FilePath}..."
        gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

        #����Ҫ������ļ��ƶ�������Ŀ¼
        mv "${vSmbSrcPath}/${v_FilePath}" "${vSmbWorkPath}/."

        fProcOneFile ${v_FilePath}
    done
    v_LogLevel="3"
    v_LogContent="Sleeping [${vSleepTime}] second ..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
    sleep ${vSleepTime}
done
