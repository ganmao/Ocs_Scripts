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

  -- �����м�����ʹ�ú��Ƿ�ɾ��(TRUE|FALSE)
  GC_TMP_TABLE_DEL CONSTANT BOOLEAN := FALSE;

  -- �����Ƿ��������ݲɼ��׶�ֱ�ӽ��б������(TRUE|FALSE)
  GC_JUMP_COLLECT CONSTANT BOOLEAN := FALSE;

  -- ������־�ȼ�
  GC_LOGING_LEVEL CONSTANT NUMBER := 5;
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

  -- ��ȡϵͳ��ǰʱ������ID
  FUNCTION PF_GETLOCALCYCLEID
    RETURN BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE;

  -- �������
  -- ==================================================
  -- ���̵�������
  PROCEDURE PP_MAIN;

  -- ��ʼ�������������ڵ��м���
  PROCEDURE PP_CREATE_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

  -- ��ʼ������ձ������ݣ��ڽ����м���ʱ����

  -- ɾ�������ڵ��м���
  PROCEDURE PP_DEL_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

  -- �ɼ��û���Ϣ�������û���Ϣ������
  PROCEDURE PP_COLLECT_USERINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

  -- �ɼ����������࣬��������
  PROCEDURE PP_COLLECT_CDR(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

  -- �������������Ϣ����������
  PROCEDURE PP_COLLECT_BALINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

  PROCEDURE PP_PRINTLOG(INV_LOGLEVEL  NUMBER,
                        INV_FUNCNAME  VARCHAR2,
                        INV_LOGERRNUM VARCHAR2,
                        IN_LOGTXT     VARCHAR2);

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
  PROCEDURE PP_MAIN IS
    V_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE;
  BEGIN
    --��ʼ��
    PP_PRINTLOG(3, 'PP_MAIN', '00001', '��ʼ���г�ʼ����');
  
    -- ��ȡ������������ID
    V_BILLINGCYCLEID := PF_GETLOCALCYCLEID();
    
    -- �����м���
    -- PP_CREATE_TMP_TAB(V_BILLINGCYCLEID);
    PP_PRINTLOG(3, 'PP_MAIN', '00003', '�����м����ɣ�');
    
    PP_PRINTLOG(3, 'PP_MAIN', '10000', '��ʼ����ɣ�');
  
    -- �ɼ��û���Ϣ����
    PP_COLLECT_USERINFO(V_BILLINGCYCLEID);
  
    PP_PRINTLOG(3,
                'PP_MAIN',
                '90001',
                '����ִ�����׼���˳����ع�δ�ύ����');
    ROLLBACK;
  EXCEPTION
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
     WHERE SYSDATE >= CYCLE_BEGIN_DATE
       AND SYSDATE < CYCLE_END_DATE;
  
    PP_PRINTLOG(3,
                'pf_getLocalCycleId',
                '00000',
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
  PROCEDURE PP_CREATE_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
    --�����û���Ϣ��
    V_SQL := 'create table balrp_userInfo_' || INV_BILLINGCYCLEID || '(
                area_id number(6),
                acc_nbr VARCHAR2(60),
                SUBS_CODE VARCHAR2(30),
                SUBS_ID NUMBER(9),
                ACCT_ID NUMBER(9),
                PROD_STATE CHAR(1),
                BLOCK_REASON VARCHAR2(60)
              )';
    EXECUTE IMMEDIATE V_SQL;
  
    IF PF_JUDGE_TAB_EXIST('balrp_userInfo_' || INV_BILLINGCYCLEID) = TRUE THEN
      PP_PRINTLOG(3,
                  'PP_CREATE_TMP_TAB',
                  SQLCODE,
                  '�����ɹ���balrp_userInfo_' || INV_BILLINGCYCLEID);
    END IF;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_DEL_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
    V_SQL := 'drop table balrp_userInfo_' || INV_BILLINGCYCLEID;
    EXECUTE IMMEDIATE V_SQL;
  
    IF PF_JUDGE_TAB_EXIST('balrp_userInfo_' || INV_BILLINGCYCLEID) = FALSE THEN
      PP_PRINTLOG(3,
                  'PP_CREATE_TMP_TAB',
                  SQLCODE,
                  '��ɾ���ɹ���balrp_userInfo_' || INV_BILLINGCYCLEID);
    END IF;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_USERINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE) IS
  BEGIN
    NULL;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_CDR(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE) IS
  BEGIN
    NULL;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_BALINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE) IS
  BEGIN
    NULL;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_PRINTLOG(INV_LOGLEVEL  NUMBER,
                        INV_FUNCNAME  VARCHAR2,
                        INV_LOGERRNUM VARCHAR2,
                        IN_LOGTXT     VARCHAR2) IS
    V_CURTIME CHAR(14);
  BEGIN
    IF GC_LOGING_LEVEL >= INV_LOGLEVEL THEN
      SELECT TO_CHAR(SYSDATE, 'yyyymmddhh24miss') INTO V_CURTIME FROM DUAL;
    
      DBMS_OUTPUT.PUT_LINE(V_CURTIME || '[LOG_' || INV_LOGLEVEL || '|' ||
                           INV_LOGERRNUM || '|' || INV_FUNCNAME || ']' ||
                           IN_LOGTXT);
    END IF;
  END;

BEGIN
  -- Initialization
  DBMS_OUTPUT.ENABLE(BUFFER_SIZE => NULL);

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SQLCODE=' || SQLCODE);
    DBMS_OUTPUT.PUT_LINE('SQLERRM=' || SQLERRM);
END BALRP_PKG_FOR_CUC;
/
