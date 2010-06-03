#!/usr/bin/env python
# -*- coding:utf-8 -*-

_DEBUG=False

def calc(oIsFirstMonth,oUpdateStream,oStream,oAcmStream):
    v_rate = 0.0003 * 100.0                     #��λ����/kb��
    v_PackageFee = 36 * 100.0                  #�ײͰ��޶����ã��֣�
    v_PackageStream = 150 * 1024.0        #�ײͰ�������������kb��
    
    v_byte = round(oStream / 1024.0)                #��ȡ�����Ƕ��Ԥ����������ֵ��kb��
    #v_UpdateByte = round(oUpdateStream / 1024.0)    #��ȡ������update������(kb)
    v_UpdateByte = v_byte
    v_SubsAcmValue = oAcmStream                     #��ȡ�ۻ��������滻��Ӧ���ۻ������ͣ�kb��
    
    #���ۻ�������������(kb)����������ȡ��
    v_AllDataStream = v_byte + v_SubsAcmValue
    v_PackageFeeStream = round( v_PackageFee / v_rate )
    
    if _DEBUG == True:
        import pdb
        pdb.set_trace()
    
    #����
    if (oIsFirstMonth == '1'):
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
            
    print "============���==================="
    print "�û���ʹ��������=",v_AllDataStream
    if (oIsFirstMonth == '1') and ( v_AllDataStream > v_PackageStream ) and ( v_SubsAcmValue < v_PackageStream ):
        print "�û���Ʒ�����= %d" % (v_AllDataStream - v_PackageStream)
    elif( v_AllDataStream > v_PackageStream ) and  ( v_SubsAcmValue < v_PackageStream ):
        print "�û���Ʒ�����= %d" % (v_AllDataStream - v_PackageStream)
    
    print "Ӧ��ȡ���ã�%d���֣� " % int(res)
    
if (__name__=="__main__"):
    vIsFirstMonth = raw_input('��ѡ���Ƿ����£�1-���£�0-�����£�\n--->')
    vUpdateStream = int(raw_input('�����뱾�λỰ����������λbyte��\n--->'))
    vStream = int(raw_input('�����뱾��UPDATE����������λbyte��\n--->'))
    vAcmStream = int(raw_input('�������û������ۻ�������λkb��\n--->'))
    
    calc(vIsFirstMonth,vUpdateStream,vStream,vAcmStream)