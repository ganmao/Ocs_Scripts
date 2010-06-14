CREATE OR REPLACE PACKAGE BALRP_PKG_FOR_CUC IS

  -- Author  : zhang.dongliang@zte.com.cn
  -- Created : 2010-06-03 13:33:33
  -- Purpose : the balance report for CUC

  -- ==================================================
  -- ���²�����Ҫ�ֳ���������Լ�����
  -- ==================================================
  -- ��������ʹ�õ���
  -- �ӱ�(HB)��ɽ��(SD)������(NM)������(GS)
  GC_PROVINCE CONSTANT CHAR(2) := 'HB';

  -- ��Ҫͳ�Ƶ��������
  GC_RES_TYPE CONSTANT VARCHAR2(100) := '52';

  -- ָ������CPU��,Σ�ղ�������Ҫ�����ֳ�cpu�������ã�һ��Ϊcpu������
  GC_CPU_NUM CONSTANT NUMBER := 24;

  -- �����м�����ʹ�ú��Ƿ�ɾ��(TRUE|FALSE)
  GC_TMP_TABLE_DEL CONSTANT BOOLEAN := FALSE;

  -- �����Ƿ��������ݲɼ��׶�ֱ�ӽ��б������(TRUE|FALSE)
  GC_JUMP_COLLECT CONSTANT BOOLEAN := FALSE;

  -- ������־�ȼ�
  GC_LOGING_LEVEL CONSTANT NUMBER := 5;

  -- ���ձ����ű�
  GC_REPORT_TAB CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_report_tab_';

  -- ��־��Ϣ��
  GC_PROC_LOG CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_proc_log';

  -- �û���Ϣ�м��
  GC_USER_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_user_';

  -- �����м��
  GC_CDR_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_cdr_';

  -- ACCT_BOOK�м��
  GC_ACCTBOOK_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_acctbook_';

  -- ����Ϣ�м��
  GC_BAL_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_bal_';

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
    RETURN NUMBER;

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
                               INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE,
                               INV_TBAL_A         USER_TABLES.TABLE_NAME%TYPE,
                               INV_TBAL_B         USER_TABLES.TABLE_NAME%TYPE);

  -- ���ݸ����������ɲ�ͬͳ�Ʊ���
  PROCEDURE PP_BUILD_REPORT(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

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
    V_SQL            VARCHAR2(1000);
  BEGIN
    DBMS_OUTPUT.PUT_LINE('��ʼ���ô洢����[balrp_pkg_for_cuc.pp_main]����ϸ��־�����' ||
                         GC_PROC_LOG || ',�����������' || GC_REPORT_TAB ||
                         V_BILLINGCYCLEID);
    --EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
    -- �ж���־��Ϣ���Ƿ����
    -- ��������־��Ϣ������н���
    IF PF_JUDGE_TAB_EXIST(GC_PROC_LOG) = 0 THEN
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
    PP_PRINTLOG(3, 'PP_MAIN', 0, '��ʼ�ɼ��û���Ϣ...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
    PP_COLLECT_USERINFO(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
    PP_PRINTLOG(3, 'PP_MAIN', 0, '�ɼ��û���Ϣ��ɣ�');
  
    -- �ɼ��û���������
    PP_PRINTLOG(3, 'PP_MAIN', 0, '��ʼ�ɼ�CDR��Ϣ...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_CDR_TAB_NAME);
    PP_COLLECT_CDR(V_BILLINGCYCLEID, GC_CDR_TAB_NAME);
    PP_PRINTLOG(3, 'PP_MAIN', 0, '�ɼ�CDR��Ϣ��ɣ�');
  
    -- �ɼ��û��ɷ���Ϣ
    PP_PRINTLOG(3, 'PP_MAIN', 0, '��ʼ�ɼ��û��ɷ���Ϣ...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME);
    PP_COLLECT_ACCTBOOK(V_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME);
    PP_PRINTLOG(3, 'PP_MAIN', 0, '�ɼ��û��ɷ���Ϣ��ɣ�');
  
    -- �ɼ��û�������Ϣ
    -- ɾ���³������Ϣ��
    PP_PRINTLOG(3, 'PP_MAIN', 0, '��ʼ�ɼ��û������Ϣ...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_BAL_TAB_NAME || 'A_');
    -- ɾ����ĩ�����Ϣ��
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_BAL_TAB_NAME || 'B_');
    PP_COLLECT_BALINFO(V_BILLINGCYCLEID,
                       GC_BAL_TAB_NAME,
                       INV_PREBALTAB,
                       INV_AFTBALTAB);
    PP_PRINTLOG(3, 'PP_MAIN', 0, '�ɼ��û������Ϣ��ɣ�');
  
    PP_PRINTLOG(1, 'PP_MAIN', 0, '��ʼ����ɣ�');
  
    -- ��ʼ���ɱ���
    PP_PRINTLOG(3, 'PP_MAIN', 0, '��ʼ���ɱ���...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_REPORT_TAB);
    PP_BUILD_REPORT(V_BILLINGCYCLEID);
    PP_PRINTLOG(3,
                'PP_MAIN',
                0,
                '�û�����������ϣ�����' || GC_REPORT_TAB || V_BILLINGCYCLEID);
    COMMIT;
  
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
    RETURN NUMBER IS
    V_SQL      VARCHAR2(100);
    V_TABLENUM NUMBER(1);
  BEGIN
    /*    V_SQL := 'SELECT 1 FROM ' || INV_TABLENAME || ' WHERE ROWNUM < 1';
    EXECUTE IMMEDIATE V_SQL;
    RETURN TRUE;*/
  
    V_SQL := 'SELECT count(1) FROM  user_tables where table_name = upper(''' ||
             INV_TABLENAME || ''')';
    EXECUTE IMMEDIATE V_SQL
      INTO V_TABLENUM;
  
    IF V_TABLENUM = 1 THEN
      RETURN 1;
    ELSE
      RETURN 0;
      PP_PRINTLOG(5,
                  'PF_JUDGE_TAB_EXIST',
                  -942,
                  '�����ڣ�' || INV_TABLENAME);
    END IF;
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
    IF PF_JUDGE_TAB_EXIST(INV_TABLENAME || INV_BILLINGCYCLEID) = 1 THEN
      V_SQL := 'truncate table ' || INV_TABLENAME || INV_BILLINGCYCLEID;
      EXECUTE IMMEDIATE V_SQL;
    
      V_SQL := 'drop table ' || INV_TABLENAME || INV_BILLINGCYCLEID;
      EXECUTE IMMEDIATE V_SQL;
    
      IF PF_JUDGE_TAB_EXIST(INV_TABLENAME || INV_BILLINGCYCLEID) = 0 THEN
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
              NOLOGGING
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
  
    IF PF_JUDGE_TAB_EXIST(INV_TABLENAME || INV_BILLINGCYCLEID) = 1 THEN
      PP_PRINTLOG(3,
                  'PP_COLLECT_USERINFO',
                  SQLCODE,
                  '�����ɹ���' || INV_TABLENAME || INV_BILLINGCYCLEID);
    
      -- ����������
      V_SQL := 'CREATE INDEX IDX_balrp_usr_sub' || INV_BILLINGCYCLEID ||
               ' ON ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      PP_PRINTLOG(5,
                  'PP_COLLECT_USERINFO',
                  SQLCODE,
                  '�����������ɹ���' || INV_TABLENAME || INV_BILLINGCYCLEID);
    
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
              NOLOGGING
              AS
              SELECT /*+ PARALLEL(EVENT_USAGE_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
  
    IF PF_JUDGE_TAB_EXIST(V_TMP_TABLE || INV_BILLINGCYCLEID) = 1 THEN
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_C_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_C_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_C_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_C_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_RECURRING_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_RECURRING_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_RECURRING_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_RECURRING_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
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
              NOLOGGING
              AS
              SELECT /*+ PARALLEL(' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */  A.SUBS_ID,
                     C.AREA_ID,
                     A.SERVICE_TYPE,
                     A.RE_ID,
                     SUM(A.DURATION) "DURATION",
                     SUM(A.DATA_BYTE) "DATA_BYTE",
                     SUM(A.CHARGE_FEE) "CHARGE_FEE"
                FROM ' || V_TMP_TABLE || INV_BILLINGCYCLEID || ' A,
                     ACCT_ITEM_TYPE@LINK_CC B,
                     ' || GC_USER_TAB_NAME ||
             INV_BILLINGCYCLEID || ' C
               WHERE A.ACCT_ITEM_TYPE_ID = B.CU_AIT_ID
                 AND B.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
                 AND A.SUBS_ID = C.SUBS_ID
               GROUP BY C.AREA_ID,A.SUBS_ID, A.SERVICE_TYPE, A.RE_ID
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
  
    -- ����������
    V_SQL := 'CREATE INDEX IDX_balrp_cdr_sub' || INV_BILLINGCYCLEID ||
             ' ON ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                SQLCODE,
                '�����������ɹ���' || INV_TABLENAME || INV_BILLINGCYCLEID);
  
    ------------------ɾ����ʱ��----------------------
    --PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, V_TMP_TABLE);
  
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
              NOLOGGING
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
    V_SQL := 'CREATE INDEX IDX_ACCTBOOKTYPE_1' || INV_BILLINGCYCLEID ||
             ' ON ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
                           (ACCT_BOOK_TYPE) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_CONTACTCHANNELID_1' || INV_BILLINGCYCLEID ||
             ' ON ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
                           (CONTACT_CHANNEL_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_ACCTID_1' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
                           (ACCT_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_PARTYCODE_1' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
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
  
    V_SQL := 'insert /*+ APPEND */ into ' || GC_CDR_TAB_NAME ||
             INV_BILLINGCYCLEID || '
                  SELECT A.SUBS_ID,
                         U.AREA_ID,
                         102 "SERVICE_TYPE",
                         '''' "RE_ID",
                         0 "DURATION",
                         0 "DATA_BYTE",
                         SUM(A.CHARGE_FEE) "CHARGE_FEE"
                    FROM ' || V_TMP_ACCTOOK ||
             INV_BILLINGCYCLEID || ' A,
             ' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
                   WHERE (A.ACCT_BOOK_TYPE = ''Q''
                      OR (A.ACCT_BOOK_TYPE = ''V'' AND A.CHARGE_FEE > 0))
                     AND A.SUBS_ID = U.SUBS_ID
                   GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID
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
    -- ���ڽ�999999�����Ƚ��ɷ�ͳ����,�ֳ����Ը���������ͽ����޳�
    V_SQL := 'CREATE TABLE ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              NOLOGGING
              AS
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, 200 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
             ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 1
                 AND (A.PARTY_CODE != ''999001'' OR A.PARTY_CODE IS NULL)
                 AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR  (A.ACCT_BOOK_TYPE = ''V'' AND  A.CHARGE_fee < 0))
                 AND A.SUBS_ID = U.SUBS_ID
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID
               ';
    --dbms_output.put_line('V_SQL='||V_SQL);
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
    V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
             INV_BILLINGCYCLEID || '
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, 201 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
             ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 4
                 AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR (A.ACCT_BOOK_TYPE = ''V'' AND A. CHARGE_fee < 0))
                 AND A.SUBS_ID = U.SUBS_ID
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�����û�һ����ɷ�������ɣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ͳ���û� ����Ԥ��� SERVICE_TYPE = 202
    V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
             INV_BILLINGCYCLEID || '
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, 202 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
             ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 1
                 AND A.PARTY_CODE = ''999001''
                 AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR (A.ACCT_BOOK_TYPE = ''V'' AND A. CHARGE_fee < 0))
                 AND A.SUBS_ID = U.SUBS_ID
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID
               ';
  
    IF GC_PROVINCE = 'SD' THEN
      V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
               INV_BILLINGCYCLEID || '
                SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, 202 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                  FROM ' || V_TMP_ACCTOOK ||
               INV_BILLINGCYCLEID || ' A,' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || ' U
                 WHERE A.CONTACT_CHANNEL_ID = 1
                   AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR (A.ACCT_BOOK_TYPE = ''V'' AND A. CHARGE_fee < 0))
                   AND A.PARTY_CODE IS NOT NULL
                   AND A.SUBS_ID = U.SUBS_ID
                   --AND A.ACCT_RES_ID IN (''1'', ''32'')
                 GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID
                 ';
    END IF;
    --dbms_output.put_line('V_SQL='||V_SQL);
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�����û�����Ԥ���������ɣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ͳ���û� ���п���ֵ SERVICE_TYPE = 203
    V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
             INV_BILLINGCYCLEID || '
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, 203 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
             ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 10
                 AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR (A.ACCT_BOOK_TYPE = ''V'' AND  A.CHARGE_fee < 0))
                 AND A.SUBS_ID = U.SUBS_ID
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�����û����п���ֵ������ɣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ͳ���û� ���г�ֵ SERVICE_TYPE = 204
    V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
             INV_BILLINGCYCLEID || '
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, 204 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
             ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 7
                 AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR (A.ACCT_BOOK_TYPE = ''V'' AND  A.CHARGE_fee < 0))
                 AND A.SUBS_ID = U.SUBS_ID
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '�����û����г�ֵ������ɣ�' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- ����������
    V_SQL := 'CREATE INDEX IDX_balrp_acct_sub' || INV_BILLINGCYCLEID ||
             ' ON ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_acct_s' || INV_BILLINGCYCLEID ||
             ' ON ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (SERVICE_TYPE) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    PP_PRINTLOG(5,
                'PP_COLLECT_ACCTBOOK',
                SQLCODE,
                '�����������ɹ���' || INV_TABLENAME || INV_BILLINGCYCLEID);
  
    ------------------ɾ����ʱ��----------------------
    --PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, V_TMP_ACCTOOK);
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_BALINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                               INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE,
                               INV_TBAL_A         USER_TABLES.TABLE_NAME%TYPE,
                               INV_TBAL_B         USER_TABLES.TABLE_NAME%TYPE) IS
    V_SQL   VARCHAR2(1000);
    V_COUNT NUMBER(10);
  BEGIN
    IF PF_JUDGE_TAB_EXIST(INV_TBAL_A) = 1 AND
       PF_JUDGE_TAB_EXIST(INV_TBAL_B) = 1 THEN
    
      V_SQL := 'SELECT count(1) FROM ' || INV_TBAL_A;
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
    
      PP_PRINTLOG(3,
                  'PP_COLLECT_BALINFO',
                  0,
                  '[' || INV_TBAL_A || ']���м�¼��' || V_COUNT);
    
      -- ����A����м��ɸѡ���ݣ�
      V_SQL := 'CREATE TABLE ' || INV_TABLENAME || 'A_' ||
               INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT SA.SUBS_ID,
                       U.AREA_ID,
                       B.ACCT_ID,
                       SUM(B.GROSS_BAL) "GROSS_BAL",
                       SUM(B.RESERVE_BAL) "RESERVE_BAL",
                       SUM(B.CONSUME_BAL) "CONSUME_BAL"
                  FROM ' || INV_TBAL_A ||
               ' B, SUBS_ACCT@LINK_CC SA, ' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || ' U
                 WHERE B.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
                   AND B.ACCT_ID = SA.ACCT_ID(+)
                   AND SA.SUBS_ID = U.SUBS_ID
                 GROUP BY B.ACCT_ID, SA.SUBS_ID, U.AREA_ID
                ';
      EXECUTE IMMEDIATE V_SQL;
      PP_PRINTLOG(3,
                  'PP_COLLECT_BALINFO',
                  0,
                  '�û��³���Ϣ���ռ���ɣ�' || INV_TABLENAME || 'A_' ||
                  INV_BILLINGCYCLEID);
      COMMIT;
    
      V_SQL := 'SELECT count(1) FROM ' || INV_TBAL_B;
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
    
      PP_PRINTLOG(3,
                  'PP_COLLECT_BALINFO',
                  0,
                  '[' || INV_TBAL_B || ']���м�¼��' || V_COUNT);
    
      -- ����B����м��ɸѡ���ݣ�
      V_SQL := 'CREATE TABLE ' || INV_TABLENAME || 'B_' ||
               INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT SA.SUBS_ID,
                       U.AREA_ID,
                       B.ACCT_ID,
                       SUM(B.GROSS_BAL) "GROSS_BAL",
                       SUM(B.RESERVE_BAL) "RESERVE_BAL",
                       SUM(B.CONSUME_BAL) "CONSUME_BAL"
                  FROM ' || INV_TBAL_B ||
               ' B, SUBS_ACCT@LINK_CC SA, ' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || ' U
                 WHERE B.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
                   AND B.ACCT_ID = SA.ACCT_ID(+)
                   AND SA.SUBS_ID = U.SUBS_ID
                 GROUP BY B.ACCT_ID, SA.SUBS_ID, U.AREA_ID
                ';
      EXECUTE IMMEDIATE V_SQL;
      PP_PRINTLOG(3,
                  'PP_COLLECT_BALINFO',
                  0,
                  '�û���ĩ��Ϣ���ռ���ɣ�' || INV_TABLENAME || 'B_' ||
                  INV_BILLINGCYCLEID);
      COMMIT;
    
      -- ��������
      V_SQL := 'CREATE INDEX IDX_balrp_bal_suba' || INV_BILLINGCYCLEID ||
               ' ON ' || INV_TABLENAME || 'A_' || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      V_SQL := 'CREATE INDEX IDX_balrp_bal_subb' || INV_BILLINGCYCLEID ||
               ' ON ' || INV_TABLENAME || 'B_' || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      PP_PRINTLOG(5,
                  'PP_COLLECT_BALINFO',
                  SQLCODE,
                  '�����������ɹ���' || INV_TABLENAME || INV_BILLINGCYCLEID);
    ELSE
      PP_PRINTLOG(1,
                  'PP_COLLECT_BALINFO',
                  SQLCODE,
                  '����������Ϣ�����ڣ�A=' || INV_TBAL_A || ' B=' || INV_TBAL_B);
    END IF;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_BUILD_REPORT(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
  
    -- ��ʼ�������ɱ���
    IF GC_PROVINCE = 'NM' THEN
      V_SQL := 'CREATE TABLE ' || GC_REPORT_TAB || INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT U.ACC_NBR "�û�����",
                       U.AREA_ID "����ID",
                       U.SUBS_CODE "�û���ʶ",
                       SUM(B1.GROSS_BAL + B1.RESERVE_BAL + B1.CONSUME_BAL) "�³����",
                       SUM(A.CHARGE_FEE) "���³�ֵ",
                       SUM(C.CHARGE_FEE) "��������",
                       SUM(B2.GROSS_BAL + B1.RESERVE_BAL + B1.CONSUME_BAL) "��ĩ���"
                  FROM ' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || '        U,
                       ' || GC_BAL_TAB_NAME || 'A_' ||
               INV_BILLINGCYCLEID || ' B1,
                       ' || GC_ACCTBOOK_TAB_NAME ||
               INV_BILLINGCYCLEID || '    A,
                       ' || GC_CDR_TAB_NAME ||
               INV_BILLINGCYCLEID || '         C,
                       ' || GC_BAL_TAB_NAME || 'B_' ||
               INV_BILLINGCYCLEID || ' B2
                 WHERE U.SUBS_ID = B1.SUBS_ID
                   AND U.SUBS_ID = A.SUBS_ID
                   AND U.SUBS_ID = C.SUBS_ID
                   AND U.SUBS_ID = B2.SUBS_ID
                 GROUP BY U.ACC_NBR, U.AREA_ID, U.SUBS_CODE
                ';
    
    ELSIF GC_PROVINCE = 'SD' THEN
      V_SQL := 'CREATE TABLE ' || GC_REPORT_TAB || INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT ' || INV_BILLINGCYCLEID ||
               ' "�����·�",
                       A.AREA_ID "���б���",
                       NVL(ABS(SUM(B1.CHARGE_FEE)),0) "�ڳ�",
                       NVL(ABS(SUM(A1.CHARGE_FEE)),0) "�ֽ�ɷ�",
                       NVL(ABS(SUM(A2.CHARGE_FEE)),0) "����Ԥ���",
                       NVL(ABS(SUM(A3.CHARGE_FEE)),0) "һ����",
                       NVL(ABS(SUM(A4.CHARGE_FEE)),0) "���г�ֵ",
                       NVL(ABS(SUM(C.CHARGE_FEE)),0) "���ڼ���",
                       NVL(ABS(SUM(B2.CHARGE_FEE)),0) "��ĩ���",
                       NVL(ABS(SUM(B3.CHARGE_FEE)),0) "��ĩ������",
                       NVL(ABS(SUM(B4.CHARGE_FEE)),0) "��ĩ������",
                       NVL((ABS(SUM(B2.CHARGE_FEE)) - ABS(SUM(B3.CHARGE_FEE)) +
                       ABS(SUM(B4.CHARGE_FEE))),0) "У��"
                  FROM AREA@LINK_CC A,
                       (SELECT AREA_ID, SUM(CHARGE_FEE) "CHARGE_FEE"
                          FROM ' || GC_ACCTBOOK_TAB_NAME ||
               INV_BILLINGCYCLEID || '
                         WHERE SERVICE_TYPE = 200
                            OR SERVICE_TYPE = 203
                         GROUP BY AREA_ID) A1,
                       (SELECT AREA_ID, SUM(CHARGE_FEE) "CHARGE_FEE"
                          FROM ' || GC_ACCTBOOK_TAB_NAME ||
               INV_BILLINGCYCLEID || '
                         WHERE SERVICE_TYPE = 202
                         GROUP BY AREA_ID) A2,
                       (SELECT AREA_ID, SUM(CHARGE_FEE) "CHARGE_FEE"
                          FROM ' || GC_ACCTBOOK_TAB_NAME ||
               INV_BILLINGCYCLEID || '
                         WHERE SERVICE_TYPE = 201
                         GROUP BY AREA_ID) A3,
                       (SELECT AREA_ID, SUM(CHARGE_FEE) "CHARGE_FEE"
                          FROM ' || GC_ACCTBOOK_TAB_NAME ||
               INV_BILLINGCYCLEID || '
                         WHERE SERVICE_TYPE = 204
                         GROUP BY AREA_ID) A4,
                       (SELECT AREA_ID, SUM(CHARGE_FEE) "CHARGE_FEE"
                          FROM ' || GC_CDR_TAB_NAME ||
               INV_BILLINGCYCLEID || '
                         GROUP BY AREA_ID) C,
                       (SELECT AREA_ID,
                               SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) "CHARGE_FEE"
                          FROM ' || GC_BAL_TAB_NAME || 'A_' ||
               INV_BILLINGCYCLEID || '
                         GROUP BY AREA_ID) B1,
                       (SELECT AREA_ID,
                               SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) "CHARGE_FEE"
                          FROM ' || GC_BAL_TAB_NAME || 'B_' ||
               INV_BILLINGCYCLEID || '
                         GROUP BY AREA_ID) B2,
                       (SELECT AREA_ID,
                               SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) "CHARGE_FEE"
                          FROM ' || GC_BAL_TAB_NAME || 'B_' ||
               INV_BILLINGCYCLEID || '
                         WHERE (GROSS_BAL + RESERVE_BAL + CONSUME_BAL) < 0
                         GROUP BY AREA_ID) B3,
                       (SELECT AREA_ID,
                               SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) "CHARGE_FEE"
                          FROM ' || GC_BAL_TAB_NAME || 'B_' ||
               INV_BILLINGCYCLEID || '
                         WHERE (GROSS_BAL + RESERVE_BAL + CONSUME_BAL) > 0
                         GROUP BY AREA_ID) B4
                 WHERE A.AREA_ID = B1.AREA_ID(+)
                   AND A.AREA_ID = B2.AREA_ID(+)
                   AND A.AREA_ID = C.AREA_ID(+)
                   AND A.AREA_ID = A1.AREA_ID(+)
                   AND A.AREA_ID = A2.AREA_ID(+)
                   AND A.AREA_ID = A3.AREA_ID(+)
                   AND A.AREA_ID = A4.AREA_ID(+)
                   AND A.AREA_ID = B3.AREA_ID(+)
                   AND A.AREA_ID = B4.AREA_ID(+)
                 GROUP BY A.AREA_ID
                ';
    
    ELSIF GC_PROVINCE = 'HB' THEN
      -- ���С����롢�³������г�ֵ���������ѡ���ĩ��
      -- �³����+���г�ֵ-��������=��ĩ���
      NULL;
      V_SQL := 'CREATE TABLE ' || GC_REPORT_TAB || INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT U.ACC_NBR "�û�����",
                       U.AREA_ID "����",
                       NVL(SUM(BA.GROSS_BAL + BA.RESERVE_BAL + BA.CONSUME_BAL), 0) "�³����",
                       NVL(SUM(A.CHARGE_FEE), 0) "���г�ֵ",
                       NVL(SUM(C.CHARGE_FEE), 0) "��������",
                       NVL(SUM(BB.GROSS_BAL + BB.RESERVE_BAL + BB.CONSUME_BAL), 0) "��ĩ���",
                       NVL((SUM(BA.GROSS_BAL + BA.RESERVE_BAL + BA.CONSUME_BAL) +
                           SUM(A.CHARGE_FEE) - SUM(C.CHARGE_FEE)),
                           0) "��ĩ���У��"
                  FROM ' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || '     U,
                       ' || GC_BAL_TAB_NAME || 'A_' ||
               INV_BILLINGCYCLEID || '    BA,
                       ' || GC_ACCTBOOK_TAB_NAME ||
               INV_BILLINGCYCLEID || ' A,
                       ' || GC_CDR_TAB_NAME ||
               INV_BILLINGCYCLEID || '      C,
                       ' || GC_BAL_TAB_NAME || 'B_' ||
               INV_BILLINGCYCLEID ||
               '    BB
                 WHERE U.SUBS_ID = BA.SUBS_ID(+)
                   AND U.SUBS_ID = BA.SUBS_ID(+)
                   AND U.SUBS_ID = A.SUBS_ID(+)
                   AND U.SUBS_ID = C.SUBS_ID(+)
                   AND U.SUBS_ID = BB.SUBS_ID(+)
                 GROUP BY U.ACC_NBR, U.AREA_ID';
    
    ELSIF GC_PROVINCE = 'GS' THEN
      NULL;
    END IF;
  
    DBMS_OUTPUT.PUT_LINE('V_SQL=' || V_SQL);
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
  
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
  --����DML��CPU
  EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SQLCODE=' || SQLCODE);
    DBMS_OUTPUT.PUT_LINE('SQLERRM=' || SQLERRM);
END BALRP_PKG_FOR_CUC;
/
