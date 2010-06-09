#/usr/bin/ksh
#=====================================================
#   给河北用来月底导出用户余额的脚本
#   放在/ztesoft/ocs/scripts下
#=====================================================

#TT数据库配置(之后改为CommonENV.sh中配置)
#=====================================================
gvMdbDsn="ocs"
gvMdbUser="ocs4cuc"
gvMdbPasswd="ocs4cuc"

#余额文件备份文件夹
#=====================================================
gvBalBackPath="/ocs/cc611/scripts/work/bak"
cd ${gvBalBackPath}

#程序运行时间
#=====================================================
gvProcTime=`date +%Y%m%d%H%M%S`

#设定环境变量为32位库
#=====================================================
export LIBPATH="/oracle/product/102/lib32"

#将TT中Bal表导出进行备份---月初0点（出帐前）
#=====================================================
ttBulkCp -Cnone -o -tsformat YYYYMMDDHH24MISS -connStr "uid=ocs4cuc;pwd=ocs4cuc;dsn=ocs" ocs4cuc.bal bal.txt.${gvProcTime}

#去除导出文件中的注释
#=====================================================
sed '/^#/d' bal.txt > bal.a

#将TT中Bal表导出进行备份---（出帐后）
#=====================================================
ttBulkCp -Cnone -o -tsformat YYYYMMDDHH24MISS -connStr "uid=ocs4cuc;pwd=ocs4cuc;dsn=ocs" ocs4cuc.bal bal.txt.${gvProcTime}

#调用余额文件生成程序
#=====================================================
gvOutFilePath="/ztesoft/ocs/zdl"
perl ExpUserInformation.pl -p ${gvBalBackPath} -t ${gvProcTime} -o ${gvOutFilePath}
