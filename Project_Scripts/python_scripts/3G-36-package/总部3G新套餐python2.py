#�ۻ�������ѡ��
#   �շ��¼�����Ҫͬʱ���������ۻ�������:��36Ԫ�ײ�--���������ۼơ�/��36Ԫ�ײ�--6G�ⶥ�ۼơ�/��36Ԫ�ײ�--�շ������ۼơ�
#   ����¼�ֻ��Ҫ����һ���ۻ�������36Ԫ�ײ�--6G�ⶥ�ۼơ�
#   ��36Ԫ�ײ�--6G�ⶥ�ۼơ�/��36Ԫ�ײ�--�շ������ۼơ�--�ű�һ��ע�����ò�ͬ���ۼ�����
========================================
#��36Ԫ�ײ�--���������ۼơ�
========================================
#acm_python1--�����ۼ�--���þ�Ϊ�֣�������Ϊkb
#Ϊ������ֻ������36Ԫʱ������ʾ��Ϣ
#�������⣺
def main(r):
    v_rate = 0.0003 * 100.0    #�ۼƷ��ʵ�Ԫ����/kb��
    v_byte = round( r.event.GetAttr(MSCC_USU_BYTES).AsInteger() / 1024.0 )    #��ȡ�����Ԥ������������������ֵ��kb��
    v_EventBeginTime = r.event.GetAttr(EVENT_BEGIN_TIME).AsString()
    v_ProdCompletedDate = r.event.GetProdCompletedDate()
    #����
    if (v_EventBeginTime[:8] == v_ProdCompletedDate[:8]):
        #��������������Ӧ�üƷѷ��õĽ��֣�
        v_fee = round( v_byte * v_rate )
        #��������Ӧ���ۼ�������kb��
        res = int( round( v_fee / v_rate ) )
    else:
        res = 0
    
    r.SetResult(res)
    
========================================
#��36Ԫ�ײ�--6G�ⶥ�ۼơ�/��36Ԫ�ײ�--�շ������ۼơ�--�ű�һ��ע�����ò�ͬ���ۼ�����
========================================
#acm_python2--�������ۼ�--���þ�Ϊ�֣�������Ϊkb
#Ϊ������6G�������ⶥ
#�������⣺
def main(r):
    v_rate = 0.0003 * 100��0    #�ۼƷ��ʵ�Ԫ����/kb��
    v_byte = round( r.event.GetAttr(MSCC_USU_BYTES).AsInteger() / 1024.0 )    #��ȡ�����Ԥ������������������ֵ��kb��
    
    #��������������Ӧ�üƷѷ��õĽ��֣�
    v_fee = round( v_byte * v_rate )
    #��������Ӧ���ۼ�������kb��
    res = int( round( v_fee / v_rate ) )
    
    r.SetResult(res)

========================================
#�Ʒ�python
========================================
#�Ʒ�ʹ�õ�python--���þ�Ϊ�֣�������Ϊkb
#�ۻ��������36Ԫ�ײ�--�շ������ۼơ����ۻ�������
#ע�⣬���ڷѼ������²��ÿ�ȡ�����¿�ʼ��ȡ���ڷѣ����ǲ�����150M�������Ѿ��������ۻ�����
#��ѯʣ�������ӿ����ð����ۻ������в�ѯ���ۻ����������á�36Ԫ�ײ�--�շ������ۼơ�������
#�����ڷ����¼��������֪ͨ���š��ڶ�����
#���ô��������ۻ�������Ϊ��36Ԫ�ײ�--���������ۼơ������ﵽ��36/0.0003����ʱ����û����Ͷ��š����û���������ʹ�÷��ôﵽ36Ԫʱ�Ķ������ѡ�
#�ⶥ������ѡ���ۻ������ͣ���36Ԫ�ײ�--6G�ⶥ�ۼơ�
#��ӿ�Ʒѵ�ƷѵĹ���
def main(r):
    v_rate = 0.0003 * 100.0               #���ʣ���/kb��
    v_PackageFee = 36 * 100.0             #�ײͰ��޶����ã��֣�
    v_PackageStream = 150 * 1024.0        #�ײͰ�������������kb��
    
    v_byte = round( r.event.GetAttr(BYTES).AsInteger() / 1024.0 )    #��ȡ�����Ƕ��Ԥ����������ֵ��kb��
    print "Total byte:",v_byte
    
    #��ȡ����update��������kb��
    v_UpdateByte = round( r.event.GetAttr(UP_DATA).AsInteger() / 1024 ) + round( r.event.GetAttr(DOWN_DATA).AsInteger() / 1024 )
    print "update byte:",v_UpdateByte
    
    v_BillingCycleId = r.event.GetAttr(BILLING_CYCLE_ID).AsInteger()
    v_SubsAcmValue = r.event.GetSubsAcmValueByCycle(��36Ԫ�ײ�--�շ������ۼơ�, v_BillingCycleId)   #��ȡ�ۻ��������滻��Ӧ���ۻ������ͣ�kb��
    v_EventBeginTime = r.event.GetAttr(EVENT_BEGIN_TIME).AsString()
    v_ProdCompletedDate = r.event.GetProdCompletedDate()
    
    #���ۻ�������������(kb)����������ȡ��
    v_AllDataStream = v_byte + v_SubsAcmValue
    v_PackageFeeStream = round( v_PackageFee / v_rate )
    
    #����
    if (v_EventBeginTime[:8] == v_ProdCompletedDate[:8]):
        if (v_SubsAcmValue < v_PackageFeeStream):           #���ۻ���С��36Ԫ��������ʱ
            if ( v_AllDataStream < v_PackageFeeStream ):    #������������ʷ�ʱ
                res = round( v_UpdateByte * v_rate )
            elif( (v_AllDataStream - v_UpdateByte) < v_PackageFeeStream ):
                res = round( ( v_UpdateByte - v_AllDataStream + v_PackageFeeStream ) * v_rate )
            else:
                res = 0
        elif ( v_AllDataStream < v_PackageStream ):   #���ڵ�X1�ײͰ�������ʱ�����
            res = 0
        else:
            #�жϵ��û��ۼ������������ײͰ�����ʱ�����ۼƵ��������Ҫ�ֿ��Ʒѣ�
            if ( (v_AllDataStream - v_UpdateByte) < v_PackageStream ):
                res = round( ( v_AllDataStream - v_PackageStream ) * v_rate )
            else:
                res = round( v_UpdateByte * v_rate )    #������X1�ײͰ�����ʱ���ǰ���0.0003Ԫ/kb���
    #������
    else:
        if ( v_AllDataStream < v_PackageStream ): #���ײ͹涨�ۻ��������
            res = 0
        else:
            #�жϵ��û��ۼ������������ײͰ�����ʱ�����ۼƵ��������Ҫ�ֿ��Ʒѣ�
            if ( (v_AllDataStream - v_UpdateByte) < v_PackageStream ):
                res = round( ( v_AllDataStream - v_PackageStream ) * v_rate )
            else:
                res = round( v_UpdateByte * v_rate )    #������X1�ײͰ�����ʱ���ǰ���0.0003Ԫ/kb���
            
    r.SetResult(int(res))
