#!/usr/bin/env python
# -*- coding:utf-8 -*-

def calc(o_Stream):
    v_rate = 0.0003 * 100    #��λ����/kb��
    v_byte = round( o_Stream / 1024.0 )    #��ȡ�����Ԥ������������������ֵ����λkb��
	v_UpdateByte = round( r.event.GetAttr(MSCC_USU_BYTES).AsInteger() / 1024 )      #��ȡ����update��������kb��

    #��������������Ӧ�üƷѷ��õĽ��֣�
    v_fee = round( v_byte * v_rate )
    
    #��������Ӧ���ۼ�������kb��
    res = int( round( v_fee / v_rate ) )
    
    print "Ӧ�ۼ����� %d ��kb�� " % res
    
if (__name__=="__main__"):
    vStream = int(raw_input('��������Ҫ�������������λbyte��\n--->'))
    
    calc(vStream)