#!/usr/bin/ksh
######################################################
#   ���ݻ����ű�
#   ���ݲ���:
#       ���ջ����ļ������е�����,���´�����ݵ�CDR����
#       1,ԭ��Ŀ¼ֻ�������컰��,
#       2,���ս�ǰһ�ջ��������Ӧ��������Ŀ¼����
#       3,����ǰ�컰��Ŀ¼���ѹ�����ϴ���143����
#       /ztesoft/ocs/scripts/autoFtp2.pl -c -s 'U|I|cdradm|cdradm321!|172.31.1.143|/ztesoft/ocs/scripts/zdl/AppErr.txt|/ftp/backupcdr/200907/AppErr.txt'
#
#       crontab set:
#           0 4 * * * /ztesoft/ocs/scripts/DailyBackUpCdr.sh
######################################################

. /ztesoft/ocs/scripts/CommonENV.sh

updateExec="${HOME}/scripts/autoFtp2.pl -c -s "
vTarFileName="${gvHostName}_CdrBackUp_${gvDate_Yesterday_Month}.tar"
vGzipFileName="${vTarFileName}.gz"

#KPI���
v_KpiFileName="DailyBackUpCdr_${gvDate_Today}.kpi"
v_KpiName="DailyBackUpCdr"
#��ʼ��Kpi��ز���
v_KpiContent=""
v_KpiProcAllNum=0
v_KpiProcErrorNum=0
v_KpiProcSuccesNum=0

#######################################################
#�ƶ����ջ��������ر���Ŀ¼
fMvTomorrowCdr()
{

    if [[ -d ${gvLocalBackPath} ]]
    then
        cd ${gvLocalBackPath}
    else
        mkdir -p ${gvLocalBackPath}
        cd ${gvLocalBackPath}
    fi

    #�����±���Ŀ¼�Ƿ����,����������
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
            #���Ҵ���ÿ�����ϸ�ʽ���ļ�
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

#ѹ�����µĻ���,�Ὣ����Ŀ¼�����д��ѹ��
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

#��ѹ�����ļ��ϴ���CDR������
fUpdatePack()
{
    if [[ -f ${vGzipFileName} ]]
    then
        ${updateExec} "U|I|${gvRemoteCdrBakUser}|${gvRemoteCdrBakPasswd}|${gvRemoteCdrBakHost}|${gvLocalBackPath}/${vGzipFileName}|${gvRemoteCdrBakPath}/${vGzipFileName}"

        v_KpiContent=${v_KpiContent}"|UpdateBackCdrPack=ok"

        v_KpiProcErrorNum="ok"
    fi
}

#ɾ�����ݻ�����ѹ����,ɾ������Ŀ¼
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

#��־�ļ�����
v_LogFileName="DailyBackUpCdr_${gvDate_Today}.log"
#��־�ȼ�,����....
v_LogLevel="1"
v_LogContent="��ʼ����ÿ���ڲ���������..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

v_LogLevel="1"
v_LogContent="��ʼ�ƶ����컰��..."
gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
fMvTomorrowCdr

if [[ ${gvDate_Today_Month} != ${gvDate_Yesterday_Month} ]]
then
    v_LogLevel="1"
    v_LogContent="��ʼѹ�����»���..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
    
    fCompressCdr

    v_LogLevel="1"
    v_LogContent="��ʼ�ϴ����»���..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}

    fUpdatePack
    
    v_LogLevel="1"
    v_LogContent="��ʼɾ�����ر���..."
    gfWriteLogFile ${v_LogFileName} ${v_LogLevel} ${v_LogContent}
    
    fDeleteLocalBackCdr
fi

#==========================================
#����KPI�ļ�
gfWriteKpiFile ${v_KpiFileName} ${v_KpiName} ${v_KpiContent}

#д�����ݿ�
if [[ ${gvDate_Today_Month} != ${gvDate_Yesterday_Month} ]]
then
    gfInsertKpi2Oracle "ÿ��OCS�ڲ������������" "�����ݻ���:${v_KpiProcAllNum}" "ѹ������:${v_KpiProcSuccesNum}" "�ϴ�ѹ������:${v_KpiProcErrorNum}"
else
    gfInsertKpi2Oracle "ÿ��OCS�ڲ������������" "�����ݻ���:${v_KpiProcAllNum}" "" ""
fi