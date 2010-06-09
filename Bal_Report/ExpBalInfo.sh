#!/usr/bin/ksh
#=====================================================
#    月底导出用户余额平衡报表
#    放在/ztesoft/ocs/scripts下
#    ExpBalInfo.sh
#=====================================================

#内存数据库配置
#-----------------------------------------------------
gvMdbType="TT"      #TT/AB
gvMdbDsn="ocs"
gvMdbUser="ocs4cuc"
gvMdbPasswd="ocs4cuc"

#ttisql "uid=ocs4cuc;pwd=ocs4cuc;dsn=ocs"
#isql -u ocs -p ocs -s 127.0.0.1

#ORACLE数据库配置
#-----------------------------------------------------
gvOraDsn="trb"
gvOraUser="rb611"
gvOraPasswd="smart"

#内存库BAL表数据导出文件夹
#-----------------------------------------------------
gvBalBackPath="/ocs/cc611/scripts/rep/balbak"

#余额报表输出目录
#-----------------------------------------------------
gvOutReportPath="/ocs/cc611/scripts/rep/repout"

#=====================================================
#全局变量
gvBalFile=""
export NLS_LANG="SIMPLIFIED CHINESE_AMERICA.AL32UTF8"

#=====================================================
#调用函数

#使用帮助函数
#-----------------------------------------------------
Usage()
{
echo "=========================================="
echo "
ExpBalInfo.sh -ExpBal2Ora
    将内存库中BAL数据导出,且存入Oracle RB中BALRP_BAL_xxx
    请放入crontab中定时执行:
    0 0 * * * /ztesoft/ocs/scripts ExpBalInfo.sh -ExpBal2Ora

ExpBalInfo.sh -rep [月初余额信息表] [月末余额信息表]
    生成报表数据到指定目录

"
echo "=========================================="

exit
}

getProcTime()
{
    echo `date +%Y%m%d%H%M%S`
}

#打印日志记录（注意，参数内容请不要含有空格）
#-----------------------------------------------------
#$1     日志等级
#$2     调用日志函数
#$3     日志内容
pLog()
{
    _LogLevel=$1
    _LogFun=$2
    _LogTxt=$3
    getProcTime | read _ProcTime
    
    echo "${_ProcTime}|LOG_${_LogLevel}|${_LogFun}|${_LogTxt}"
}

#导出BAL表信息到文件，以便备份和导入ORACLE
#-----------------------------------------------------
#$1     内存库类型
#$2     bal信息备份的路径
ExpBalData()
{
    _MdbType=$1
    _BalBackPath=$2
    getProcTime | read _myProcTime
    gvBalFile=balrp_bal_${_myProcTime}
    
    if [[ ${_MdbType} = "TT" ]]; then
        pLog 1 "ExpBalData" "开始从TT数据库导出BAL表信息。。。"
        
        #从TimesTen中导出余额表BAL,以便之后处理和备份
        ttBulkCp -Cnone -o -tsformat YYYYMMDDHH24MISS -connStr "uid=${gvMdbUser};pwd=${gvMdbPasswd};dsn=${gvMdbDsn}" ${gvMdbUser}.bal ${_BalBackPath}/${gvBalFile} | read _BackBalInfo
        sed '/^#/d' ${_BalBackPath}/${gvBalFile} > ${_BalBackPath}/${gvBalFile}.out
        rm ${_BalBackPath}/${gvBalFile}
        
        pLog 3 "ExpBalData" "导出BAL表数据:${_BalBackPath}/${gvBalFile}.out|${_BackBalInfo}"
        
    elif [[ ${_MdbType} = "AB" ]]; then
        pLog 1 "ExpBalData" "开始从AB数据库导出BAL表信息。。。"
        
        ##生成导出Alibase余额表BAL的格式文件
        #iloader formout -u ${gvMdbUser} -p ${gvMdbPasswd} -s ${gvMdbDsn} -T ${gvMdbUser}.bal -f ${_BalBackPath}/bal.fmt
        #sed 's/YYYY\/MM\/DD HH:MI:SS/YYYYMMDDHHMISS/g' ${_BalBackPath}/bal.fmt > ${_BalBackPath}/${gvMdbUser}.fmt
        #rm ${_BalBackPath}/bal.fmt
        #
        ##从Altibase中导出余额表BAL,以便之后处理和备份
        #iloader out -u ${gvMdbUser} -p ${gvMdbPasswd} -s ${gvMdbDsn} -f ${gvMdbUser}.fmt -T ${gvMdbUser}.bal -d ${_BalBackPath}/${gvBalFile}.out -t ','
        
        pLog 3 "ExpBalData" "导出BAL表数据:${_BalBackPath}/${gvBalFile}.out"
    fi
}

