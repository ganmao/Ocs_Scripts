CREATE OR REPLACE PROCEDURE ZDL_SEND_PORTFOLIO_REPORT IS
  --��������
  V_ADVICE_TYPE NUMBER(6, 0) := 6;
  --������̬sql��ʱ�洢����
  V_TMP_SQL VARCHAR2(1200);
  --���Ͷ��ź����SUBS_ID
  V_SUBS_ID NUMBER;
  --��ǰ��������ID
  V_BILLING_CYCLE_ID NUMBER;
  --�׳��쳣��Ϣ����
  V_SQL_ERR_MSG VARCHAR2(500);
  --ͳ��ʱ���
  V_STAT_TIME VARCHAR2(14);

  --�����������ڴ�ŷ��Ͷ��ź���
  TYPE TYPE_TABLE IS TABLE OF VARCHAR2(1000) INDEX BY PLS_INTEGER;

  V_ACC_NBR TYPE_TABLE;
  V_MSG     TYPE_TABLE;
  --����ͳ����Ϣ����ʱ����
  V_STAT_DATA_CNT        NUMBER; --����
  V_STAT_VOICE_CNT       NUMBER; --����
  V_STAT_SMS_CNT         NUMBER; --����
  V_STAT_VAS_CNT         NUMBER; --��ֵ
  V_STAT_ERR_CNT         NUMBER; --��
  V_STAT_CYCLE_CNT       NUMBER; --���ڷ�
  V_STAT_EVENT_CNT       NUMBER; --һ���Է�
  V_STAT_RECHARGE_CNT    NUMBER; --��ֵ��¼
  V_STAT_RECHARGE_SUM    NUMBER; --��ֵ���
  V_STAT_CREATE_USER_CNT NUMBER; --�¿���
  V_STAT_ACTION_USER_CNT NUMBER; --����
  V_STAT_STOP_CNT        NUMBER; --ͣ��
  V_STAT_RECOVER_CNT     NUMBER; --����
  V_STAT_REMOVE_CNT      NUMBER; --���
  GET_BILLING_CYCLE_ERROR EXCEPTION;
