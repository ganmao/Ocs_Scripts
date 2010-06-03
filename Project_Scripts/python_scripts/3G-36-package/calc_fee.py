#!/usr/bin/env python
# -*- coding:utf-8 -*-

_DEBUG=False

def calc(oIsFirstMonth,oUpdateStream,oStream,oAcmStream):
    v_rate = 0.0003 * 100.0                     #单位（分/kb）
    v_PackageFee = 36 * 100.0                  #套餐包限定费用（分）
    v_PackageStream = 150 * 1024.0        #套餐包包的总流量（kb）
    
    v_byte = round(oStream / 1024.0)                #获取到的是多次预留的总流量值（kb）
    #v_UpdateByte = round(oUpdateStream / 1024.0)    #获取到本次update的流量(kb)
    v_UpdateByte = v_byte
    v_SubsAcmValue = oAcmStream                     #获取累积量，请替换对应的累积量类型（kb）
    
    #将累积量加入总流量(kb)且四舍五入取整
    v_AllDataStream = v_byte + v_SubsAcmValue
    v_PackageFeeStream = round( v_PackageFee / v_rate )
    
    if _DEBUG == True:
        import pdb
        pdb.set_trace()
    
    #首月
    if (oIsFirstMonth == '1'):
        if (v_SubsAcmValue < v_PackageFeeStream):           #当累积量小于36元费用流量时
            if ( v_AllDataStream < v_PackageFeeStream ):    #当跨免费流量资费时
                res = round( v_UpdateByte * v_rate )
            elif( (v_AllDataStream - v_UpdateByte) < v_PackageFeeStream ):
                res = round( ( v_UpdateByte - v_AllDataStream + v_PackageFeeStream ) * v_rate )
            else:
                res = 0
        elif ( v_AllDataStream < v_PackageStream ):   #当在到X1套餐包月量内时，免费
            res = 0
        else:
            #判断当用户累计流量不超过套餐包流量时（跨累计点的流量需要分开计费）
            if ( (v_AllDataStream - v_UpdateByte) < v_PackageStream ):
                res = round( ( v_AllDataStream - v_PackageStream ) * v_rate )
            else:
                res = round( v_UpdateByte * v_rate )    #当超过X1套餐包月量时还是按照0.0003元/kb算费
    #非首月
    else:
        if ( v_AllDataStream < v_PackageStream ): #在套餐规定累积量内免费
            res = 0
        else:
            #判断当用户累计流量不超过套餐包流量时（跨累计点的流量需要分开计费）
            if ( (v_AllDataStream - v_UpdateByte) < v_PackageStream ):
                res = round( ( v_AllDataStream - v_PackageStream ) * v_rate )
            else:
                res = round( v_UpdateByte * v_rate )    #当超过X1套餐包月量时还是按照0.0003元/kb算费
            
    print "============输出==================="
    print "用户已使用总流量=",v_AllDataStream
    if (oIsFirstMonth == '1') and ( v_AllDataStream > v_PackageStream ) and ( v_SubsAcmValue < v_PackageStream ):
        print "用户需计费流量= %d" % (v_AllDataStream - v_PackageStream)
    elif( v_AllDataStream > v_PackageStream ) and  ( v_SubsAcmValue < v_PackageStream ):
        print "用户需计费流量= %d" % (v_AllDataStream - v_PackageStream)
    
    print "应收取费用：%d（分） " % int(res)
    
if (__name__=="__main__"):
    vIsFirstMonth = raw_input('请选择是否首月（1-首月，0-非首月）\n--->')
    vUpdateStream = int(raw_input('请输入本次会话总流量（单位byte）\n--->'))
    vStream = int(raw_input('请输入本次UPDATE总流量（单位byte）\n--->'))
    vAcmStream = int(raw_input('请输入用户已有累积量（单位kb）\n--->'))
    
    calc(vIsFirstMonth,vUpdateStream,vStream,vAcmStream)