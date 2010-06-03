#/usr/bin/ksh

#Alibase数据库配置(之后改为CommonENV.sh中配置)
#=====================================================
gvABAddr="127.0.0.1"
gvABUser="ocs"
gvABPasswd="ocs"

#余额文件备份文件夹
#=====================================================
gvBalBackPath="/ztesoft/ocs/zdl"
cd ${gvBalBackPath}

#程序运行时间
#=====================================================
gvProcTime=`date +%Y%m%d%H%M%S`

#设定环境变量为32位库
#=====================================================
export LIBPATH="/oracle/product/102/lib32"

#生成导出Alibase余额表BAL的格式文件
#=====================================================
iloader formout -u ${gvABUser} -p ${gvABPasswd} -s ${gvABAddr} -T ocs.bal -f bal.fmt
sed 's/YYYY\/MM\/DD HH:MI:SS/YYYYMMDDHHMISS/g' bal.fmt > bal.fmt.${gvProcTime}
rm bal.fmt

#从Altibase中导出余额表BAL,以便之后处理和备份
#=====================================================
iloader out -u ${gvABUser} -p ${gvABPasswd} -s ${gvABAddr} -f bal.fmt.${gvProcTime} -T ocs.bal -d bal.dat.${gvProcTime} -t '|'

#调用余额文件生成程序
#=====================================================
gvOutFilePath="/ztesoft/ocs/zdl"
perl ExpUserInformation.pl -p ${gvBalBackPath} -t ${gvProcTime} -o ${gvOutFilePath}
