CREATE OR REPLACE PACKAGE BALRP_PKG_FOR_CUC IS

  -- Author  : zhang.dongliang@zte.com.cn
  -- Created : 2010-06-03 13:33:33
  -- Purpose : the balance report for CUC

  -- ==================================================
  -- ���²�����Ҫ�ֳ���������Լ�����
  -- ==================================================
  -- ��������ʹ�õ���
  -- �ӱ�(HB)��ɽ��(SD)������(NM)������(GS)
  GC_PROVINCE CONSTANT CHAR(2) := 'SD';

  -- ��Ҫͳ�Ƶ��������
  GC_RES_TYPE CONSTANT VARCHAR2(100) := '1,2';

  -- �����м�����ʹ�ú��Ƿ�ɾ��(TRUE|FALSE)
  GC_TMP_TABLE_DEL CONSTANT BOOLEAN := FALSE;

  -- �����Ƿ��������ݲɼ��׶�ֱ�ӽ��б������(TRUE|FALSE)
  GC_JUMP_COLLECT CONSTANT BOOLEAN := FALSE;

  -- ������־�ȼ�
  GC_LOGING_LEVEL CONSTANT NUMBER := 5;

  -- ��־��Ϣ��
  GC_PROC_LOG CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_proc_log';

  -- �û���Ϣ�м��
  GC_USER_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_user_';

  -- �����м��
  GC_CDR_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_cdr_';

  -- ACCT_BOOK�м��
  GC_ACCTBOOK_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_acctbook_';

  EXP_CREATE_TMP_TAB_ERR EXCEPTION;
  -- ==================================================

  /*
  ����˵����
     �� p ǰ׺�ľ�Ϊ���������͡�����������������
     pt_ ��������
     pc_ ��������
     pv_ ��������
     ...
  */

  -- Public type declarations
  -- type <TypeName> is <Datatype>;

  -- �������
  -- ==================================================
  -- ����ID
  GV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE;

  -- ���庯��
  -- ==================================================
  -- �ж�ĳ�ű��Ƿ��Ѿ�����
  FUNCTION PF_JUDGE_TAB_EXIST(INV_TABLENAME USER_TABLES.TABLE_NAME%TYPE)
    RETURN BOOLEAN;

  -- ��ȡϵͳ��ǰʱ���ϸ�������ID
  FUNCTION PF_GETLOCALCYCLEID
    RETURN BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE;

  -- ��������id��ȡ���ڿ�ʼʱ��
  FUNCTION PF_GET_CYCLEEGINTIME(INV_CYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE)
    RETURN BILLING_CYCLE.CYCLE_BEGIN_DATE@LINK_CC%TYPE;

  -- ��������id��ȡ���ڽ���ʱ��
  FUNCTION PF_GET_CYCLEENDIME(INV_CYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE)
    RETURN BILLING_CYCLE.CYCLE_END_DATE@LINK_CC%TYPE;

  -- ���ص�ǰ����ʡ��
  FUNCTION PF_CURR_PROVINCE RETURN CHAR;

  -- �������
  -- ==================================================
  -- ���̵�������
  PROCEDURE PP_MAIN(INV_PREBALTAB USER_TABLES.TABLE_NAME%TYPE,
                    INV_AFTBALTAB USER_TABLES.TABLE_NAME%TYPE);

  -- ��ʼ������ձ������ݣ��ڽ����м���ʱ����

  -- ɾ�������ڵ��м���
  PROCEDURE PP_DEL_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                           INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- �ɼ��û���Ϣ�������û���Ϣ������
  PROCEDURE PP_COLLECT_USERINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                                INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- �ɼ����������࣬��������
  PROCEDURE PP_COLLECT_CDR(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                           INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- �ɼ��û�����ACCT_BOOK����Ϣ
  PROCEDURE PP_COLLECT_ACCTBOOK(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                                INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- �������������Ϣ����������
  PROCEDURE PP_COLLECT_BALINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                               INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- ��־��ӡ
  PROCEDURE PP_PRINTLOG(INV_LOGLEVEL  NUMBER,
                        INV_FUNCNAME  VARCHAR2,
                        INV_LOGERRNUM VARCHAR2,
                        INV_LOGTXT    VARCHAR2);

END BALRP_PKG_FOR_CUC;
/
CREATE OR REPLACE PACKAGE BODY BALRP_PKG_FOR_CUC IS

  -- Private type declarations
  -- type <TypeName> is <Datatype>;

  -- Private constant declarations
  -- <ConstantName> constant <Datatype> := <Value>;

  -- Private variable declarations
  -- <VariableName> <Datatype>;

  -------------------------------------------------------------------------------
  PROCEDURE PP_MAIN(INV_PREBALTAB USER_TABLES.TABLE_NAME%TYPE,
                    INV_AFTBALTAB USER_TABLES.TABLE_NAME%TYPE) IS
    V_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE;
    V_SQL            VARCHAR2(4000);
    V_COUNT          NUMBER(10);
  BEGIN
    DBMS_OUTPUT.PUT_LINE('��ʼ���ô洢����[balrp_pkg_for_cuc.pp_main]����ϸ��־�����' ||
                         GC_PROC_LOG);
  
    -- �ж���־��Ϣ���Ƿ����
    -- ��������־��Ϣ������н���
    IF PF_JUDGE_TAB_EXIST(GC_PROC_LOG) = FALSE THEN
      DBMS_OUTPUT.PUT_LINE('��־��Ϣ�����ڣ���ʼ������' || GC_PROC_LOG);
    
      -- �����û���־��Ϣ��
      V_SQL := 'create table ' || GC_PROC_LOG || ' (
                proc_time date,
                log_level number(3),
                log_fun varchar2(100),
                log_err_no number(6),
                log_txt varchar2(1000)
                )
                TABLESPACE TAB_RB
                 ';
      EXECUTE IMMEDIATE V_SQL;
    
    END IF;
    -- DBMS_OUTPUT.PUT_LINE('��־��Ϣ���Ѿ�������' || GC_PROC_LOG);
  
    -- ��ʼ��
    PP_PRINTLOG(1,
                'PP_MAIN',
                0,
                '-------------------------------------------------------------------------------');
    PP_PRINTLOG(1, 'PP_MAIN', 0, '��ʼ���г�ʼ����');
  
    -- ��ȡ������������ID
    V_BILLINGCYCLEID := PF_GETLOCALCYCLEID();
  
    -- �ɼ��û���Ϣ����
    --PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
    --PP_COLLECT_USERINFO(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
    --PP_PRINTLOG(3, 'PP_MAIN', '00004', '�ɼ��û���Ϣ��ɣ�');
  
    -- �ɼ��û���������
    /*    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_CDR_TAB_NAME);
    PP_COLLECT_CDR(V_BILLINGCYCLEID, GC_CDR_TAB_NAME);
    PP_PRINTLOG(3, 'PP_MAIN', 0, '�ɼ�CDR��Ϣ��ɣ�');*/
  
    -- �ɼ��û��ɷ���Ϣ
    --PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME);
    --PP_COLLECT_ACCTBOOK(V_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME);
    --PP_PRINTLOG(3, 'PP_MAIN', 0, '�ɼ��û��ɷ���Ϣ��ɣ�');
  
    -- �����û�������Ϣ
    IF PF_JUDGE_TAB_EXIST(INV_PREBALTAB) = TRUE AND
       PF_JUDGE_TAB_EXIST(INV_AFTBALTAB) = TRUE THEN
    
      V_SQL := 'SELECT count(1) FROM '||INV_PREBALTAB;
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
        
      PP_PRINTLOG(3,
                  'PP_MAIN',
                  0,
                  '[' || INV_PREBALTAB || ']���м�¼��' || V_COUNT);
    
      V_SQL := 'SELECT count(1) FROM '||INV_AFTBALTAB;
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
        
      PP_PRINTLOG(3,
                  'PP_MAIN',
                  0,
                  '[' || INV_AFTBALTAB || ']���м�¼��' || V_COUNT);
    END IF;
  
    PP_PRINTLOG(1, 'PP_MAIN', 0, '��ʼ����ɣ�');
  
    PP_PRINTLOG(1, 'PP_MAIN', 0, '����ִ�����׼���˳����ع�δ�ύ����');
  
    ROLLBACK;
  EXCEPTION
    WHEN EXP_CREATE_TMP_TAB_ERR THEN
      PP_PRINTLOG(1, 'PP_MAIN', -90001, '������ʱ��ʧ�ܣ�');
    WHEN OTHERS THEN
      PP_PRINTLOG(1, 'PP_MAIN', SQLCODE, SQLERRM);
  END;

  -------------------------------------------------------------------------------
  FUNCTION PF_JUDGE_TAB_EXIST(INV_TABLENAME USER_TABLES.TABLE_NAME%TYPE)
    RETURN BOOLEAN IS
    V_SQL VARCHAR2(100);
  BEGIN
    V_SQL := 'SELECT 1 FROM ' || INV_TABLENAME || ' WHERE ROWNUM < 1';
    EXECUTE IMMEDIATE V_SQL;
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      DECLARE
        ERROR_CODE NUMBER := SQLCODE;
      BEGIN
        IF ERROR_CODE = -942 THEN
          PP_PRINTLOG(5,
                      'PF_JUDGE_TAB_EXIST',
                      SQLCODE,
                      '�����ڣ�' || INV_TABLENAME);
          RETURN FALSE;
        ELSE
          RETURN NULL;
        END IF;
      END;
  END;

  -------------------------------------------------------------------------------
  FUNCTION PF_GETLOCALCYCLEID
    RETURN BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE IS
    V_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE;
  BEGIN
  
    SELECT BILLING_CYCLE_ID
      INTO V_BILLINGCYCLEID
      FROM BILLING_CYCLE@LINK_CC
     WHERE ADD_MONTHS(SYSDATE, -1) >= CYCLE_BEGIN_DATE
       AND ADD_MONTHS(SYSDATE, -1) < CYCLE_END_DATE;
  
    PP_PRINTLOG(3,
                'pf_getLocalCycleId',
                0,
                '��ȡ������ID:' || V_BILLINGCYCLEID);
  
    RETURN V_BILLINGCYCLEID;
  
  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
      PP_PRINTLOG(1,
                  'pf_getLocalCycleId',
                  SQLCODE,
                  'BILLING_CYCLE�д������㵱ǰʱ��Ķ�����ڣ����飡');
      RETURN NULL;
    
  END;

  -------------------------------------------------------------------------------
  FUNCTION PF_GET_CYCLEEGINTIME(INV_CYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE)
    RETURN BILLING_CYCLE.CYCLE_BEGIN_DATE@LINK_CC%TYPE IS
    V_BEGIN_DATE BILLING_CYCLE.CYCLE_BEGIN_DATE@LINK_CC%TYPE;
  BEGIN
    SELECT CYCLE_BEGIN_DATE
      INTO V_BEGIN_DATE
      FROM BILLING_CYCLE@LINK_CC
     WHERE BILLING_CYCLE_ID = INV_CYCLEID;
    RETURN V_BEGIN_DATE;
  END;

  -------------------------------------------------------------------------------
  FUNCTION PF_GET_CYCLEENDIME(INV_CYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE)
    RETURN BILLING_CYCLE.CYCLE_END_DATE@LINK_CC%TYPE IS
    V_END_DATE BILLING_CYCLE.CYCLE_END_DATE@LINK_CC%TYPE;
  BEGIN
    SELECT CYCLE_END_DATE
      INTO V_END_DATE
      FROM BILLING_CYCLE@LINK_CC
     WHERE BILLING_CYCLE_ID = INV_CYCLEID;
    RETURN V_END_DATE;
  END;

  -------------------------------------------------------------------------------
  FUNCTION PF_CURR_PROVINCE RETURN CHAR IS
  BEGIN
    RETURN GC_PROVINCE;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_DEL_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                           INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
    IF PF_JUDGE_TAB_EXIST(INV_TABLENAME || INV_BILLINGCYCLEID) = TRUE THEN
      V_SQL := 'truncate table ' || INV_TABLENAME || INV_BILLINGCYCLEID;
      EXECUTE IMMEDIATE V_SQL;
    
      V_SQL := 'drop table ' || INV_TABLENAME || INV_BILLINGCYCLEID;
      EXECUTE IMMEDIATE V_SQL;
    
      IF PF_JUDGE_TAB_EXIST(INV_TABLENAME || INV_BILLINGCYCLEID) = FALSE THEN
        PP_PRINTLOG(3,
                    'PP_DEL_TMP_TAB',
                    SQLCODE,
                    '��ɾ���ɹ���' || INV_TABLENAME || INV_BILLINGCYCLEID);
      END IF;
    ELSE
      PP_PRINTLOG(3,
                  'PP_DEL_TMP_TAB',
                  SQLCODE,
                  '������,����ɾ����' || INV_TABLENAME || INV_BILLINGCYCLEID);
    END IF;
  
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_USERINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                                INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
    --�����û���Ϣ��,���Ҳɼ�����
    V_SQL := 'create table ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              as 
              SELECT S.SUBS_ID,
                     S.ACC_NBR,
                     S.AREA_ID,
                     S.SUBS_CODE,
                     P.PROD_STATE,
                     P.BLOCK_REASON,
                     S.ACCT_ID "credit_acct",
                     SA.ACCT_ID
                FROM SUBS@LINK_CC S, PROD@LINK_CC P, SUBS_ACCT@LINK_CC SA
               WHERE S.SUBS_ID = P.PROD_ID
                 AND S.SUBS_ID = SA.SUBS_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
  
    IF PF_JUDGE_TAB_EXIST(INV_TABLENAME || INV_BILLINGCYCLEID) = TRUE THEN
      PP_PRINTLOG(3,
                  'PP_COLLECT_USERINFO',
                  SQLCODE,
                  '�����ɹ���' || INV_TABLENAME || INV_BILLINGCYCLEID);
    END IF;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_CDR(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                           INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE) IS
    V_SQL       VARCHAR2(4000);
    V_TMP_TABLE USER_TABLES.TABLE_NAME%TYPE := INV_TABLENAME || 'tmp_';
  BEGIN
  
    -- ɾ����ʱ��
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, V_TMP_TABLE);
  
    -- �ֽ��м����ݶ�����tmp��֮���ٹ���INV_TABLENAME
  
    ------------------����/����ҵ��----------------------
    -- ����CDR��,���Ҳɼ�EVNET_USAGE acct_item_type1����
    V_SQL := 'CREATE TABLE ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              AS
              SELECT SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     SUM(DURATION) "DURATION",
                     SUM(BYTE_UP + BYTE_DOWN) "DATA_BYTE",
                     SUM(charge1) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID1 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_USAGE_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID1 != -1
                 AND STATE in (''A'',''C'')
               GROUP BY SUBS_ID,
                        SERVICE_TYPE,
                        RE_ID,
                        ACCT_ITEM_TYPE_ID1
               ';
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
  
    IF PF_JUDGE_TAB_EXIST(V_TMP_TABLE || INV_BILLINGCYCLEID) = TRUE THEN
      PP_PRINTLOG(3,
                  'PP_COLLECT_CDR',
                  SQLCODE,
                  '�����ɹ���' || V_TMP_TABLE || INV_BILLINGCYCLEID);
    
      PP_PRINTLOG(5,
                  'PP_COLLECT_CDR',
                  0,
                  '����EVNET_USAGE acct_item_type1������ɣ�' || V_TMP_TABLE ||
                  INV_BILLINGCYCLEID);
    ELSE
      RAISE EXP_CREATE_TMP_TAB_ERR;
      PP_PRINTLOG(1, 'PP_COLLECT_CDR', -99001, '������ʱ��ʧ�ܣ�');
    END IF;
  
    -- �ɼ�EVNET_USAGE acct_item_type2����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE2) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID2 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_USAGE_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID2 != -1
                 AND STATE in (''A'',''C'')
               GROUP BY SUBS_ID,
                        SERVICE_TYPE,
                        RE_ID,
                        ACCT_ITEM_TYPE_ID2
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVNET_USAGE acct_item_type2������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- �ɼ�EVNET_USAGE acct_item_type3����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE3) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID3 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_USAGE_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID3 != -1
                 AND STATE in (''A'',''C'')
               GROUP BY SUBS_ID,
                        SERVICE_TYPE,
                        RE_ID,
                        ACCT_ITEM_TYPE_ID3
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVNET_USAGE acct_item_type3������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- �ɼ�EVNET_USAGE acct_item_type4����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE4) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID4 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_USAGE_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID4 != -1
                 AND STATE in (''A'',''C'')
               GROUP BY SUBS_ID,
                        SERVICE_TYPE,
                        RE_ID,
                        ACCT_ITEM_TYPE_ID4
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVNET_USAGE acct_item_type4������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------����/��ֵҵ��----------------------
    -- �ɼ�EVNET_USAGE_C acct_item_type1����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     SUM(DURATION) "DURATION",
                     SUM(BYTE_UP + BYTE_DOWN) "DATA_BYTE",
                     SUM(charge1) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID1 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_USAGE_C_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID1 != -1
                 AND STATE in (''A'',''C'')
               GROUP BY SUBS_ID,
                        SERVICE_TYPE,
                        RE_ID,
                        ACCT_ITEM_TYPE_ID1
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVNET_USAGE_C acct_item_type1������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- �ɼ�EVNET_USAGE_C acct_item_type2����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     SUM(DURATION) "DURATION",
                     SUM(BYTE_UP + BYTE_DOWN) "DATA_BYTE",
                     SUM(charge2) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID2 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_USAGE_C_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID2 != -1
                 AND STATE in (''A'',''C'')
               GROUP BY SUBS_ID,
                        SERVICE_TYPE,
                        RE_ID,
                        ACCT_ITEM_TYPE_ID2
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVNET_USAGE_C acct_item_type2������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- �ɼ�EVNET_USAGE_C acct_item_type3����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     SUM(DURATION) "DURATION",
                     SUM(BYTE_UP + BYTE_DOWN) "DATA_BYTE",
                     SUM(charge3) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID3 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_USAGE_C_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID3 != -1
                 AND STATE in (''A'',''C'')
               GROUP BY SUBS_ID,
                        SERVICE_TYPE,
                        RE_ID,
                        ACCT_ITEM_TYPE_ID3
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVNET_USAGE_C acct_item_type3������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- �ɼ�EVNET_USAGE_C acct_item_type4����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     SUM(DURATION) "DURATION",
                     SUM(BYTE_UP + BYTE_DOWN) "DATA_BYTE",
                     SUM(charge4) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID4 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_USAGE_C_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID4 != -1
                 AND STATE in (''A'',''C'')
               GROUP BY SUBS_ID,
                        SERVICE_TYPE,
                        RE_ID,
                        ACCT_ITEM_TYPE_ID4
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVNET_USAGE_C acct_item_type4������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------���ڷ�RECURRING----------------------SERVICE_TYPE = 100
    -- �ɼ�EVENT_RECURRING acct_item_type1����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     100 "SERVICE_TYPE",
                     RE_ID,
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE1) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID1 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_RECURRING_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID1 != -1
                 AND STATE = ''A''
               GROUP BY SUBS_ID,
                     RE_ID,
                     ACCT_ITEM_TYPE_ID1
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVENT_RECURRING acct_item_type1������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- �ɼ�EVENT_RECURRING acct_item_type2����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     100 "SERVICE_TYPE",
                     RE_ID,
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE2) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID2 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_RECURRING_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID2 != -1
                 AND STATE = ''A''
               GROUP BY SUBS_ID,
                     RE_ID,
                     ACCT_ITEM_TYPE_ID2
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVENT_RECURRING acct_item_type2������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- �ɼ�EVENT_RECURRING acct_item_type3����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     100 "SERVICE_TYPE",
                     RE_ID,
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE3) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID3 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_RECURRING_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID3 != -1
                 AND STATE = ''A''
               GROUP BY SUBS_ID,
                     RE_ID,
                     ACCT_ITEM_TYPE_ID3
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVENT_RECURRING acct_item_type3������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- �ɼ�EVENT_RECURRING acct_item_type4����
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     100 "SERVICE_TYPE",
                     RE_ID,
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE4) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID4 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_RECURRING_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID4 != -1
                 AND STATE = ''A''
               GROUP BY SUBS_ID,
                     RE_ID,
                     ACCT_ITEM_TYPE_ID4
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVENT_RECURRING acct_item_type4������ɣ�' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------���ڷ�EVENT_CHARGE----------------------SERVICE_TYPE = 101
    -- ע�⣺��ΪEVENT_CHARGEû��RE_ID����PRICE_ID����
    -- EVENT_CHARGE.STATE:'1'��δ���ʣ�'2'�������У�'3'���ѳ��ʡ�'4'�������ˡ�
    --                    '7'��ע��--instalment state�������ڸ���Ҳʹ�á�
    --                    �����ڸ��������ķ��ڸ��ֻ��һ�ڡ�
    V_SQL := 'insert into ' || V_TMP_TABLE || INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     101 "SERVICE_TYPE",
                     PRICE_ID "RE_ID",
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE) "CHARGE_FEE",
                     ACCT_ITEM_ID "ACCT_ITEM_TYPE_ID"
                FROM EVENT_CHARGE@LINK_CC
               WHERE ACCT_ITEM_ID != -1
                 AND STATE IN (1, 2, 3, 4)
                 AND billing_cycle_id = ' || INV_BILLINGCYCLEID || '
               GROUP BY SUBS_ID,
                     PRICE_ID,
                     ACCT_ITEM_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '����EVENT_CHARGE������ɣ�' || V_TMP_TABLE || INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------���ݺϲ�----------------------
    -- ���ɼ��ĸ������ݽ����ٴκϲ��������ʽCDR��
    V_SQL := 'CREATE TABLE ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              AS
              SELECT SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     SUM(DURATION) "DURATION",
                     SUM(DATA_BYTE) "DATA_BYTE",
                     SUM(CHARGE_FEE) "CHARGE_FEE"
                FROM BALRP_CDR_TMP_' || INV_BILLINGCYCLEID || ' A,
                     ACCT_ITEM_TYPE@LINK_CC B
               WHERE A.ACCT_ITEM_TYPE_ID = B.ACCT_ITEM_TYPE_ID
                 AND B.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
               GROUP BY SUBS_ID, SERVICE_TYPE, RE_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_CDR',
                0,
                '������Ϣ�ռ���ϣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    V_SQL := 'alter table ' || INV_TABLENAME || INV_BILLINGCYCLEID ||
             ' modify RE_ID null';
    EXECUTE IMMEDIATE V_SQL;
  
    ------------------ɾ����ʱ��----------------------
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, V_TMP_TABLE);
  
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_ACCTBOOK(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                                INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE) IS
    V_TMP_ACCTOOK USER_TABLES.TABLE_NAME%TYPE := INV_TABLENAME || 'tmp_';
    V_SQL         VARCHAR2(4000);
    V_BEGIN_DATE  VARCHAR2(20);
    V_END_DATE    VARCHAR2(20);
  BEGIN
    ------------------ɾ����ʱ��----------------------
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, V_TMP_ACCTOOK);
  
    -- ��ȡ���ڿ�ʼ�ͽ���ʱ�䣬��ACCT_BOOK����û�����ڱ�ʶ������Ҫ
    V_BEGIN_DATE := TO_CHAR(PF_GET_CYCLEEGINTIME(INV_BILLINGCYCLEID),
                            'yyyymmddhh24miss');
  
    V_END_DATE := TO_CHAR(PF_GET_CYCLEENDIME(INV_BILLINGCYCLEID),
                          'yyyymmddhh24miss');
  
    -- �Ƚ����������ݣ���ACCT_BOOK_TYPE in ('H', 'P', 'Q', 'V')�����ݷ�����ʱ���Խ���������
    V_SQL := 'CREATE TABLE ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              AS
              SELECT SA.SUBS_ID,
                     AB.ACCT_ID,
                     AB.ACCT_BOOK_TYPE,
                     AB.CREATED_DATE,
                     AB.CONTACT_CHANNEL_ID,
                     AB.PARTY_CODE,
                     SUM(AB.CHARGE) "CHARGE_FEE"
                FROM ACCT_BOOK@LINK_CC AB, SUBS_ACCT@LINK_CC SA
               WHERE ACCT_BOOK_TYPE IN (''H'', ''P'', ''Q'', ''V'')
                 AND AB.ACCT_ID = SA.ACCT_ID
                 AND AB.CREATED_DATE >= to_date(' ||
             V_BEGIN_DATE ||
             ', ''yyyymmddhh24miss'')
                 AND AB.CREATED_DATE < to_date(' || V_END_DATE ||
             ', ''yyyymmddhh24miss'')
                 AND AB.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
               GROUP BY SA.SUBS_ID,
                        AB.ACCT_ID,
                        AB.ACCT_BOOK_TYPE,
                        AB.CREATED_DATE,
                        AB.PARTY_CODE,
                        AB.CONTACT_CHANNEL_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '��������ʱACCT_BOOK������ϣ�' || V_TMP_ACCTOOK ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ����ʱ��������
    V_SQL := 'CREATE INDEX IDX_ACCTBOOKTYPE_1 ON ' || V_TMP_ACCTOOK ||
             INV_BILLINGCYCLEID || '
                           (ACCT_BOOK_TYPE) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_CONTACTCHANNELID_1 ON ' || V_TMP_ACCTOOK ||
             INV_BILLINGCYCLEID || '
                           (CONTACT_CHANNEL_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_ACCTID_1 ON ' || V_TMP_ACCTOOK ||
             INV_BILLINGCYCLEID || '
                           (ACCT_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_PARTYCODE_1 ON ' || V_TMP_ACCTOOK ||
             INV_BILLINGCYCLEID || '
                           (PARTY_CODE) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '��������ʱACCT_BOOK������������ϣ�' || V_TMP_ACCTOOK ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ͳ���û�һ���Է� SERVICE_TYPE = 102
    V_SQL := 'delete from ' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID ||
             ' where SERVICE_TYPE = 102';
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                'ɾ������һ���Է�������ɣ�' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID);
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
  
    V_SQL := 'insert into ' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID || '
                  SELECT SUBS_ID,
                         102 "SERVICE_TYPE",
                         '''' "RE_ID",
                         0 "DURATION",
                         0 "DATA_BYTE",
                         SUM(CHARGE_FEE) "CHARGE_FEE"
                    FROM ' || V_TMP_ACCTOOK ||
             INV_BILLINGCYCLEID || '
                   WHERE ACCT_BOOK_TYPE = ''Q''
                      OR (ACCT_BOOK_TYPE = ''V'' AND CHARGE_FEE > 0)
                   GROUP BY ACCT_ID, SUBS_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '������һ���Էѷ��ò�����ϣ�' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- �����û��ɷ���Ϣͳ�Ʊ�
    -- ͳ���û� �ֽ�ɷ� SERVICE_TYPE = 200
    -- 999001�ǿ���Ԥ��999999��Ԥ��ת�ң������������ļ������ã�
    V_SQL := 'CREATE TABLE ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              AS
              SELECT ACCT_ID, 200 "SERVICE_TYPE", sum(CHARGE_fee) "CHARGE_fee"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
               WHERE CONTACT_CHANNEL_ID = 1
                 AND PARTY_CODE NOT IN (''999001'',''999999'')
                 AND ACCT_BOOK_TYPE IN (''H'',''P'')
                 OR (ACCT_BOOK_TYPE = ''V'' AND  CHARGE_fee < 0)
               GROUP BY ACCT_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�������û��ɷ���Ϣ������ϣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
  
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�����û��ֽ�ɷ���ɣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ͳ���û� һ����ɷ� SERVICE_TYPE = 201
    V_SQL := 'INSERT INTO ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              SELECT ACCT_ID, 201 "SERVICE_TYPE", sum(CHARGE_fee)
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
               WHERE CONTACT_CHANNEL_ID = 4
                 AND ACCT_BOOK_TYPE IN (''H'',''P'')
                  OR (ACCT_BOOK_TYPE = ''V'' AND  CHARGE_fee < 0)
               GROUP BY ACCT_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�����û�һ����ɷ�������ɣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ͳ���û� ����Ԥ��� SERVICE_TYPE = 202
    V_SQL := 'INSERT INTO ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              SELECT ACCT_ID, 202 "SERVICE_TYPE", sum(CHARGE_fee)
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
               WHERE CONTACT_CHANNEL_ID = 1
                 AND PARTY_CODE = ''999001''
                 AND ACCT_BOOK_TYPE IN (''H'',''P'')
                  OR (ACCT_BOOK_TYPE = ''V'' AND  CHARGE_fee < 0)
               GROUP BY ACCT_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�����û�����Ԥ���������ɣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ͳ���û� ���п���ֵ SERVICE_TYPE = 203
    V_SQL := 'INSERT INTO ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              SELECT ACCT_ID, 203 "SERVICE_TYPE", sum(CHARGE_fee)
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
               WHERE CONTACT_CHANNEL_ID = 10
                 AND ACCT_BOOK_TYPE IN (''H'',''P'')
                  OR (ACCT_BOOK_TYPE = ''V'' AND  CHARGE_fee < 0)
               GROUP BY ACCT_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�����û����п���ֵ������ɣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ͳ���û� ���г�ֵ SERVICE_TYPE = 204
    V_SQL := 'INSERT INTO ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              SELECT ACCT_ID, 204 "SERVICE_TYPE", sum(CHARGE_fee)
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
               WHERE CONTACT_CHANNEL_ID = 7
                 AND ACCT_BOOK_TYPE IN (''H'',''P'')
                  OR (ACCT_BOOK_TYPE = ''V'' AND  CHARGE_fee < 0)
               GROUP BY ACCT_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�����û����г�ֵ������ɣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------ɾ����ʱ��----------------------
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, V_TMP_ACCTOOK);
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_BALINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                               INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE) IS
  BEGIN
    NULL;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_PRINTLOG(INV_LOGLEVEL  NUMBER,
                        INV_FUNCNAME  VARCHAR2,
                        INV_LOGERRNUM VARCHAR2,
                        INV_LOGTXT    VARCHAR2) IS
    V_CURTIME CHAR(14);
    V_SQL     VARCHAR2(1000);
  BEGIN
    IF GC_LOGING_LEVEL >= INV_LOGLEVEL THEN
      SELECT TO_CHAR(SYSDATE, 'yyyymmddhh24miss') INTO V_CURTIME FROM DUAL;
    
      DBMS_OUTPUT.PUT_LINE(V_CURTIME || '[LOG_' || INV_LOGLEVEL || '|' ||
                           INV_LOGERRNUM || '|' || INV_FUNCNAME || ']' ||
                           INV_LOGTXT);
    
      V_SQL := 'insert into ' || GC_PROC_LOG || '
              values ( to_date(''' || V_CURTIME ||
               ''',''yyyymmddhh24miss''),
                       ' || INV_LOGLEVEL || ',
                       ''' || INV_FUNCNAME || ''',
                       ' || INV_LOGERRNUM || ',
                       ''' || INV_LOGTXT || ''')';
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    END IF;
  END;

BEGIN
  DBMS_OUTPUT.ENABLE(BUFFER_SIZE => NULL);

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SQLCODE=' || SQLCODE);
    DBMS_OUTPUT.PUT_LINE('SQLERRM=' || SQLERRM);
END BALRP_PKG_FOR_CUC;
/
