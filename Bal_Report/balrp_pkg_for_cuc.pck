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

  -- 需要统计的余额类型
  GC_RES_TYPE CONSTANT VARCHAR2(100) := '1,2';

  -- 定义中间层表在使用后是否删除(TRUE|FALSE)
  GC_TMP_TABLE_DEL CONSTANT BOOLEAN := FALSE;

  -- 定义是否跳过数据采集阶段直接进行报表输出(TRUE|FALSE)
  GC_JUMP_COLLECT CONSTANT BOOLEAN := FALSE;

  -- 定义日志等级
  GC_LOGING_LEVEL CONSTANT NUMBER := 5;

  -- 日志信息表
  GC_PROC_LOG CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_proc_log';

  -- 用户信息中间表
  GC_USER_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_user_';

  -- 话单中间表
  GC_CDR_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_cdr_';

  -- ACCT_BOOK中间表
  GC_ACCTBOOK_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_acctbook_';

  EXP_CREATE_TMP_TAB_ERR EXCEPTION;
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

  -- 获取系统当前时间上个月帐期ID
  FUNCTION PF_GETLOCALCYCLEID
    RETURN BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE;

  -- 根据帐期id获取帐期开始时间
  FUNCTION PF_GET_CYCLEEGINTIME(INV_CYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE)
    RETURN BILLING_CYCLE.CYCLE_BEGIN_DATE@LINK_CC%TYPE;

  -- 根据帐期id获取帐期结束时间
  FUNCTION PF_GET_CYCLEENDIME(INV_CYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE)
    RETURN BILLING_CYCLE.CYCLE_END_DATE@LINK_CC%TYPE;

  -- 返回当前设置省份
  FUNCTION PF_CURR_PROVINCE RETURN CHAR;

  -- 定义过程
  -- ==================================================
  -- 过程调用引擎
  PROCEDURE PP_MAIN(INV_PREBALTAB USER_TABLES.TABLE_NAME%TYPE,
                    INV_AFTBALTAB USER_TABLES.TABLE_NAME%TYPE);

  -- 初始化，清空表中数据，在建立中间层表时调用

  -- 删除本帐期的中间层表
  PROCEDURE PP_DEL_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                           INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- 采集用户信息，创建用户信息表索引
  PROCEDURE PP_COLLECT_USERINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                                INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- 采集话单，归类，创建索引
  PROCEDURE PP_COLLECT_CDR(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                           INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- 采集用户本月ACCT_BOOK表信息
  PROCEDURE PP_COLLECT_ACCTBOOK(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                                INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- 处理入库的余额信息，创建索引
  PROCEDURE PP_COLLECT_BALINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                               INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- 日志打印
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
    DBMS_OUTPUT.PUT_LINE('开始调用存储过程[balrp_pkg_for_cuc.pp_main]，详细日志请见：' ||
                         GC_PROC_LOG);
  
    -- 判断日志信息表是否存在
    -- 不存在日志信息表则进行建立
    IF PF_JUDGE_TAB_EXIST(GC_PROC_LOG) = FALSE THEN
      DBMS_OUTPUT.PUT_LINE('日志信息表不存在，开始建立！' || GC_PROC_LOG);
    
      -- 创建用户日志信息表
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
    -- DBMS_OUTPUT.PUT_LINE('日志信息表已经建立！' || GC_PROC_LOG);
  
    -- 初始化
    PP_PRINTLOG(1,
                'PP_MAIN',
                0,
                '-------------------------------------------------------------------------------');
    PP_PRINTLOG(1, 'PP_MAIN', 0, '开始进行初始化！');
  
    -- 获取当天帐务周期ID
    V_BILLINGCYCLEID := PF_GETLOCALCYCLEID();
  
    -- 采集用户信息数据
    --PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
    --PP_COLLECT_USERINFO(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
    --PP_PRINTLOG(3, 'PP_MAIN', '00004', '采集用户信息完成！');
  
    -- 采集用户语音话单
    /*    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_CDR_TAB_NAME);
    PP_COLLECT_CDR(V_BILLINGCYCLEID, GC_CDR_TAB_NAME);
    PP_PRINTLOG(3, 'PP_MAIN', 0, '采集CDR信息完成！');*/
  
    -- 采集用户缴费信息
    --PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME);
    --PP_COLLECT_ACCTBOOK(V_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME);
    --PP_PRINTLOG(3, 'PP_MAIN', 0, '采集用户缴费信息完成！');
  
    -- 检验用户余额表信息
    IF PF_JUDGE_TAB_EXIST(INV_PREBALTAB) = TRUE AND
       PF_JUDGE_TAB_EXIST(INV_AFTBALTAB) = TRUE THEN
    
      V_SQL := 'SELECT count(1) FROM '||INV_PREBALTAB;
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
        
      PP_PRINTLOG(3,
                  'PP_MAIN',
                  0,
                  '[' || INV_PREBALTAB || ']表含有记录：' || V_COUNT);
    
      V_SQL := 'SELECT count(1) FROM '||INV_AFTBALTAB;
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
        
      PP_PRINTLOG(3,
                  'PP_MAIN',
                  0,
                  '[' || INV_AFTBALTAB || ']表含有记录：' || V_COUNT);
    END IF;
  
    PP_PRINTLOG(1, 'PP_MAIN', 0, '初始化完成！');
  
    PP_PRINTLOG(1, 'PP_MAIN', 0, '程序执行完毕准备退出，回滚未提交事务！');
  
    ROLLBACK;
  EXCEPTION
    WHEN EXP_CREATE_TMP_TAB_ERR THEN
      PP_PRINTLOG(1, 'PP_MAIN', -90001, '创建临时表失败！');
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
     WHERE ADD_MONTHS(SYSDATE, -1) >= CYCLE_BEGIN_DATE
       AND ADD_MONTHS(SYSDATE, -1) < CYCLE_END_DATE;
  
    PP_PRINTLOG(3,
                'pf_getLocalCycleId',
                0,
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
                    '表删除成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
      END IF;
    ELSE
      PP_PRINTLOG(3,
                  'PP_DEL_TMP_TAB',
                  SQLCODE,
                  '表不存在,无需删除：' || INV_TABLENAME || INV_BILLINGCYCLEID);
    END IF;
  
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_USERINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                                INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
    --创建用户信息表,并且采集数据
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
                  '表创建成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
    END IF;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_CDR(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                           INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE) IS
    V_SQL       VARCHAR2(4000);
    V_TMP_TABLE USER_TABLES.TABLE_NAME%TYPE := INV_TABLENAME || 'tmp_';
  BEGIN
  
    -- 删除临时表
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, V_TMP_TABLE);
  
    -- 现将中间数据都插入tmp表，之后再归入INV_TABLENAME
  
    ------------------语音/短信业务----------------------
    -- 创建CDR表,并且采集EVNET_USAGE acct_item_type1数据
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
                  '表创建成功：' || V_TMP_TABLE || INV_BILLINGCYCLEID);
    
      PP_PRINTLOG(5,
                  'PP_COLLECT_CDR',
                  0,
                  '插入EVNET_USAGE acct_item_type1数据完成！' || V_TMP_TABLE ||
                  INV_BILLINGCYCLEID);
    ELSE
      RAISE EXP_CREATE_TMP_TAB_ERR;
      PP_PRINTLOG(1, 'PP_COLLECT_CDR', -99001, '创建临时表失败！');
    END IF;
  
    -- 采集EVNET_USAGE acct_item_type2数据
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
                '插入EVNET_USAGE acct_item_type2数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE acct_item_type3数据
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
                '插入EVNET_USAGE acct_item_type3数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE acct_item_type4数据
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
                '插入EVNET_USAGE acct_item_type4数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------数据/增值业务----------------------
    -- 采集EVNET_USAGE_C acct_item_type1数据
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
                '插入EVNET_USAGE_C acct_item_type1数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE_C acct_item_type2数据
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
                '插入EVNET_USAGE_C acct_item_type2数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE_C acct_item_type3数据
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
                '插入EVNET_USAGE_C acct_item_type3数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE_C acct_item_type4数据
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
                '插入EVNET_USAGE_C acct_item_type4数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------周期费RECURRING----------------------SERVICE_TYPE = 100
    -- 采集EVENT_RECURRING acct_item_type1数据
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
                '插入EVENT_RECURRING acct_item_type1数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVENT_RECURRING acct_item_type2数据
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
                '插入EVENT_RECURRING acct_item_type2数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVENT_RECURRING acct_item_type3数据
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
                '插入EVENT_RECURRING acct_item_type3数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVENT_RECURRING acct_item_type4数据
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
                '插入EVENT_RECURRING acct_item_type4数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------周期费EVENT_CHARGE----------------------SERVICE_TYPE = 101
    -- 注意：因为EVENT_CHARGE没有RE_ID故用PRICE_ID代替
    -- EVENT_CHARGE.STATE:'1'、未出帐，'2'、出帐中，'3'、已出帐、'4'、已销账、
    --                    '7'已注销--instalment state，不分期付款也使用。
    --                    不分期付款当作特殊的分期付款，只付一期。
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
                '插入EVENT_CHARGE数据完成！' || V_TMP_TABLE || INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------数据合并----------------------
    -- 将采集的各个数据进行再次合并后放入正式CDR表
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
                '话单信息收集完毕！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    V_SQL := 'alter table ' || INV_TABLENAME || INV_BILLINGCYCLEID ||
             ' modify RE_ID null';
    EXECUTE IMMEDIATE V_SQL;
  
    ------------------删除临时表----------------------
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
    ------------------删除临时表----------------------
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, V_TMP_ACCTOOK);
  
    -- 获取帐期开始和结束时间，因ACCT_BOOK表中没有帐期标识，故需要
    V_BEGIN_DATE := TO_CHAR(PF_GET_CYCLEEGINTIME(INV_BILLINGCYCLEID),
                            'yyyymmddhh24miss');
  
    V_END_DATE := TO_CHAR(PF_GET_CYCLEENDIME(INV_BILLINGCYCLEID),
                          'yyyymmddhh24miss');
  
    -- 先将本帐期数据，且ACCT_BOOK_TYPE in ('H', 'P', 'Q', 'V')的数据放入临时表，以较少数据量
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
                '本帐期临时ACCT_BOOK表建立完毕！' || V_TMP_ACCTOOK ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 给临时表建立索引
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
                '本帐期临时ACCT_BOOK表索引建立完毕！' || V_TMP_ACCTOOK ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户一次性费 SERVICE_TYPE = 102
    V_SQL := 'delete from ' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID ||
             ' where SERVICE_TYPE = 102';
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '删除表中一次性费数据完成！' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID);
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
                '本帐期一次性费费用插入完毕！' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 创建用户缴费信息统计表
    -- 统计用户 现金缴费 SERVICE_TYPE = 200
    -- 999001是开户预存款，999999是预存转兑（可以在配置文件中配置）
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
                '本帐期用户缴费信息表建立完毕！' || INV_TABLENAME || INV_BILLINGCYCLEID);
  
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '插入用户现金缴费完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 一卡冲缴费 SERVICE_TYPE = 201
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
                '插入用户一卡冲缴费数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 开户预存款 SERVICE_TYPE = 202
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
                '插入用户开户预存款数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 银行卡充值 SERVICE_TYPE = 203
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
                '插入用户银行卡充值数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 空中充值 SERVICE_TYPE = 204
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
                '插入用户空中充值数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------删除临时表----------------------
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
