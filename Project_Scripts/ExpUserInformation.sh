#/usr/bin/ksh

#Alibase���ݿ�����(֮���ΪCommonENV.sh������)
#=====================================================
gvABAddr="127.0.0.1"
gvABUser="ocs"
gvABPasswd="ocs"

#����ļ������ļ���
#=====================================================
gvBalBackPath="/ztesoft/ocs/zdl"
cd ${gvBalBackPath}

#��������ʱ��
#=====================================================
gvProcTime=`date +%Y%m%d%H%M%S`

#�趨��������Ϊ32λ��
#=====================================================
export LIBPATH="/oracle/product/102/lib32"

#���ɵ���Alibase����BAL�ĸ�ʽ�ļ�
#=====================================================
iloader formout -u ${gvABUser} -p ${gvABPasswd} -s ${gvABAddr} -T ocs.bal -f bal.fmt
sed 's/YYYY\/MM\/DD HH:MI:SS/YYYYMMDDHHMISS/g' bal.fmt > bal.fmt.${gvProcTime}
rm bal.fmt

#��Altibase�е�������BAL,�Ա�֮����ͱ���
#=====================================================
iloader out -u ${gvABUser} -p ${gvABPasswd} -s ${gvABAddr} -f bal.fmt.${gvProcTime} -T ocs.bal -d bal.dat.${gvProcTime} -t '|'

#��������ļ����ɳ���
#=====================================================
gvOutFilePath="/ztesoft/ocs/zdl"
perl ExpUserInformation.pl -p ${gvBalBackPath} -t ${gvProcTime} -o ${gvOutFilePath}
