#/usr/bin/ksh
#=====================================================
#   ���ӱ������µ׵����û����Ľű�
#   ����/ztesoft/ocs/scripts��
#=====================================================

#TT���ݿ�����(֮���ΪCommonENV.sh������)
#=====================================================
gvMdbDsn="ocs"
gvMdbUser="ocs4cuc"
gvMdbPasswd="ocs4cuc"

#����ļ������ļ���
#=====================================================
gvBalBackPath="/ocs/cc611/scripts/work/bak"
cd ${gvBalBackPath}

#��������ʱ��
#=====================================================
gvProcTime=`date +%Y%m%d%H%M%S`

#�趨��������Ϊ32λ��
#=====================================================
export LIBPATH="/oracle/product/102/lib32"

#��TT��Bal�������б���---�³�0�㣨����ǰ��
#=====================================================
ttBulkCp -Cnone -o -tsformat YYYYMMDDHH24MISS -connStr "uid=ocs4cuc;pwd=ocs4cuc;dsn=ocs" ocs4cuc.bal bal.txt.${gvProcTime}

#ȥ�������ļ��е�ע��
#=====================================================
sed '/^#/d' bal.txt > bal.a

#��TT��Bal�������б���---�����ʺ�
#=====================================================
ttBulkCp -Cnone -o -tsformat YYYYMMDDHH24MISS -connStr "uid=ocs4cuc;pwd=ocs4cuc;dsn=ocs" ocs4cuc.bal bal.txt.${gvProcTime}

#��������ļ����ɳ���
#=====================================================
gvOutFilePath="/ztesoft/ocs/zdl"
perl ExpUserInformation.pl -p ${gvBalBackPath} -t ${gvProcTime} -o ${gvOutFilePath}
