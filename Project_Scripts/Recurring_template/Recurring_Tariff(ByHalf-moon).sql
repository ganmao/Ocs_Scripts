def main(r):
    #预收型租费,通过周期开始时间查Prod_State
    prod_state = r.event.GetIndependProdState()
    #获取算费场景
    recurr_deal_mode = r.event.GetAttrEx(RECURRING_DEAL_MODE).AsInteger()
    #资费计划状态
    price_plan_inst_state = r.event.GetAttrEx(PRICE_PLAN_INST_STATE).AsString()

    cycle_begin_time = r.event.GetAttrEx(CYCLE_BEGIN_TIME).AsString()
    currentTime = r.event.GetAttrEx(EVENT_BEGIN_TIME).AsString()

    #N不收费,A按天折算收取,E按整个帐期收取
    new_flag=&NEWCONNECTION&
    term_flag=&TERMINATION&
    normal_flag=&NORMAL&

    #可以设置每天是多少钱，或者每个帐期多少钱
    price_day=&PRICEBYDAY&
    price_cycle=&PRICEBYCYCLE&

    #获得月已经过去天数
    pass_days=diffdays(currentTime,cycle_begin_time)

    #如果界面设置的是按照帐期计费
    if(price_day == -1) :
        #按照整帐期计算周期费
        price_charge = (price_cycle * 1000 + 5)/10
    #计算日租
    else:
        #通过每天单价扩大100倍,获得一个帐期的费用
        price_charge = (price_day * 1000 + 5)/10

    if (pass_days > 15):
        price_charge = price_charge / 2

    if (recurr_deal_mode == 0): #正常算费
        first_cycle_flag = r.event.GetAttrEx(IS_FIRST_CYCLE).AsInteger() #是否是首月租算费
        if (first_cycle_flag == 1): #首月租算费子,结合资费计划本身状态,去激活状态租费金额为0
            #收取产品周期事件资费
            if(prod_state != "" and price_plan_inst_state != ""):
                #如果产品状态是G或A或D
                if( (prod_state == "A" or prod_state == "G" or prod_state == "D") and price_plan_inst_state == "A" ):
                    charge = price_charge
                else:
                    charge = 0
            else:
                charge = 0
        else: #非首月租算费,资费计划本身状态确定金额,去激活状态租费金额为0
            if(prod_state != "" and price_plan_inst_state != ""):
                if((prod_state == "A" or prod_state == "D") and price_plan_inst_state == "A"):
                    charge = price_charge
                else:
                    charge = 0
            else:
                charge = 0
    elif(recurr_deal_mode == 1): #充值补收,不要判断资费计划状态
        charge = price_charge
    elif(recurr_deal_mode == 3): #用户状态变更
        #用户状态变更前状态
        pre_indep_prod_state = r.event.GetAttrEx(PRE_INDEP_PROD_STATE).AsString()
        if (pre_indep_prod_state == "G"):
            #首次激活判断
            if(prod_state != "" and price_plan_inst_state == "A"):
                charge = price_charge
            else:
                charge = 0
        else:
            #此处编写非首次激活,不需要判断资费计划状态
            if(prod_state != "" and price_plan_inst_state != ""):
                charge = price_charge
            else:
                charge = 0
    else:
        charge = 0

    #将费用缩小100倍,再次四舍五入
    r.SetResult((charge+50)/100);