#生成导入Oracle的控制文件
#-----------------------------------------------------
#$1     表名
#放入Oracle的表名与导出文件去掉后缀名的一致
WriteCtl()
{
    _FilePath=$1
    _TableName=$2
    _FileName=${_TableName}".out"
    _CtlName=${_TableName}".ctl"
    
    echo "load data
infile ${_FileName}
into table ${_TableName}
truncate
fields terminated by ','
trailing nullcols
(
    BAL_ID,
    ACCT_ID,
    ACCT_RES_ID,
    GROSS_BAL,
    RESERVE_BAL,
    CONSUME_BAL,
    RATING_BAL,
    BILLING_BAL,
    EFF_DATE \"TO_DATE(:EFF_DATE,'YYYYMMDDHH24MISS')\", 
    EXP_DATE \"DECODE(:EXP_DATE,'NULL',TO_DATE('2099-12-30','YYYY-MM-DD'),TO_DATE(:EXP_DATE,'YYYYMMDDHH24MISS'))\",
    UPDATE_DATE \"TO_DATE(:UPDATE_DATE,'YYYYMMDDHH24MISS')\",
    CEIL_LIMIT \"DECODE(:CEIL_LIMIT, 'NULL', NULL, :CEIL_LIMIT)\",
    FLOOR_LIMIT \"DECODE(:CEIL_LIMIT, 'NULL', NULL, :FLOOR_LIMIT)\",
    DAILY_CEIL_LIMIT \"DECODE(:CEIL_LIMIT, 'NULL', NULL, :DAILY_CEIL_LIMIT)\",
    DAILY_FLOOR_LIMIT \"DECODE(:CEIL_LIMIT, 'NULL', NULL, :DAILY_FLOOR_LIMIT)\",
    PRIORITY \"DECODE(:CEIL_LIMIT, 'NULL', NULL, :PRIORITY)\",
    LAST_BAL \"DECODE(:CEIL_LIMIT, 'NULL', NULL, :LAST_BAL)\",
    LAST_RECHARGE \"DECODE(:CEIL_LIMIT, 'NULL', NULL, :LAST_RECHARGE)\",
    BAL_CODE \"DECODE(:CEIL_LIMIT, 'NULL', NULL, :BAL_CODE)\"
)" > ${_FilePath}/${_CtlName}

    echo ${_CtlName}
}

#生成导入Oracle的BAL建表脚本
#-----------------------------------------------------
#$1     表名
WriteCreateSql()
{
    _FilePath=$1
    _TableName=$2
    _SqlFileName=${_TableName}".sql"
    
    echo "CREATE TABLE ${_TableName}(
    BAL_ID          NUMBER(12) not null,
    ACCT_ID         NUMBER(9) not null,
    ACCT_RES_ID     NUMBER(9) not null,
    GROSS_BAL       NUMBER(12),
    RESERVE_BAL     NUMBER(12),
    CONSUME_BAL     NUMBER(12),
    RATING_BAL      NUMBER(12),
    BILLING_BAL     NUMBER(12),
    EFF_DATE        date,
    EXP_DATE        date,
    UPDATE_DATE     date,
    CEIL_LIMIT      NUMBER(12),
    FLOOR_LIMIT     NUMBER(12),
    DAILY_CEIL_LIMIT   NUMBER(12),
    DAILY_FLOOR_LIMIT  NUMBER(12),
    PRIORITY           NUMBER(9),
    LAST_BAL           NUMBER(12),
    LAST_RECHARGE      NUMBER(12),
    BAL_CODE           NUMBER(12)
) tablespace TAB_RB;
--CREATE INDEX IDX${_TableName} ON ${_TableName}(ACCT_ID) tablespace IDX_RB;
" > ${_FilePath}/${_SqlFileName}

    echo ${_SqlFileName}
}

#执行Oracle sql文件
#-----------------------------------------------------
#$1     Sql文件
ProcOraSql()
{
    _SqlFile=$1
    
    sqlplus -S ${gvOraUser}/${gvOraPasswd}@${gvOraDsn} << END
    set heading off
    set feedback off
    set pagesize 0
    
    set serveroutput on size unlimited
    
    ${_SqlFile}
    
    exit;
END
}

