����ǰ��:
select * from omc_kpi where kpi_id = 'schedule'
select * from omc_kpi_type where kpi_type = '03'
��һ��������������Ƿ���OMC��������,���û�����ֳ�����OMC����Ա���,������ӿ�����ѯ���ҿ�


1,CommonENV.sh��ͨ�õı����ͺ�������,�����������ݿ���û���������,���ֳ��޸�
2,����ÿ�����̶�����crontable,���Բο�ͷ����ע��
3,PorcessDailyRecurrEvent.sh--ÿ�����⴦��ű�
4,PorcessFirstRecurrEvent.sh--ÿ�������⴦��ű�
5,RefreshRuleCache.sh--ÿ�ս���ˢ�½ű�,����CommonENV.sh��ˢ����Ҫ���µĽű�
6,����ͣ,˫ͣ��job����ʱ�䶼�������賿3��
