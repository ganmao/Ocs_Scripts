def main(r):
    #Ԥ�������,ͨ�����ڿ�ʼʱ���Prod_State
    prod_state = r.event.GetIndependProdState()
    #��ȡ��ѳ���
    recurr_deal_mode = r.event.GetAttrEx(RECURRING_DEAL_MODE).AsInteger()
    #�ʷѼƻ�״̬
    price_plan_inst_state = r.event.GetAttrEx(PRICE_PLAN_INST_STATE).AsString()

    #N���շ�,A����������ȡ,E������������ȡ
    new_flag=&NEWCONNECTION&
    term_flag=&TERMINATION&
    normal_flag=&NORMAL&

    #��������ÿ���Ƕ���Ǯ������ÿ�����ڶ���Ǯ
    price_day=&PRICEBYDAY&
    price_cycle=&PRICEBYCYCLE&

    #����������õ��ǰ������ڼƷ�
    if(price_day == -1) :
        #���������ڼ������ڷ�
        price_charge = (price_cycle * 1000 + 5)/10
    #��������
    else:
        #ͨ��ÿ�쵥������100��,���һ�����ڵķ���
        price_charge = (price_day * 1000 + 5)/10

    if (recurr_deal_mode == 0): #�������
        first_cycle_flag = r.event.GetAttrEx(IS_FIRST_CYCLE).AsInteger() #�Ƿ������������
        if (first_cycle_flag == 1): #�����������,����ʷѼƻ�����״̬,ȥ����״̬��ѽ��Ϊ0
            #��ȡ��Ʒ�����¼��ʷ�
            if(prod_state != "" and price_plan_inst_state != ""):
                #�����Ʒ״̬��G��A��D
                if((prod_state == "A" or prod_state == "G" or prod_state == "D") and price_plan_inst_state == "A"):
                    charge = price_charge
                else:
                    charge = 0
            else:
                charge = 0
        else: #�����������,�ʷѼƻ�����״̬ȷ�����,ȥ����״̬��ѽ��Ϊ0
            if(prod_state != "" and price_plan_inst_state != ""):
                if((prod_state == "A" or prod_state == "D") and price_plan_inst_state == "A"):
                    charge = price_charge
                else:
                    charge = 0
            else:
                charge = 0
    elif(recurr_deal_mode == 1): #��ֵ����,��Ҫ�ж��ʷѼƻ�״̬
        charge = price_charge
    elif(recurr_deal_mode == 3): #�û�״̬���
        #�û�״̬���ǰ״̬
        pre_indep_prod_state = r.event.GetAttrEx(PRE_INDEP_PROD_STATE).AsString()
        if (pre_indep_prod_state == "G"):
            #�״μ����ж�
            if(prod_state != "" and price_plan_inst_state == "A"):
                charge = price_charge
            else:
                charge = 0
        else:
            #�˴���д���״μ���,����Ҫ�ж��ʷѼƻ�״̬
            if(prod_state != "" and price_plan_inst_state != ""):
                charge = price_charge
            else:
                charge = 0
    else:
        charge = 0

    #��������С100��,�ٴ���������
    r.SetResult((charge+50)/100);