CREATE OR REPLACE PACKAGE BALRP_PKG_FOR_CUC IS

  -- Author  : zhang.dongliang@zte.com.cn
  -- Created : 2010-06-03 13:33:33
  -- Purpose : the balance report for CUC

  -- ==================================================
  -- 以下部分需要现场根据情况自己配置
  -- ==================================================
  -- 定义具体的使用地市
  -- 河北(HB)，山东(SD)，内蒙(NM)，甘肃(GS)
  GC_PROVINCE CONSTANT CHAR(2) := 'SD';

  -- 定义中间层表在使用后是否删除(TRUE|FALSE)
  GC_TMP_TABLE_DEL CONSTANT BOOLEAN := FALSE;

  -- 定义是否跳过数据采集阶段直接进行报表输出(TRUE|FALSE)
  GC_JUMP_COLLECT CONSTANT BOOLEAN := FALSE;

  -- 定义日志等级
  GC_LOGING_LEVEL CONSTANT NUMBER := 5;
  -- ==================================================

  /*
  定义说明：
     带 p 前缀的均为公共的类型、常量、变量、函数
     pt_ 公共类型
     pc_ 公共常量
     pv_ 公共变量
     ...
  */

  -- Public type declarations
  -- type <TypeName> is <Datatype>;

  -- 定义变量
  -- ==================================================
  -- 帐期ID
  GV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE;

  -- 定义函数
  -- ==================================================
  -- 判断某张表是否已经建立
  FUNCTION PF_JUDGE_TAB_EXIST(INV_TABLENAME USER_TABLES.TABLE_NAME%TYPE)
    RETURN BOOLEAN;

  -- 获取系统当前时间帐期ID
  FUNCTION PF_GETLOCALCYCLEID
    RETURN BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE;

  -- 定义过程
  -- ==================================================
  -- 过程调用引擎
  PROCEDURE PP_MAIN;

  -- 初始化，建立本帐期的中间层表
  PROCEDURE PP_CREATE_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

  -- 初始化，清空表中数据，在建立中间层表时调用

  -- 删除本帐期的中间层表
  PROCEDURE PP_DEL_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

  -- 采集用户信息，创建用户信息表索引
  PROCEDURE PP_COLLECT_USERINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

  -- 采集话单，归类，创建索引
  PROCEDURE PP_COLLECT_CDR(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

  -- 处理入库的余额信息，创建索引
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
    --初始化
    PP_PRINTLOG(3, 'PP_MAIN', '00001', '开始进行初始化！');
  
    -- 获取当天帐务周期ID
    V_BILLINGCYCLEID := PF_GETLOCALCYCLEID();
    
    -- 创建中间层表
    -- PP_CREATE_TMP_TAB(V_BILLINGCYCLEID);
    PP_PRINTLOG(3, 'PP_MAIN', '00003', '创建中间表完成！');
    
    PP_PRINTLOG(3, 'PP_MAIN', '10000', '初始化完成！');
  
    -- 采集用户信息数据
    PP_COLLECT_USERINFO(V_BILLINGCYCLEID);
  
    PP_PRINTLOG(3,
                'PP_MAIN',
                '90001',
                '程序执行完毕准备退出，回滚未提交事务！');
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
                      '表不存在：' || INV_TABLENAME);
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
                '获取到帐期ID:' || V_BILLINGCYCLEID);
  
    RETURN V_BILLINGCYCLEID;
  
  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
      PP_PRINTLOG(1,
                  'pf_getLocalCycleId',
                  SQLCODE,
                  'BILLING_CYCLE中存在满足当前时间的多个帐期，请检查！');
      RETURN NULL;
    
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_CREATE_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
    --创建用户信息表
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
                  '表创建成功：balrp_userInfo_' || INV_BILLINGCYCLEID);
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
                  '表删除成功：balrp_userInfo_' || INV_BILLINGCYCLEID);
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