BEGIN
  DBMS_OUTPUT.ENABLE(99999999);
  /*������Ҫ������Ϣ���ֻ�����,������OCSϵͳ�ڴ��ڵĺ���*/
  --================================================================
  V_ACC_NBR(1) := '15593777402';
  V_ACC_NBR(2) := '18609445414';
  V_ACC_NBR(3) := '18609445413';
  V_ACC_NBR(4) := '15569615384';
  V_ACC_NBR(5) := '13139405468';
  V_ACC_NBR(6) := '13139405467'; 
  --================================================================

  --��ȡͳ��ʱ���
  SELECT TO_CHAR(SYSDATE, 'yyyymmddhh24miss') INTO V_STAT_TIME FROM DUAL;

  --��ȡ��ǰ��������ID
  SELECT NVL(BILLING_CYCLE_ID, 0)
    INTO V_BILLING_CYCLE_ID
    FROM CC.BILLING_CYCLE@LINK_CC
   WHERE SYSDATE >= CYCLE_BEGIN_DATE
     AND SYSDATE < CYCLE_END_DATE;

  IF V_BILLING_CYCLE_ID = 0 THEN
    RAISE GET_BILLING_CYCLE_ERROR;
  END IF;

  --��ȡ���Ͷ��ŵ�ҵ����ͳ��
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

  --��
  SELECT COUNT(*)
    INTO V_STAT_ERR_CNT
    FROM EVENT_USAGE_FAIL
   WHERE TRUNC(CREATE_TIME) = TRUNC(SYSDATE);

  --һ���Է�
  SELECT COUNT(*)
    INTO V_STAT_EVENT_CNT
    FROM EVENT_CHARGE@LINK_CC
   WHERE TRUNC(STATE_DATE) = TRUNC(SYSDATE);

  --��ֵ
  SELECT COUNT(*) TOTAL, SUM(CHARGE / 100) * (-1) CHARGE
    INTO V_STAT_RECHARGE_CNT, V_STAT_RECHARGE_SUM
    FROM CC.ACCT_BOOK@LINK_CC
   WHERE ACCT_BOOK_TYPE = 'P'
     AND TRUNC(CREATED_DATE) = TRUNC(SYSDATE);

  --����
  SELECT COUNT(*) TOTAL
    INTO V_STAT_CREATE_USER_CNT
    FROM CC.PROD@LINK_CC
   WHERE TRUNC(CREATED_DATE) = TRUNC(SYSDATE)
     and indep_prod_id IS NULL;

  --����
  SELECT COUNT(*) TOTAL
    INTO V_STAT_ACTION_USER_CNT
    FROM CC.PROD@LINK_CC
   WHERE TRUNC(COMPLETED_DATE) = TRUNC(SYSDATE)
     AND PROD_STATE != 'G'
     AND indep_prod_id IS NULL;

  --ͣ��
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

  --����
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

  --���
  SELECT COUNT(*) TOTAL
    INTO V_STAT_REMOVE_CNT
    FROM CC.PROD@LINK_CC
   WHERE TRUNC(PROD_STATE_DATE) = TRUNC(SYSDATE)
     AND PROD_STATE = 'B'
     AND indep_prod_id IS NULL;

  --��Ϸ��Ͷ��ŵ�����
  V_MSG(1) := '������ͳ��(��)||����:' || V_STAT_VOICE_CNT || '|����:' ||
              V_STAT_SMS_CNT || '|����:' || V_STAT_DATA_CNT || '|��ֵ:' ||
              V_STAT_VAS_CNT || '|��:' || V_STAT_ERR_CNT || '|���ڷ�:' ||
              V_STAT_CYCLE_CNT || '|һ���Է�:' || V_STAT_EVENT_CNT || '|��ֵ��¼:' ||
              V_STAT_RECHARGE_CNT || '|��ֵ���(Ԫ):' || V_STAT_RECHARGE_SUM ||
              '||�û���ͳ��||����:' || V_STAT_CREATE_USER_CNT || '|����:' ||
              V_STAT_ACTION_USER_CNT || '|ͣ��:' || V_STAT_STOP_CNT || '|����:' ||
              V_STAT_RECOVER_CNT || '|���:' || V_STAT_REMOVE_CNT || '|ͳ��ʱ��:' ||
              V_STAT_TIME;
  DBMS_OUTPUT.PUT_LINE(V_MSG(1));
  /*  V_MSG(2) := '�û���ͳ��:����:' || V_STAT_CREATE_USER_CNT || '|����:' ||
                V_STAT_ACTION_USER_CNT || '|ͣ��:' || V_STAT_STOP_CNT || '|����:' ||
                V_STAT_RECOVER_CNT || '|���:' || V_STAT_REMOVE_CNT || '|ͳ��ʱ��:' ||
                V_STAT_TIME;
    DBMS_OUTPUT.PUT_LINE(V_MSG(2));
  */
  --��ʼ���Ͷ���
  FOR I IN V_ACC_NBR.FIRST .. V_ACC_NBR.LAST LOOP
    DBMS_OUTPUT.PUT_LINE('��ʼ��[' || V_ACC_NBR(I) || ']���Ͷ���!');
    V_SQL_ERR_MSG := V_ACC_NBR(I);
  
    BEGIN
      --���ݺ����ȡ�û���SUBS_ID
      SELECT NVL(SUBS_ID, 0)
        INTO V_SUBS_ID
        FROM CC.SUBS@LINK_CC S, CC.PROD@LINK_CC P
       WHERE S.SUBS_ID = P.PROD_ID
         AND (P.PROD_STATE = 'A' OR P.PROD_STATE = 'D')
         AND ACC_NBR = V_ACC_NBR(I);
    
      FOR MI IN V_MSG.FIRST .. V_MSG.LAST LOOP
        --����ADVICE���Ͷ���
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
        V_SQL_ERR_MSG := '��Ҫ���Ͷ��ŵĺ���[' || V_SQL_ERR_MSG ||
                         ']��OCSϵͳ�в��Ҳ��������Ѿ�ʧЧ!';
        DBMS_OUTPUT.PUT_LINE(V_SQL_ERR_MSG);
      WHEN TOO_MANY_ROWS THEN
        V_SQL_ERR_MSG := '����[' || V_SQL_ERR_MSG || ']���ڶ���SUBS��¼!';
        DBMS_OUTPUT.PUT_LINE(V_SQL_ERR_MSG);
    END;
  END LOOP;
EXCEPTION
  WHEN GET_BILLING_CYCLE_ERROR THEN
    V_SQL_ERR_MSG := '��ȡ��ǰʱ��[' || SYSDATE || ']������id����!';
    DBMS_OUTPUT.PUT_LINE(V_SQL_ERR_MSG);
  WHEN OTHERS THEN
    V_SQL_ERR_MSG := SQLERRM;
    DBMS_OUTPUT.PUT_LINE(V_SQL_ERR_MSG);
END ZDL_SEND_PORTFOLIO_REPORT;
/
