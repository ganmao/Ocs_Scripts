CREATE OR REPLACE PROCEDURE ZDL_SEND_PORTFOLIO_REPORT IS
  --提醒类型
  V_ADVICE_TYPE NUMBER(6, 0) := 6;
  --构建动态sql临时存储变量
  V_TMP_SQL VARCHAR2(1200);
  --发送短信号码的SUBS_ID
  V_SUBS_ID NUMBER;
  --当前所在帐期ID
  V_BILLING_CYCLE_ID NUMBER;
  --抛出异常消息内容
  V_SQL_ERR_MSG VARCHAR2(500);
  --统计时间点
  V_STAT_TIME VARCHAR2(14);

  --定义数据用于存放发送短信号码
  TYPE TYPE_TABLE IS TABLE OF VARCHAR2(1000) INDEX BY PLS_INTEGER;

  V_ACC_NBR TYPE_TABLE;
  V_MSG     TYPE_TABLE;
  --部分统计信息的临时变量
  V_STAT_DATA_CNT        NUMBER; --数据
  V_STAT_VOICE_CNT       NUMBER; --语音
  V_STAT_SMS_CNT         NUMBER; --短信
  V_STAT_VAS_CNT         NUMBER; --增值
  V_STAT_ERR_CNT         NUMBER; --错单
  V_STAT_CYCLE_CNT       NUMBER; --周期费
  V_STAT_EVENT_CNT       NUMBER; --一次性费
  V_STAT_RECHARGE_CNT    NUMBER; --充值记录
  V_STAT_RECHARGE_SUM    NUMBER; --充值金额
  V_STAT_CREATE_USER_CNT NUMBER; --新开户
  V_STAT_ACTION_USER_CNT NUMBER; --激活
  V_STAT_STOP_CNT        NUMBER; --停机
  V_STAT_RECOVER_CNT     NUMBER; --复机
  V_STAT_REMOVE_CNT      NUMBER; --拆机
  GET_BILLING_CYCLE_ERROR EXCEPTION;
