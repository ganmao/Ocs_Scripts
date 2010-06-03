#!/usr/bin/env python
# -*- coding:utf-8 -*-

def calc(o_Stream):
    v_rate = 0.0003 * 100    #单位（分/kb）
    v_byte = round( o_Stream / 1024.0 )    #获取到多次预留的四舍五入总流量值（单位kb）
	v_UpdateByte = round( r.event.GetAttr(MSCC_USU_BYTES).AsInteger() / 1024 )      #获取本次update的流量（kb）

    #四舍五入计算出来应该计费费用的金额（分）
    v_fee = round( v_byte * v_rate )
    
    #四舍五入应该累计流量（kb）
    res = int( round( v_fee / v_rate ) )
    
    print "应累计流量 %d （kb） " % res
    
if (__name__=="__main__"):
    vStream = int(raw_input('请输入需要计算的流量（单位byte）\n--->'))
    
    calc(vStream)