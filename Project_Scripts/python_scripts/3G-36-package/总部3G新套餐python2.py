#累积量配置选择：
#   收费事件中需要同时配置三个累积量类型:“36元套餐--首月提醒累计”/“36元套餐--6G封顶累计”/“36元套餐--收费流量累计”
#   免费事件只需要配置一个累积量：“36元套餐--6G封顶累计”
#   “36元套餐--6G封顶累计”/“36元套餐--收费流量累计”--脚本一样注意配置不同的累计类型
========================================
#“36元套餐--首月提醒累计”
========================================
#acm_python1--首月累计--费用均为分，流量均为kb
#为了做到只有首月36元时发送提示消息
def main(r):
    v_rate = 0.0003 * 100.0    #累计费率单元（分/kb）
    v_byte = round( r.event.GetAttr(BYTES).AsInteger() / 1024.0 )    #获取到多次预留的四舍五入总流量值（kb）
    v_EventBeginTime = r.event.GetAttr(EVENT_BEGIN_TIME).AsString()
    v_ProdCompletedDate = r.event.GetProdCompletedDate()
    #首月
    if (v_EventBeginTime[:6] == v_ProdCompletedDate[:6]):
        #四舍五入计算出来应该计费费用的金额（分）
        v_fee = round( v_byte * v_rate )
        #四舍五入应该累计流量（kb）
        res = int( round( v_fee / v_rate ) )
    else:
        res = 0
    
    r.SetResult(res)
    
========================================
#“36元套餐--6G封顶累计”/“36元套餐--收费流量累计”--脚本一样注意配置不同的累计类型
========================================
#acm_python2--非首月累计--费用均为分，流量均为kb
#为了做到6G的流量封顶
#存在问题：
def main(r):
    v_rate = 0.0003 * 100。0    #累计费率单元（分/kb）
    v_byte = round( r.event.GetAttr(BYTES).AsInteger() / 1024.0 )    #获取到多次预留的四舍五入总流量值（kb）
    
    #四舍五入计算出来应该计费费用的金额（分）
    v_fee = round( v_byte * v_rate )
    #四舍五入应该累计流量（kb）
    res = int( round( v_fee / v_rate ) )
    
    r.SetResult(res)

========================================
#计费python
========================================
#计费使用的python--费用均为分，流量均为kb
#累积量类型填“36元套餐--收费流量累计”的累积量类型
#注意，周期费激活首月不用扣取，次月开始扣取周期费，但是不赠送150M，赠送已经包含在累积量中
#查询剩余流量接口配置按照累积量进行查询，累积量类型配置“36元套餐--收费流量累计”的类型
#在周期费首月激活场景配置通知短信“第二条”
#配置触发器，累积量类型为“36元套餐--首月提醒累计”，当达到“36/0.0003”的时候给用户发送短信“当用户数据流量使用费用达到36元时的短信提醒”
#封顶设置中选择累积量类型：“36元套餐--6G封顶累计”
#添加跨计费点计费的功能
#bytes是针对总使用流量的字节数，但是找不到专门针对本次上报使用量的脚本
def main(r):
    v_rate = 0.0003 * 100.0               #费率（分/kb）
    v_PackageFee = 36 * 100.0             #套餐包限定费用（分）
    v_PackageStream = 150 * 1024.0        #套餐包包的总流量（kb）
    
    v_byte = round( r.event.GetAttr(BYTES).AsInteger() / 1024.0 )    #获取到的是多次预留的总流量值（kb）
    print "Total byte:",v_byte
    
    #获取本次update的流量（kb）
    #v_UpdateByte = round( r.event.GetAttr(UP_DATA).AsInteger() / 1024 ) + round( r.event.GetAttr(DOWN_DATA).AsInteger() / 1024 )
	v_UpdateByte = v_byte
    print "update byte:",v_UpdateByte
    
    v_BillingCycleId = r.event.GetAttr(BILLING_CYCLE_ID).AsInteger()
    v_SubsAcmValue = r.event.GetSubsAcmValueByCycle(“36元套餐--收费流量累计”, v_BillingCycleId)   #获取累积量，请替换对应的累积量类型（kb）
    v_EventBeginTime = r.event.GetAttr(EVENT_BEGIN_TIME).AsString()
    v_ProdCompletedDate = r.event.GetProdCompletedDate()
    
    #将累积量加入总流量(kb)且四舍五入取整
    v_AllDataStream = v_byte + v_SubsAcmValue
    v_PackageFeeStream = round( v_PackageFee / v_rate )
    
    #首月
    if (v_EventBeginTime[:6] == v_ProdCompletedDate[:6]):
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
            
    r.SetResult(int(res))

#===============================
#测试属性的脚本
#===============================
def main(r):
	print "***************begin scripts*****************"
	try:
		v_MSCC_USU_BYTES = r.event.GetAttr(MSCC_USU_BYTES).AsInteger()
		print "v_MSCC_USU_BYTES =", v_MSCC_USU_BYTES
	except Exception, e:
		print "v_MSCC_USU_BYTES error:", e
		
	try:
		v_UP_DATA = r.event.GetAttr(UP_DATA).AsInteger()
		print "v_UP_DATA =", v_UP_DATA
	except Exception, e:
		print "v_UP_DATA error:", e
		
	try:
		v_DOWN_DATA = r.event.GetAttr(DOWN_DATA).AsInteger()
		print "v_DOWN_DATA ", v_DOWN_DATA
	except Exception, e:
		print "v_DOWN_DATA error:", e
		
	try:
		v_BYTES = r.event.GetAttr(BYTES).AsInteger()
		print "v_BYTES =", v_BYTES
	except Exception, e:
		print "v_BYTES error:", e
		
	try:
		v_USU_CC_TOTAL_OCTETS2 = r.event.GetAttr(USU_CC_TOTAL_OCTETS2).AsInteger()
		print "v_USU_CC_TOTAL_OCTETS2 =", v_USU_CC_TOTAL_OCTETS2
	except Exception, e:
		print "v_USU_CC_TOTAL_OCTETS2 error:", e
		
	try:
		v_USU_CC_INPUT_OCTETS2 = r.event.GetAttr(USU_CC_INPUT_OCTETS2).AsInteger()
		print "v_USU_CC_INPUT_OCTETS2 =", v_USU_CC_INPUT_OCTETS2
	except Exception, e:
		print "v_USU_CC_INPUT_OCTETS2 error:", e
		
	try:
		v_USU_CC_OUTPUT_OCTETS2 = r.event.GetAttr(USU_CC_OUTPUT_OCTETS2).AsInteger()
		print "v_USU_CC_OUTPUT_OCTETS2 =", v_USU_CC_OUTPUT_OCTETS2
	except Exception, e:
		print "v_USU_CC_OUTPUT_OCTETS2 error:", e
		
	r.SetResult(0)
    
#山东最终确认的累计方式：
#以KB为累计
#acm_python1--首月累计--费用均为分，流量均为kb
#为了做到只有首月36元时发送提示消息
def main(r):
    v_rate = 0.0003 * 100.0                                         #累计费率单元（分/kb）
    v_byte = ( r.event.GetAttr(BYTES).AsInteger() + 1023 ) / 1024   #获取到多次预留的四舍五入总流量值（kb）
    v_EventBeginTime = r.event.GetAttr(EVENT_BEGIN_TIME).AsString()
    v_ProdCompletedDate = r.event.GetProdCompletedDate()
    
    if (v_EventBeginTime[:6] == v_ProdCompletedDate[:6]):           #首月
        res = int(v_byte)
    else:
        res = 0
    
    r.SetResult(res)
    