BEGIN
  DBMS_OUTPUT.ENABLE(99999999);
  /*定义需要发送消息的手机号码,必须是OCS系统内存在的号码*/
  --================================================================
  V_ACC_NBR(1) := '15593777402';
  V_ACC_NBR(2) := '18609445414';
  V_ACC_NBR(3) := '18609445413';
  V_ACC_NBR(4) := '15569615384';
  V_ACC_NBR(5) := '13139405468';
  V_ACC_NBR(6) := '13139405467'; 
  --================================================================

  --获取统计时间点
  SELECT TO_CHAR(SYSDATE, 'yyyymmddhh24miss') INTO V_STAT_TIME FROM DUAL;

  --获取当前所在帐期ID
  SELECT NVL(BILLING_CYCLE_ID, 0)
    INTO V_BILLING_CYCLE_ID
    FROM CC.BILLING_CYCLE@LINK_CC
   WHERE SYSDATE >= CYCLE_BEGIN_DATE
     AND SYSDATE < CYCLE_END_DATE;

  IF V_BILLING_CYCLE_ID = 0 THEN
    RAISE GET_BILLING_CYCLE_ERROR;
  END IF;

  --获取发送短信的业务量统计
  V_TMP_SQL := 'SELECT COUNT(*) FROM event_usage_c_' || V_BILLING_CYCLE_ID ||
               ' WHERE service_type = 1 AND trunc(state_date) = trunc(SYSDATE)';

  EXECUTE IMMEDIATE V_TMP_SQL
    INTO V_STAT_DATA_CNT;

  V_TMP_SQL := 'SELECT COUNT(*) FROM event_usage_' || V_BILLING_CYCLE_ID ||
               ' WHERE service_type = 2 AND trunc(state_date) = trunc(SYSDATE)';

  EXECUTE IMMEDIATE V_TMP_SQL
    INTO V_STAT_VOICE_CNT;

  V_TMP_SQL := 'SELECT COUNT(*) FROM event_usage_' || V_BILLING_CYCLE_ID ||
               ' WHERE service_type = 4 AND trunc(state_date) = trunc(SYSDATE)';

  EXECUTE IMMEDIATE V_TMP_SQL
    INTO V_STAT_SMS_CNT;

  V_TMP_SQL := 'SELECT COUNT(*) FROM event_usage_c_' || V_BILLING_CYCLE_ID ||
               ' WHERE service_type = 8 AND trunc(state_date) = trunc(SYSDATE)';

  EXECUTE IMMEDIATE V_TMP_SQL
    INTO V_STAT_VAS_CNT;

  V_TMP_SQL := 'SELECT COUNT(*) FROM event_recurring_' ||
               V_BILLING_CYCLE_ID ||
               ' WHERE trunc(created_date) = trunc(SYSDATE)';

  EXECUTE IMMEDIATE V_TMP_SQL
    INTO V_STAT_CYCLE_CNT;

  --错单
  SELECT COUNT(*)
    INTO V_STAT_ERR_CNT
    FROM EVENT_USAGE_FAIL
   WHERE TRUNC(CREATE_TIME) = TRUNC(SYSDATE);

  --一次性费
  SELECT COUNT(*)
    INTO V_STAT_EVENT_CNT
    FROM EVENT_CHARGE@LINK_CC
   WHERE TRUNC(STATE_DATE) = TRUNC(SYSDATE);

  --充值
  SELECT COUNT(*) TOTAL, SUM(CHARGE / 100) * (-1) CHARGE
    INTO V_STAT_RECHARGE_CNT, V_STAT_RECHARGE_SUM
    FROM CC.ACCT_BOOK@LINK_CC
   WHERE ACCT_BOOK_TYPE = 'P'
     AND TRUNC(CREATED_DATE) = TRUNC(SYSDATE);

  --开户
  SELECT COUNT(*) TOTAL
    INTO V_STAT_CREATE_USER_CNT
    FROM CC.PROD@LINK_CC
   WHERE TRUNC(CREATED_DATE) = TRUNC(SYSDATE)
     and indep_prod_id IS NULL;

  --激活
  SELECT COUNT(*) TOTAL
    INTO V_STAT_ACTION_USER_CNT
    FROM CC.PROD@LINK_CC
   WHERE TRUNC(COMPLETED_DATE) = TRUNC(SYSDATE)
     AND PROD_STATE != 'G'
     AND indep_prod_id IS NULL;

  --停机
  SELECT COUNT(*) TOTAL
    INTO V_STAT_STOP_CNT
    FROM CC.PROD@LINK_CC P, CC.PROD_HIS@LINK_CC PH
   WHERE P.PROD_STATE = 'D'
     AND TRUNC(P.PROD_STATE_DATE) = TRUNC(SYSDATE)
     AND TRUNC(PH.STATE_DATE) = TRUNC(SYSDATE)
     AND P.PROD_ID = PH.PROD_ID
     AND P.PROD_STATE_DATE = PH.STATE_DATE
     AND PH.PROD_STATE = 'A'
     AND p.indep_prod_id IS NULL;

  --复机
  SELECT COUNT(*) TOTAL
    INTO V_STAT_RECOVER_CNT
    FROM CC.PROD@LINK_CC P, CC.PROD_HIS@LINK_CC PH
   WHERE P.PROD_STATE = 'A'
     AND TRUNC(P.PROD_STATE_DATE) = TRUNC(SYSDATE)
     AND TRUNC(PH.STATE_DATE) = TRUNC(SYSDATE)
     AND P.PROD_ID = PH.PROD_ID
     AND P.PROD_STATE_DATE = PH.STATE_DATE
     AND PH.PROD_STATE = 'D'
     AND p.indep_prod_id IS NULL;

  --拆机
  SELECT COUNT(*) TOTAL
    INTO V_STAT_REMOVE_CNT
    FROM CC.PROD@LINK_CC
   WHERE TRUNC(PROD_STATE_DATE) = TRUNC(SYSDATE)
     AND PROD_STATE = 'B'
     AND indep_prod_id IS NULL;

  --组合发送短信的内容
  V_MSG(1) := '话务量统计(条)||语音:' || V_STAT_VOICE_CNT || '|短信:' ||
              V_STAT_SMS_CNT || '|数据:' || V_STAT_DATA_CNT || '|增值:' ||
              V_STAT_VAS_CNT || '|错单:' || V_STAT_ERR_CNT || '|周期费:' ||
              V_STAT_CYCLE_CNT || '|一次性费:' || V_STAT_EVENT_CNT || '|充值记录:' ||
              V_STAT_RECHARGE_CNT || '|充值金额(元):' || V_STAT_RECHARGE_SUM ||
              '||用户数统计||开户:' || V_STAT_CREATE_USER_CNT || '|激活:' ||
              V_STAT_ACTION_USER_CNT || '|停机:' || V_STAT_STOP_CNT || '|复机:' ||
              V_STAT_RECOVER_CNT || '|拆机:' || V_STAT_REMOVE_CNT || '|统计时间:' ||
              V_STAT_TIME;
  DBMS_OUTPUT.PUT_LINE(V_MSG(1));
  /*  V_MSG(2) := '用户数统计:开户:' || V_STAT_CREATE_USER_CNT || '|激活:' ||
                V_STAT_ACTION_USER_CNT || '|停机:' || V_STAT_STOP_CNT || '|复机:' ||
                V_STAT_RECOVER_CNT || '|拆机:' || V_STAT_REMOVE_CNT || '|统计时间:' ||
                V_STAT_TIME;
    DBMS_OUTPUT.PUT_LINE(V_MSG(2));
  */
  --开始发送短信
  FOR I IN V_ACC_NBR.FIRST .. V_ACC_NBR.LAST LOOP
    DBMS_OUTPUT.PUT_LINE('开始向[' || V_ACC_NBR(I) || ']发送短信!');
    V_SQL_ERR_MSG := V_ACC_NBR(I);
  
    BEGIN
      --根据号码获取用户的SUBS_ID
      SELECT NVL(SUBS_ID, 0)
        INTO V_SUBS_ID
        FROM CC.SUBS@LINK_CC S, CC.PROD@LINK_CC P
       WHERE S.SUBS_ID = P.PROD_ID
         AND (P.PROD_STATE = 'A' OR P.PROD_STATE = 'D')
         AND ACC_NBR = V_ACC_NBR(I);
    
      FOR MI IN V_MSG.FIRST .. V_MSG.LAST LOOP
        --插入ADVICE表发送短信
        INSERT INTO CC.ADVICE@LINK_CC
          (ADVICE_ID,
           ADVICE_TYPE,
           SUBS_ID,
           ACC_NBR,
           MSG,
           CREATED_DATE,
           STATE,
           STATE_DATE)
        VALUES
          (CC.ADVICE_ID_SEQ.NEXTVAL@LINK_CC,
           V_ADVICE_TYPE,
           V_SUBS_ID,
           V_ACC_NBR(I),
           V_MSG(MI),
           SYSDATE,
           'A',
           SYSDATE);
      
        COMMIT;
      END LOOP;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        V_SQL_ERR_MSG := '需要发送短信的号码[' || V_SQL_ERR_MSG ||
                         ']在OCS系统中查找不到或者已经失效!';
        DBMS_OUTPUT.PUT_LINE(V_SQL_ERR_MSG);
      WHEN TOO_MANY_ROWS THEN
        V_SQL_ERR_MSG := '号码[' || V_SQL_ERR_MSG || ']存在多条SUBS记录!';
        DBMS_OUTPUT.PUT_LINE(V_SQL_ERR_MSG);
    END;
  END LOOP;
EXCEPTION
  WHEN GET_BILLING_CYCLE_ERROR THEN
    V_SQL_ERR_MSG := '获取当前时间[' || SYSDATE || ']的帐期id错误!';
    DBMS_OUTPUT.PUT_LINE(V_SQL_ERR_MSG);
  WHEN OTHERS THEN
    V_SQL_ERR_MSG := SQLERRM;
    DBMS_OUTPUT.PUT_LINE(V_SQL_ERR_MSG);
END ZDL_SEND_PORTFOLIO_REPORT;
/