#将BAL表信息导入ORACLE
#-----------------------------------------------------
#$1     BAL信息存放路径
#$2     BAL信息文件名称
#放入Oracle的表名与导出文件去掉后缀名的一致
LoadBal2Ora()
{
    _BalFilePath=$1
    _BalTabName=$2
    _BalFile=${_BalTabName}".out"
    
    cd ${_BalFilePath}
    
    pLog 3 "LoadBal2Ora" "准备导入文件：${_BalFilePath}/${_BalFile}"
    
    WriteCreateSql ${_BalFilePath} ${_BalTabName} | read _mySqlFile
    pLog 3 "LoadBal2Ora" "生成Bal表创建脚本:${_mySqlFile}"
    
    WriteCtl ${_BalFilePath} ${_BalTabName} | read _myCtlName
    pLog 3 "LoadBal2Ora" "生成SqlLod控制文件:${_myCtlName}"
    
    ProcOraSql "select count(1) from user_tables where table_name = upper('${_BalTabName}');" | read _BalExist
    pLog 5 "LoadBal2Ora" "select count(1) from user_tables where table_name = upper('${_BalTabName}');"
    _BalExist=`echo ${_BalExist} | sed 's/ //'`
    pLog 5 "LoadBal2Ora" "_BalExist=[${_BalExist}]"
    if [[ ${_BalExist} = "0" ]]; then
        #创建BAL信息表
        ProcOraSql "@"${_BalFilePath}/${_mySqlFile}
        pLog 3 "LoadBal2Ora" "在Oracle中创建Bal信息表：${_BalTabName}"
    else
        pLog 3 "LoadBal2Ora" "Oracle中Bal信息表已经存在，不再创建，直接覆盖数据：${_BalTabName}"
    fi
    
    #将数据导入表中
    sqlldr userid=${gvOraUser}/${gvOraPasswd}@${gvOraDsn} silent=feedback control=${_BalFilePath}/${_BalTabName}.ctl log=${_BalFilePath}/${_BalTabName}.log bad=${_BalFilePath}/${_BalTabName}.bad
    pLog 3 "LoadBal2Ora" "将BAL信息导入Oracle中：${_BalTabName}"
}

#主函数
#-----------------------------------------------------
main()
{
    #获取报表制定省市
    ProcOraSql "SELECT balrp_pkg_for_cuc.pf_curr_province FROM dual;" | read gvProvince
    gvProvince=`echo ${gvProvince} | sed 's/ //'`
    pLog 1 "main" "报表生成省份为：【${gvProvince}】"
    
    if [[ $1 = "-ExpBal2Ora" ]]; then
        ExpBalData ${gvMdbType} ${gvBalBackPath}
        
        pLog 5 "main" "gvBalFile=${gvBalFile}"
        
        #gvBalFile="balrp_bal_20100609095950"
        if [[ -n ${gvBalFile} ]]; then
            LoadBal2Ora ${gvBalBackPath} ${gvBalFile}
            
            pLog 1 "main" "BAL信息已经入库到表：${gvBalFile}"
        else
            pLog 1 "main" "没有导出正确的BAL文件"
        fi
    elif [[ $1 = "-rep" ]]; then
        pLog 1 "main" "输入月初余额信息表：[$2]"
        pLog 1 "main" "输入月末余额信息表：[$3]"
        
        pLog 1 "main" "开始调用数据库中报表存储过程！balrp_pkg_for_cuc.pp_main()"
        
        ProcOraSql "exec balrp_pkg_for_cuc.pp_main('$2', '$3');" | read _ProcOut
        
        _ProcHead=`echo ${_ProcOut} | cut -c 1-5`
        
        if [[ ${_ProcHead} = "BEGIN" ]]; then
            pLog 1 "main" "存储过程[balrp_pkg_for_cuc.pp_main]编译存在问题！"
            pLog 1 "main" "exec balrp_pkg_for_cuc.pp_main('$2', '$3');"
            pLog 3 "main" "_ProcOut=[${_ProcOut}]"
        else
            pLog 1 "main" "exec balrp_pkg_for_cuc.pp_main('$2', '$3');"
            pLog 3 "main" "${_ProcOut}"
        fi
    else
        pLog 1 "main" "输入参数不正确！"
        Usage
    fi
}

main $1 $2 $3
