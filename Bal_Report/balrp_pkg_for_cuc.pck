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
  GC_RES_TYPE CONSTANT VARCHAR2(100) := '1, 16, 17, 23, 25, 26, 27, 28, 30, 31, 41, 116, 156, 172';

  -- 指定CPU并发数,危险参数！
  GC_CPU_NUM CONSTANT NUMBER := 18;

  -- 定义中间层表在使用后是否删除(TRUE|FALSE)
  GC_TMP_TABLE_DEL CONSTANT BOOLEAN := FALSE;

  -- 定义是否跳过数据采集阶段直接进行报表输出(TRUE|FALSE)
  GC_JUMP_COLLECT CONSTANT BOOLEAN := FALSE;

  -- 定义日志等级
  GC_LOGING_LEVEL CONSTANT NUMBER := 5;

  -- 最终报表存放表
  GC_REPORT_TAB CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_report_tab_';

  -- 日志信息表
  GC_PROC_LOG CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_proc_log';

  -- 用户信息中间表
  GC_USER_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_user_';

  -- 话单中间表
  GC_CDR_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_cdr_';

  -- ACCT_BOOK中间表
  GC_ACCTBOOK_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_acctbook_';

  -- 月信息中间表
  GC_BAL_TAB_NAME CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_bal_';

  -- 新 CU_BAL_CHECK
  GC_CU_BAL_CHECK CONSTANT USER_TABLES.TABLE_NAME%TYPE := 'balrp_cu_bal_check_';

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
    RETURN NUMBER;

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

  -- 返回余额报表结果表的表名
  FUNCTION PF_REP_TAB_NAME RETURN VARCHAR2;

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
                           INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE,
                           INV_AFTBALTAB      USER_TABLES.TABLE_NAME%TYPE);

  -- 采集用户本月ACCT_BOOK表信息
  PROCEDURE PP_COLLECT_ACCTBOOK(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                                INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE);

  -- 处理入库的余额信息，创建索引
  PROCEDURE PP_COLLECT_BALINFO(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                               INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE,
                               INV_TBAL_A         USER_TABLES.TABLE_NAME%TYPE,
                               INV_TBAL_B         USER_TABLES.TABLE_NAME%TYPE);

  -- 根据各个地市生成不同统计报表
  PROCEDURE PP_BUILD_REPORT(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                            INV_TBAL_A         USER_TABLES.TABLE_NAME%TYPE,
                            INV_TBAL_B         USER_TABLES.TABLE_NAME%TYPE);

  -- 更新cu_bal_check@link_cc中数据
  PROCEDURE PP_INSERT_CHECK(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                            INV_TBAL_A         USER_TABLES.TABLE_NAME%TYPE,
                            INV_TBAL_B         USER_TABLES.TABLE_NAME%TYPE);

  -- 清理中间表
  PROCEDURE PP_CLEAR_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

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
    V_SQL            VARCHAR2(1000);
  BEGIN
    -- 获取上月帐务周期ID
    V_BILLINGCYCLEID := PF_GETLOCALCYCLEID();
  
    DBMS_OUTPUT.PUT_LINE('开始调用存储过程[balrp_pkg_for_cuc.pp_main]，详细日志请见：' ||
                         GC_PROC_LOG || ',报表结果详见：' || GC_REPORT_TAB ||
                         V_BILLINGCYCLEID);
    -- 判断日志信息表是否存在
    -- 不存在日志信息表则进行建立
    IF PF_JUDGE_TAB_EXIST(GC_PROC_LOG) = 0 THEN
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
  
    IF GC_JUMP_COLLECT = FALSE THEN
      -- 采集用户信息数据
      PP_PRINTLOG(3, 'PP_MAIN', 0, '开始采集用户信息...');
      PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
      PP_COLLECT_USERINFO(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
      PP_PRINTLOG(3, 'PP_MAIN', 0, '采集用户信息完成！');
    
      -- 采集用户话单
      PP_PRINTLOG(3, 'PP_MAIN', 0, '开始采集CDR信息...');
      PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_CDR_TAB_NAME);
      PP_COLLECT_CDR(V_BILLINGCYCLEID, GC_CDR_TAB_NAME, INV_AFTBALTAB);
      PP_PRINTLOG(3, 'PP_MAIN', 0, '采集CDR信息完成！');
    
      -- 采集用户缴费信息
      PP_PRINTLOG(3, 'PP_MAIN', 0, '开始采集用户缴费信息...');
      PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME);
      PP_COLLECT_ACCTBOOK(V_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME);
      PP_PRINTLOG(3, 'PP_MAIN', 0, '采集用户缴费信息完成！');
    
      -- 采集用户余额表信息
      -- 删除月初余额信息表
      PP_PRINTLOG(3, 'PP_MAIN', 0, '开始采集用户余额信息...');
      PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_BAL_TAB_NAME || 'A_');
      -- 删除月末余额信息表
      PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_BAL_TAB_NAME || 'B_');
      PP_COLLECT_BALINFO(V_BILLINGCYCLEID,
                         GC_BAL_TAB_NAME,
                         INV_PREBALTAB,
                         INV_AFTBALTAB);
      PP_PRINTLOG(3, 'PP_MAIN', 0, '采集用户余额信息完成！');
    
      PP_PRINTLOG(1, 'PP_MAIN', 0, '初始化完成！');
    END IF;
  
    -- 开始生成报表
    PP_PRINTLOG(3, 'PP_MAIN', 0, '开始生成报表...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_REPORT_TAB);
    PP_BUILD_REPORT(V_BILLINGCYCLEID, INV_PREBALTAB, INV_AFTBALTAB);
    PP_PRINTLOG(3,
                'PP_MAIN',
                0,
                '用户余额报表生成完毕，见表：' || GC_REPORT_TAB || V_BILLINGCYCLEID);
  
    PP_PRINTLOG(3, 'PP_MAIN', 0, '开始新建CU_BAL_CHECK数据...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_CU_BAL_CHECK);
    PP_INSERT_CHECK(V_BILLINGCYCLEID, INV_PREBALTAB, INV_AFTBALTAB);
  
    IF GC_TMP_TABLE_DEL = TRUE THEN
      -- 开始删除中间表
      PP_PRINTLOG(3, 'PP_MAIN', 0, '开始删除中间表...');
      PP_CLEAR_TMP_TAB(V_BILLINGCYCLEID);
    END IF;
  
    COMMIT;
  
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
                  '表不存在：' || INV_TABLENAME);
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
  
    /*    PP_PRINTLOG(3,
    'pf_getLocalCycleId',
    0,
    '获取到帐期ID:' || V_BILLINGCYCLEID);*/
  
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
  FUNCTION PF_REP_TAB_NAME RETURN VARCHAR2 IS
  BEGIN
    RETURN GC_REPORT_TAB || PF_GETLOCALCYCLEID;
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
    /*    V_SQL := 'create table ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
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
     ';*/
  
    -- 根据王伟提供的新脚本来获取
    V_SQL := 'create table ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              NOLOGGING
              as 
              SELECT S.SUBS_ID,
                     S.ACC_NBR,
                     S.AREA_ID,
                     S.SUBS_CODE,
                     S.CUST_ID,
                     C.CUST_CODE,
                     P.PROD_STATE,
                     P.BLOCK_REASON,
                     S.ACCT_ID "CREDIT_ACCT",
                     SA.ACCT_ID,
                     A.ACCT_NBR
                FROM SUBS@LINK_CC      S,
                     PROD@LINK_CC      P,
                     SUBS_ACCT@LINK_CC SA,
                     ACCT@LINK_CC      A,
                     CUST@LINK_CC      C
               WHERE S.SUBS_ID = P.PROD_ID
                 AND S.CUST_ID = C.CUST_ID
                 AND S.SUBS_ID = SA.SUBS_ID
                 AND SA.ACCT_ID = A.ACCT_ID
                 AND SA.STATE = ''A''
                 AND P.STATE != ''B''
                 AND SA.PRIORITY = ''999999999''
                 AND SA.CU_AIT_ID = (SELECT CURRENT_VALUE
                                       FROM SYSTEM_PARAM@link_cc T
                                      WHERE T.MASK = ''DEFAULT_CU_AIT_ID'')
               ';
  
    EXECUTE IMMEDIATE V_SQL;
  
    IF PF_JUDGE_TAB_EXIST(INV_TABLENAME || INV_BILLINGCYCLEID) = 1 THEN
      PP_PRINTLOG(3,
                  'PP_COLLECT_USERINFO',
                  SQLCODE,
                  '表创建成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
    
      -- 创建表索引
      V_SQL := 'CREATE INDEX IDX_balrp_t1' || INV_BILLINGCYCLEID || ' ON ' ||
               INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      V_SQL := 'CREATE INDEX IDX_balrp_t20' || INV_BILLINGCYCLEID || ' ON ' ||
               INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (ACCT_ID) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      V_SQL := 'CREATE INDEX IDX_balrp_t21' || INV_BILLINGCYCLEID || ' ON ' ||
               INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (CREDIT_ACCT) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      PP_PRINTLOG(5,
                  'PP_COLLECT_USERINFO',
                  SQLCODE,
                  '表索引创建成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
    
    END IF;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_COLLECT_CDR(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                           INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE,
                           INV_AFTBALTAB      USER_TABLES.TABLE_NAME%TYPE) IS
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
              NOLOGGING
              AS
              SELECT /*+ PARALLEL(EVENT_USAGE_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     ACCT_ID1 "ACCT_ID",
                     BAL_ID1 "BAL_ID",
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
                        ACCT_ITEM_TYPE_ID1,
                        ACCT_ID1,
                        BAL_ID1
               ';
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
  
    IF PF_JUDGE_TAB_EXIST(V_TMP_TABLE || INV_BILLINGCYCLEID) = 1 THEN
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     ACCT_ID2 "ACCT_ID",
                     BAL_ID2 "BAL_ID",
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
                        ACCT_ITEM_TYPE_ID2,
                        ACCT_ID2,
                        BAL_ID2
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '插入EVNET_USAGE acct_item_type2数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE acct_item_type3数据
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     ACCT_ID3 "ACCT_ID",
                     BAL_ID3 "BAL_ID",
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
                        ACCT_ITEM_TYPE_ID3,
                        ACCT_ID3,
                        BAL_ID3
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '插入EVNET_USAGE acct_item_type3数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE acct_item_type4数据
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     ACCT_ID4 "ACCT_ID",
                     BAL_ID4 "BAL_ID",
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
                        ACCT_ITEM_TYPE_ID4,
                        ACCT_ID4,
                        BAL_ID4
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_C_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     ACCT_ID1 "ACCT_ID",
                     BAL_ID1 "BAL_ID",
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
                        ACCT_ITEM_TYPE_ID1,
                        ACCT_ID1,
                        BAL_ID1
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '插入EVNET_USAGE_C acct_item_type1数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE_C acct_item_type2数据
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_C_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     ACCT_ID2 "ACCT_ID",
                     BAL_ID2 "BAL_ID",
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
                        ACCT_ITEM_TYPE_ID2,
                        ACCT_ID2,
                        BAL_ID2
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '插入EVNET_USAGE_C acct_item_type2数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE_C acct_item_type3数据
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_C_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     ACCT_ID3 "ACCT_ID",
                     BAL_ID3 "BAL_ID",
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
                        ACCT_ITEM_TYPE_ID3,
                        ACCT_ID3,
                        BAL_ID3
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '插入EVNET_USAGE_C acct_item_type3数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVNET_USAGE_C acct_item_type4数据
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_USAGE_C_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     SERVICE_TYPE,
                     RE_ID,
                     ACCT_ID4 "ACCT_ID",
                     BAL_ID4 "BAL_ID",
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
                        ACCT_ITEM_TYPE_ID4,
                        ACCT_ID4,
                        BAL_ID4
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_RECURRING_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     100 "SERVICE_TYPE",
                     RE_ID,
                     ACCT_ID1 "ACCT_ID",
                     BAL_ID1 "BAL_ID",
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE1) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID1 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_RECURRING_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID1 != -1
                 AND STATE = ''A''
               GROUP BY SUBS_ID,
                     RE_ID,
                     ACCT_ITEM_TYPE_ID1,
                     ACCT_ID1,
                     BAL_ID1
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '插入EVENT_RECURRING acct_item_type1数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVENT_RECURRING acct_item_type2数据
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_RECURRING_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     100 "SERVICE_TYPE",
                     RE_ID,
                     ACCT_ID2 "ACCT_ID",
                     BAL_ID2 "BAL_ID",
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE2) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID2 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_RECURRING_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID2 != -1
                 AND STATE = ''A''
               GROUP BY SUBS_ID,
                     RE_ID,
                     ACCT_ITEM_TYPE_ID2,
                     ACCT_ID2,
                     BAL_ID2
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '插入EVENT_RECURRING acct_item_type2数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVENT_RECURRING acct_item_type3数据
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_RECURRING_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     100 "SERVICE_TYPE",
                     RE_ID,
                     ACCT_ID3 "ACCT_ID",
                     BAL_ID3 "BAL_ID",
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE3) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID3 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_RECURRING_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID3 != -1
                 AND STATE = ''A''
               GROUP BY SUBS_ID,
                     RE_ID,
                     ACCT_ITEM_TYPE_ID3,
                     ACCT_ID3,
                     BAL_ID3
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '插入EVENT_RECURRING acct_item_type3数据完成！' || V_TMP_TABLE ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 采集EVENT_RECURRING acct_item_type4数据
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT /*+ PARALLEL(EVENT_RECURRING_' ||
             INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
             ') */ SUBS_ID,
                     100 "SERVICE_TYPE",
                     RE_ID,
                     ACCT_ID4 "ACCT_ID",
                     BAL_ID4 "BAL_ID",
                     0 "DURATION",
                     0 "DATA_BYTE",
                     SUM(CHARGE4) "CHARGE_FEE",
                     ACCT_ITEM_TYPE_ID4 "ACCT_ITEM_TYPE_ID"
                FROM EVENT_RECURRING_' || INV_BILLINGCYCLEID || '
               WHERE ACCT_ITEM_TYPE_ID4 != -1
                 AND STATE = ''A''
               GROUP BY SUBS_ID,
                     RE_ID,
                     ACCT_ITEM_TYPE_ID4,
                     ACCT_ID4,
                     BAL_ID4
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
    V_SQL := 'insert /*+ APPEND */ into ' || V_TMP_TABLE ||
             INV_BILLINGCYCLEID || '
              SELECT SUBS_ID,
                     101 "SERVICE_TYPE",
                     PRICE_ID "RE_ID",
                     ACCT_ID "ACCT_ID",
                     BAL_ID "BAL_ID",
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
                     ACCT_ITEM_ID,
                     ACCT_ID,
                     BAL_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                0,
                '插入EVENT_CHARGE数据完成！' || V_TMP_TABLE || INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------创建索引----------------------
    V_SQL := 'CREATE INDEX IDX_balrp_t2' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_TABLE || INV_BILLINGCYCLEID || '
                           (ACCT_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t3' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_TABLE || INV_BILLINGCYCLEID || '
                           (BAL_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    ------------------数据合并----------------------
    -- 将采集的各个数据进行再次合并后放入正式CDR表
    IF GC_PROVINCE = 'SD' THEN
      V_SQL := 'CREATE TABLE ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              NOLOGGING
              AS
              SELECT /*+ PARALLEL(' || V_TMP_TABLE ||
               INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
               ') */   A.SUBS_ID,
                     C.AREA_ID,
                     A.SERVICE_TYPE,
                     A.RE_ID,
                     A.ACCT_ID "ACCT_ID",
                     A.BAL_ID "BAL_ID",
                     SUM(A.DURATION) "DURATION",
                     SUM(A.DATA_BYTE) "DATA_BYTE",
                     SUM(A.CHARGE_FEE) "CHARGE_FEE"
                FROM ' || V_TMP_TABLE || INV_BILLINGCYCLEID || ' A,
                     ' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || ' C,
                     ' || INV_AFTBALTAB || ' B
               WHERE A.Bal_Id(+) = B.Bal_Id
                 AND b.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
                 AND A.SUBS_ID = C.SUBS_ID
               GROUP BY C.AREA_ID, A.SUBS_ID, A.SERVICE_TYPE, A.RE_ID, A.ACCT_ID, A.BAL_ID
               ';
    ELSE
      V_SQL := 'CREATE TABLE ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              NOLOGGING
              AS
              SELECT /*+ PARALLEL(' || V_TMP_TABLE ||
               INV_BILLINGCYCLEID || ', ' || GC_CPU_NUM ||
               ') */   A.SUBS_ID,
                     C.AREA_ID,
                     A.SERVICE_TYPE,
                     A.RE_ID,
                     A.ACCT_ID "ACCT_ID",
                     A.BAL_ID "BAL_ID",
                     SUM(A.DURATION) "DURATION",
                     SUM(A.DATA_BYTE) "DATA_BYTE",
                     SUM(A.CHARGE_FEE) "CHARGE_FEE"
                FROM ' || V_TMP_TABLE || INV_BILLINGCYCLEID || ' A,
                     ' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || ' C,
                     (SELECT DISTINCT CU_AIT_ID
                        FROM ACCT_ITEM_TYPE@LINK_CC
                       WHERE ACCT_RES_ID IN (' || GC_RES_TYPE ||
               ')) B
               WHERE A.ACCT_ITEM_TYPE_ID IN B.CU_AIT_ID
                 AND A.SUBS_ID = C.SUBS_ID
               GROUP BY C.AREA_ID, A.SUBS_ID, A.SERVICE_TYPE, A.RE_ID, A.ACCT_ID, A.BAL_ID
               ';
    END IF;
  
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_CDR',
                0,
                '话单信息收集完毕！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    V_SQL := 'alter table ' || INV_TABLENAME || INV_BILLINGCYCLEID ||
             ' modify RE_ID null';
    EXECUTE IMMEDIATE V_SQL;
  
    -- 创建表索引
    V_SQL := 'CREATE INDEX IDX_balrp_t4' || INV_BILLINGCYCLEID || ' ON ' ||
             INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    PP_PRINTLOG(5,
                'PP_COLLECT_CDR',
                SQLCODE,
                '表索引创建成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
  
    ------------------删除临时表----------------------
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
              NOLOGGING
              AS
              SELECT SA.SUBS_ID,
                     AB.ACCT_ID,
                     AB.BAL_ID,
                     AB.ACCT_RES_ID,
                     AB.ACCT_BOOK_TYPE,
                     AB.CREATED_DATE,
                     AB.CONTACT_CHANNEL_ID,
                     AB.PARTY_CODE,
                     SUM(AB.CHARGE) "CHARGE_FEE"
                FROM ACCT_BOOK@LINK_CC AB, ' ||
             GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' SA
               WHERE ACCT_BOOK_TYPE IN (''H'', ''P'', ''Q'', ''V'')
                 AND (AB.ACCT_ID = SA.ACCT_ID OR AB.ACCT_ID = SA.CREDIT_ACCT)
                 AND AB.CREATED_DATE >= to_date(' ||
             V_BEGIN_DATE ||
             ', ''yyyymmddhh24miss'')
                 AND AB.CREATED_DATE < to_date(' || V_END_DATE ||
             ', ''yyyymmddhh24miss'')
               GROUP BY SA.SUBS_ID,
                        AB.ACCT_ID,
                        AB.BAL_ID,
                        AB.ACCT_RES_ID,
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
    V_SQL := 'CREATE INDEX IDX_balrp_t5' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
                           (ACCT_BOOK_TYPE) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t6' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
                           (CONTACT_CHANNEL_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t7' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
                           (ACCT_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t8' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
                           (PARTY_CODE) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t9' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
                           (ACCT_RES_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t10' || INV_BILLINGCYCLEID || ' ON ' ||
             V_TMP_ACCTOOK || INV_BILLINGCYCLEID || '
                           (BAL_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '本帐期临时ACCT_BOOK表索引建立完毕！' || V_TMP_ACCTOOK ||
                INV_BILLINGCYCLEID);
    COMMIT;
    
    -- 将ACCT_BOOK临时表中，充值抵扣信用账本的记录，充值渠道更新为1
    V_SQL := 'UPDATE ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID || ' A
                 SET A.CONTACT_CHANNEL_ID = 1
               WHERE A.CONTACT_CHANNEL_ID IS NULL
                 AND A.ACCT_BOOK_TYPE = ''V''
                 AND A.CHARGE_FEE < 0';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '更新V充值记录的渠道信息完毕!' || V_TMP_ACCTOOK ||
                INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 创建用户缴费信息统计表
    -- 统计用户 现金缴费 SERVICE_TYPE = 200
    -- 999001是开户预存款，999999是预存转兑（可以在配置文件中配置）
    -- 现在将999999归入先进缴费统计中,现场可以根据余额类型将其剔除
    IF GC_PROVINCE = 'SD' THEN
      V_SQL := 'CREATE TABLE ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, A.BAL_ID, A.ACCT_RES_ID, 
                       200 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                  FROM ' || V_TMP_ACCTOOK ||
               INV_BILLINGCYCLEID || ' A,' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || ' U
                 WHERE A.CONTACT_CHANNEL_ID = 1
                   AND A.PARTY_CODE = ''999999'' 
                   AND A.ACCT_BOOK_TYPE = (''H'')
                   AND A.SUBS_ID = U.SUBS_ID
                   AND A.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
                 GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID, A.BAL_ID, A.ACCT_RES_ID';
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    
      V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
               INV_BILLINGCYCLEID || '
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, A.BAL_ID, A.ACCT_RES_ID, 
                     200 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
               ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 1
                 AND A.PARTY_CODE IS NULL 
                 AND ( A.ACCT_BOOK_TYPE = (''P'') OR  (A.ACCT_BOOK_TYPE = ''V'' AND  A.CHARGE_fee < 0) )
                 AND A.SUBS_ID = U.SUBS_ID
                 AND A.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID, A.BAL_ID, A.ACCT_RES_ID';
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    
    ELSE
      V_SQL := 'CREATE TABLE ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, A.BAL_ID, A.ACCT_RES_ID, 
                       200 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                  FROM ' || V_TMP_ACCTOOK ||
               INV_BILLINGCYCLEID || ' A,' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || ' U
                 WHERE A.CONTACT_CHANNEL_ID = 1
                   AND (A.PARTY_CODE != ''999001'' OR A.PARTY_CODE IS NULL)
                   AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR  (A.ACCT_BOOK_TYPE = ''V'' AND  A.CHARGE_fee < 0))
                   AND A.SUBS_ID = U.SUBS_ID
                   AND A.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
                 GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID, A.BAL_ID, A.ACCT_RES_ID
                 ';
      --dbms_output.put_line('V_SQL='||V_SQL);
      EXECUTE IMMEDIATE V_SQL;
    END IF;
  
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
    V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
             INV_BILLINGCYCLEID || '
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, A.BAL_ID, A.ACCT_RES_ID,
                     201 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
             ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 4
                 AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR (A.ACCT_BOOK_TYPE = ''V'' AND A. CHARGE_fee < 0))
                 AND A.SUBS_ID = U.SUBS_ID
                 AND A.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID, A.BAL_ID, A.ACCT_RES_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '插入用户一卡冲缴费数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 开户预存款 SERVICE_TYPE = 202
    V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
             INV_BILLINGCYCLEID || '
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, A.BAL_ID, A.ACCT_RES_ID,
                     202 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
             ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 1
                 AND A.PARTY_CODE = ''999001''
                 AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR (A.ACCT_BOOK_TYPE = ''V'' AND A. CHARGE_fee < 0))
                 AND A.SUBS_ID = U.SUBS_ID
                 AND A.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID, A.BAL_ID, A.ACCT_RES_ID
               ';
  
    -- 因为山东统计开户预存款sql不太一致，所以单独列出来
    IF GC_PROVINCE = 'SD' THEN
      V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
               INV_BILLINGCYCLEID || '
                SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, A.BAL_ID, A.ACCT_RES_ID,
                       202 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                  FROM ' || V_TMP_ACCTOOK ||
               INV_BILLINGCYCLEID || ' A,' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || ' U
                 WHERE A.CONTACT_CHANNEL_ID = 1
                   AND (A.ACCT_BOOK_TYPE = ''P'' OR (A.ACCT_BOOK_TYPE = ''V'' AND A. CHARGE_fee < 0))
                   AND A.PARTY_CODE IS NOT NULL
                   AND A.SUBS_ID = U.SUBS_ID
                   AND A.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
                 GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID, A.BAL_ID, A.ACCT_RES_ID
                 ';
    END IF;
    --dbms_output.put_line('V_SQL='||V_SQL);
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '插入用户开户预存款数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 银行卡充值 SERVICE_TYPE = 203
    V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
             INV_BILLINGCYCLEID || '
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, A.BAL_ID, A.ACCT_RES_ID,
                     203 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
             ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 10
                 AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR (A.ACCT_BOOK_TYPE = ''V'' AND  A.CHARGE_fee < 0))
                 AND A.SUBS_ID = U.SUBS_ID
                 AND A.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID, A.BAL_ID, A.ACCT_RES_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '插入用户银行卡充值数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 空中充值 SERVICE_TYPE = 204
    V_SQL := 'INSERT /*+ APPEND */ INTO ' || INV_TABLENAME ||
             INV_BILLINGCYCLEID || '
              SELECT A.SUBS_ID, U.AREA_ID, A.ACCT_ID, A.BAL_ID, A.ACCT_RES_ID,
                     204 "SERVICE_TYPE", sum(A.CHARGE_fee) "CHARGE_FEE"
                FROM ' || V_TMP_ACCTOOK || INV_BILLINGCYCLEID ||
             ' A,' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
               WHERE A.CONTACT_CHANNEL_ID = 7
                 AND (A.ACCT_BOOK_TYPE IN (''H'',''P'') OR (A.ACCT_BOOK_TYPE = ''V'' AND  A.CHARGE_fee < 0))
                 AND A.SUBS_ID = U.SUBS_ID
                 AND A.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
               GROUP BY A.ACCT_ID, A.SUBS_ID, U.AREA_ID, A.BAL_ID, A.ACCT_RES_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '插入用户空中充值数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 创建表索引
    V_SQL := 'CREATE INDEX IDX_balrp_t11' || INV_BILLINGCYCLEID || ' ON ' ||
             INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t12' || INV_BILLINGCYCLEID || ' ON ' ||
             INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (SERVICE_TYPE) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    PP_PRINTLOG(5,
                'PP_COLLECT_ACCTBOOK',
                SQLCODE,
                '表索引创建成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
  
    ------------------删除临时表----------------------
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
                  '[' || INV_TBAL_A || ']表含有记录：' || V_COUNT);
    
      ------------------创建索引----------------------
      V_SQL := 'SELECT count(1) FROM User_Objects WHERE object_name = upper(''IDX_balrp_t13' ||
               INV_BILLINGCYCLEID || ''') AND OBJECT_TYPE = ''INDEX''';
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
      IF V_COUNT = 0 THEN
        V_SQL := 'CREATE INDEX IDX_balrp_t13' || INV_BILLINGCYCLEID ||
                 ' ON ' || INV_TBAL_A || '
                             (ACCT_ID) TABLESPACE IDX_RB';
        EXECUTE IMMEDIATE V_SQL;
      END IF;
    
      V_SQL := 'SELECT count(1) FROM User_Objects WHERE object_name = upper(''IDX_balrp_t14' ||
               INV_BILLINGCYCLEID || ''') AND OBJECT_TYPE = ''INDEX''';
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
      IF V_COUNT = 0 THEN
        V_SQL := 'CREATE INDEX IDX_balrp_t14' || INV_BILLINGCYCLEID ||
                 ' ON ' || INV_TBAL_A || '
                             (BAL_ID) TABLESPACE IDX_RB';
        EXECUTE IMMEDIATE V_SQL;
      END IF;
    
      -- 生成A表的中间表（筛选数据）
      V_SQL := 'CREATE TABLE ' || INV_TABLENAME || 'A_' ||
               INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT U.SUBS_ID,
                       U.AREA_ID,
                       B.ACCT_ID,
                       SUM(B.GROSS_BAL) "GROSS_BAL",
                       SUM(B.RESERVE_BAL) "RESERVE_BAL",
                       SUM(B.CONSUME_BAL) "CONSUME_BAL"
                  FROM ' || INV_TBAL_A || ' B, ' ||
               GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
                 WHERE B.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
                   AND (B.ACCT_ID = U.ACCT_ID OR B.ACCT_ID = U.CREDIT_ACCT)
                 GROUP BY B.ACCT_ID, U.SUBS_ID, U.AREA_ID
                ';
      EXECUTE IMMEDIATE V_SQL;
      PP_PRINTLOG(3,
                  'PP_COLLECT_BALINFO',
                  0,
                  '用户月初信息表收集完成：' || INV_TABLENAME || 'A_' ||
                  INV_BILLINGCYCLEID);
      COMMIT;
    
      V_SQL := 'SELECT count(1) FROM ' || INV_TBAL_B;
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
    
      PP_PRINTLOG(3,
                  'PP_COLLECT_BALINFO',
                  0,
                  '[' || INV_TBAL_B || ']表含有记录：' || V_COUNT);
    
      ------------------创建索引----------------------
      V_SQL := 'SELECT count(1) FROM User_Objects WHERE object_name = upper(''IDX_balrp_t15' ||
               INV_BILLINGCYCLEID || ''') AND OBJECT_TYPE = ''INDEX''';
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
      IF V_COUNT = 0 THEN
        V_SQL := 'CREATE INDEX IDX_balrp_t15' || INV_BILLINGCYCLEID ||
                 ' ON ' || INV_TBAL_B || '
                             (ACCT_ID) TABLESPACE IDX_RB';
        EXECUTE IMMEDIATE V_SQL;
      END IF;
    
      V_SQL := 'SELECT count(1) FROM User_Objects WHERE object_name = upper(''IDX_balrp_t16' ||
               INV_BILLINGCYCLEID || ''') AND OBJECT_TYPE = ''INDEX''';
      EXECUTE IMMEDIATE V_SQL
        INTO V_COUNT;
      IF V_COUNT = 0 THEN
        V_SQL := 'CREATE INDEX IDX_balrp_t16' || INV_BILLINGCYCLEID ||
                 ' ON ' || INV_TBAL_B || '
                             (BAL_ID) TABLESPACE IDX_RB';
        EXECUTE IMMEDIATE V_SQL;
      END IF;
    
      -- 生成B表的中间表（筛选数据）
      V_SQL := 'CREATE TABLE ' || INV_TABLENAME || 'B_' ||
               INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT U.SUBS_ID,
                       U.AREA_ID,
                       B.ACCT_ID,
                       SUM(B.GROSS_BAL) "GROSS_BAL",
                       SUM(B.RESERVE_BAL) "RESERVE_BAL",
                       SUM(B.CONSUME_BAL) "CONSUME_BAL"
                  FROM ' || INV_TBAL_B || ' B, ' ||
               GC_USER_TAB_NAME || INV_BILLINGCYCLEID || ' U
                 WHERE B.ACCT_RES_ID IN (' || GC_RES_TYPE || ')
                   AND (B.ACCT_ID = U.ACCT_ID OR B.ACCT_ID = U.CREDIT_ACCT)
                 GROUP BY B.ACCT_ID, U.SUBS_ID, U.AREA_ID
                ';
      EXECUTE IMMEDIATE V_SQL;
      PP_PRINTLOG(3,
                  'PP_COLLECT_BALINFO',
                  0,
                  '用户月末信息表收集完成：' || INV_TABLENAME || 'B_' ||
                  INV_BILLINGCYCLEID);
      COMMIT;
    
      -- 创建索引
      V_SQL := 'CREATE INDEX IDX_balrp_t17' || INV_BILLINGCYCLEID || ' ON ' ||
               INV_TABLENAME || 'A_' || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      V_SQL := 'CREATE INDEX IDX_balrp_t18' || INV_BILLINGCYCLEID || ' ON ' ||
               INV_TABLENAME || 'B_' || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      PP_PRINTLOG(5,
                  'PP_COLLECT_BALINFO',
                  SQLCODE,
                  '表索引创建成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
    ELSE
      PP_PRINTLOG(1,
                  'PP_COLLECT_BALINFO',
                  SQLCODE,
                  '传入的余额信息表不存在！A=' || INV_TBAL_A || ' B=' || INV_TBAL_B);
    END IF;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_BUILD_REPORT(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                            INV_TBAL_A         USER_TABLES.TABLE_NAME%TYPE,
                            INV_TBAL_B         USER_TABLES.TABLE_NAME%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
  
    -- 开始生成内蒙报表
    IF GC_PROVINCE = 'NM' OR GC_PROVINCE = 'GS' THEN
      V_SQL := 'CREATE TABLE ' || GC_REPORT_TAB || INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT U.ACC_NBR "用户号码",
                       U.AREA_ID "地市",
                       ABS(NVL(BA.CHARGE_FEE, 0)) "月初余额",
                       ABS(NVL(A.CHARGE_FEE, 0)) "月中充值",
                       ABS(NVL(C.CHARGE_FEE, 0)) "月中消费",
                       ABS(NVL(BB.CHARGE_FEE, 0)) "月末余额",
                       ABS(BA.CHARGE_FEE) + ABS(NVL(A.CHARGE_FEE, 0)) -
                       ABS(NVL(C.CHARGE_FEE, 0)) "月末自平衡余额"
                  FROM ' || GC_USER_TAB_NAME ||
               INV_BILLINGCYCLEID || ' U,
                       (SELECT SUBS_ID,
                               SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                          FROM ' || GC_BAL_TAB_NAME || 'A_' ||
               INV_BILLINGCYCLEID || '
                         GROUP BY SUBS_ID) BA,
                       (SELECT SUBS_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                          FROM ' || GC_ACCTBOOK_TAB_NAME ||
               INV_BILLINGCYCLEID || '
                         GROUP BY SUBS_ID) A,
                       (SELECT SUBS_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                          FROM ' || GC_CDR_TAB_NAME ||
               INV_BILLINGCYCLEID || '
                         GROUP BY SUBS_ID) C,
                       (SELECT SUBS_ID,
                               SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                          FROM ' || GC_BAL_TAB_NAME || 'B_' ||
               INV_BILLINGCYCLEID || '
                         GROUP BY SUBS_ID) BB
                 WHERE U.SUBS_ID = BA.SUBS_ID(+)
                   AND U.SUBS_ID = BA.SUBS_ID(+)
                   AND U.SUBS_ID = A.SUBS_ID(+)
                   AND U.SUBS_ID = C.SUBS_ID(+)
                   AND U.SUBS_ID = BB.SUBS_ID(+)
                 GROUP BY U.ACC_NBR,
                          U.AREA_ID,
                          C.CHARGE_FEE,
                          BA.CHARGE_FEE,
                          A.CHARGE_FEE,
                          BB.CHARGE_FEE';
    
    ELSIF GC_PROVINCE = 'SD' THEN
      -- 山东特殊处理
      -- 删除测试号码的数据
      V_SQL := 'delete from ' || GC_USER_TAB_NAME || INV_BILLINGCYCLEID ||
               ' where SUBS_ID in (SELECT DISTINCT subs_id FROM tt_ocssys_nr@link_cc)';
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    
      V_SQL := 'delete from ' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID ||
               ' where SUBS_ID in (SELECT DISTINCT subs_id FROM tt_ocssys_nr@link_cc)';
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    
      V_SQL := 'delete from ' || GC_ACCTBOOK_TAB_NAME || INV_BILLINGCYCLEID ||
               ' where SUBS_ID in (SELECT DISTINCT subs_id FROM tt_ocssys_nr@link_cc)';
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    
      V_SQL := 'delete from ' || GC_BAL_TAB_NAME || 'A_' ||
               INV_BILLINGCYCLEID ||
               ' where SUBS_ID in (SELECT DISTINCT subs_id FROM tt_ocssys_nr@link_cc)';
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    
      V_SQL := 'delete from ' || GC_BAL_TAB_NAME || 'B_' ||
               INV_BILLINGCYCLEID ||
               ' where SUBS_ID in (SELECT DISTINCT subs_id FROM tt_ocssys_nr@link_cc)';
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    
      PP_PRINTLOG(3, 'PP_BUILD_REPORT', SQLCODE, '删除测试用户数据完成！');
    
      V_SQL := 'CREATE TABLE ' || GC_REPORT_TAB || INV_BILLINGCYCLEID || '
  TABLESPACE TAB_RB
  NOLOGGING
  AS
  SELECT ' || INV_BILLINGCYCLEID || ' "帐务月份",
         A.AREA_ID "地市编码",
         NVL(ABS(SUM(B1.CHARGE_FEE)),0)*(0.01) "期初",
         NVL(ABS(SUM(A1.CHARGE_FEE)),0)*(0.01) "现金缴费",
         NVL(ABS(SUM(A2.CHARGE_FEE)),0)*(0.01) "开户预存款",
         NVL(ABS(SUM(A3.CHARGE_FEE)),0)*(0.01) "一卡充",
         NVL(ABS(SUM(A4.CHARGE_FEE)),0)*(0.01) "空中充值",
         NVL(ABS(SUM(C.CHARGE_FEE)),0)*(0.01) "本期减少",
         (NVL(ABS(SUM(B1.CHARGE_FEE)),0)
          + NVL(ABS(SUM(A1.CHARGE_FEE)),0)
          + NVL(ABS(SUM(A2.CHARGE_FEE)),0)
          + NVL(ABS(SUM(A3.CHARGE_FEE)),0)
          + NVL(ABS(SUM(A4.CHARGE_FEE)),0)
          - NVL(ABS(SUM(C.CHARGE_FEE)),0))*(0.01) "月末余额",
         NVL(ABS(SUM(B3.CHARGE_FEE)),0)*(0.01) "月末余额（正）",
         NVL(SUM(B4.CHARGE_FEE),0)*(-0.01) "月末余额（负）",
         NVL((ABS((NVL(ABS(SUM(B1.CHARGE_FEE)),0)
                  + NVL(ABS(SUM(A1.CHARGE_FEE)),0)
                  + NVL(ABS(SUM(A2.CHARGE_FEE)),0)
                  + NVL(ABS(SUM(A3.CHARGE_FEE)),0)
                  + NVL(ABS(SUM(A4.CHARGE_FEE)),0)
                  - NVL(ABS(SUM(C.CHARGE_FEE)),0)))
             - ABS(SUM(B3.CHARGE_FEE))
             + ABS(SUM(B4.CHARGE_FEE))),0)*(0.01) "校验"
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
            FROM ' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID || '
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
      PP_PRINTLOG(3, 'PP_BUILD_REPORT', SQLCODE, '开始执行河北报表生成!');
      -- 河北需要重新写，加入bal_id的信息
      V_SQL := 'CREATE TABLE ' || GC_REPORT_TAB || INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT BA.BAL_ID,
                       ABS(NVL(BA.CHARGE_FEE, 0)) "月初余额",
                       ABS(NVL(A.CHARGE_FEE, 0)) "月中充值",
                       ABS(NVL(C.CHARGE_FEE, 0)) "月中消费",
                       ABS(NVL(BB.CHARGE_FEE, 0)) "月末余额",
                       ABS(NVL(BA.CHARGE_FEE), 0) + ABS(NVL(A.CHARGE_FEE, 0)) -
                       ABS(NVL(C.CHARGE_FEE, 0)) "月末自平衡余额"  
                  FROM (SELECT BAL_ID,
                               SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                          FROM ' || INV_TBAL_A || '
                         GROUP BY BAL_ID) BA,
                       (SELECT BAL_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                          FROM ' || GC_ACCTBOOK_TAB_NAME ||
               'tmp_' || INV_BILLINGCYCLEID || '
                         GROUP BY BAL_ID) A,
                       (SELECT BAL_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                          FROM ' || GC_CDR_TAB_NAME || 'tmp_' ||
               INV_BILLINGCYCLEID || '
                         GROUP BY BAL_ID) C,
                       (SELECT BAL_ID,
                               SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                          FROM ' || INV_TBAL_B || '
                         GROUP BY BAL_ID) BB
                   WHERE BA.BAL_ID = A.BAL_ID(+)
                     AND BA.BAL_ID = C.BAL_ID(+)
                     AND BA.BAL_ID = BB.BAL_ID(+)
                   GROUP BY BA.BAL_ID,
                            C.CHARGE_FEE,
                            BA.CHARGE_FEE,
                            A.CHARGE_FEE,
                            BB.CHARGE_FEE
                ';
    
      /*    ELSIF GC_PROVINCE = 'GS' THEN
      NULL;*/
    END IF;
  
    -- DBMS_OUTPUT.PUT_LINE('V_SQL=' || V_SQL);
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
  
    PP_PRINTLOG(3,
                'PP_BUILD_REPORT',
                SQLCODE,
                '报表生成完毕!' || GC_REPORT_TAB || INV_BILLINGCYCLEID);
  
    -- 对生成的报表的处理
    IF GC_PROVINCE = 'SD' THEN
      V_SQL := ' UPDATE ' || GC_REPORT_TAB || INV_BILLINGCYCLEID || ' A
                 SET "帐务月份" = (SELECT TO_NUMBER(TO_CHAR(CYCLE_BEGIN_DATE, ''YYYYMM ''))
                     FROM BILLING_CYCLE@LINK_CC B
                    WHERE A."帐务月份" = B.BILLING_CYCLE_ID)';
      -- DBMS_OUTPUT.PUT_LINE('V_SQL=' || V_SQL);
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    
      PP_PRINTLOG(3,
                  'PP_BUILD_REPORT',
                  SQLCODE,
                  '山东更新帐务月份处理完毕！');
    
    ELSIF GC_PROVINCE = 'HB' THEN
      V_SQL := 'CREATE INDEX IDX_balrp_t19' || INV_BILLINGCYCLEID || ' ON ' ||
               GC_REPORT_TAB || INV_BILLINGCYCLEID || '
                           (BAL_ID) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      PP_PRINTLOG(3, 'PP_BUILD_REPORT', SQLCODE, '建立山东报表所引完成');
    
      -- 将 "月末自平衡余额"  插入bal_bak@link_cc表的 month_bal 字段
      V_SQL := 'UPDATE BAL_BAK@LINK_CC A
                   SET MONTH_BAL = (SELECT "月末自平衡余额"
                                      FROM ' || GC_REPORT_TAB ||
               INV_BILLINGCYCLEID || ' B
                                     WHERE B.BAL_ID = A.BAL_ID)
                     ';
      DBMS_OUTPUT.PUT_LINE('V_SQL=' || V_SQL);
      EXECUTE IMMEDIATE V_SQL;
      COMMIT;
    
      PP_PRINTLOG(3, 'PP_BUILD_REPORT', SQLCODE, '河北更新BAL_BAK表完成！');
    
    END IF;
  
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_INSERT_CHECK(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE,
                            INV_TBAL_A         USER_TABLES.TABLE_NAME%TYPE,
                            INV_TBAL_B         USER_TABLES.TABLE_NAME%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
    --与王伟商量后，决定不再采用cu_bal_check@link_cc表，我重新在rb库建立相应表
    /*    -- 先删除表中已有本帐期的数据
    V_SQL := 'delete from CU_BAL_CHECK@link_cc where BILLING_CYCLE_ID =' ||
             INV_BILLINGCYCLEID;
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
    PP_PRINTLOG(3,
                'PP_INSERT_CHECK',
                SQLCODE,
                '删除CU_BAL_CHECK@link_cc表中[' || INV_BILLINGCYCLEID ||
                ']帐期数据完成！');
    
    -- 插入本帐期数据
    V_SQL := 'INSERT INTO CU_BAL_CHECK@link_cc 
                     (acct_id, bal_id, PRE_CYCLE_BAL, DUE, CHARGE, CUR_CYCLE_BAL, BILLING_CYCLE_ID)
              SELECT A.ACCT_ID,
                     A.BAL_ID,
                     NVL(C.CHARGE_FEE, 0) "PRE_CYCLE_BALANCE",
                     NVL(B.CHARGE_FEE, 0) "DUE",
                     NVL(A.CHARGE_FEE, 0) "CHARGE",
                     NVL(D.CHARGE_FEE, 0) "CUR_CYCLE_BAL",
                     ''' || INV_BILLINGCYCLEID ||
             ''' "BILLING_CYCLE_ID"
                FROM (SELECT ACCT_ID, BAL_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                        FROM ' || GC_ACCTBOOK_TAB_NAME ||
             'tmp_' || INV_BILLINGCYCLEID || '
                       GROUP BY ACCT_ID, BAL_ID) A,
                     (SELECT BAL_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                        FROM ' || GC_CDR_TAB_NAME || 'tmp_' ||
             INV_BILLINGCYCLEID || '
                       GROUP BY BAL_ID) B,
                     (SELECT BAL_ID,
                             SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                        FROM ' || INV_TBAL_A || '
                       GROUP BY BAL_ID) C,
                     (SELECT BAL_ID,
                             SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                        FROM ' || INV_TBAL_B || '
                       GROUP BY BAL_ID) D
               WHERE C.BAL_ID = B.BAL_ID(+)
                 AND C.BAL_ID = A.BAL_ID(+)
                 AND C.BAL_ID = D.BAL_ID(+)
               GROUP BY A.ACCT_ID,
                        A.BAL_ID,
                        A.CHARGE_FEE,
                        B.CHARGE_FEE,
                        C.CHARGE_FEE,
                        D.CHARGE_FEE
              ';*/
    /*              
    1、在RB库重新生成一张CU_BAL_CHECK_XXX帐期的表，具体字段如下：
        SUBS_ID,ACCT_ID,ACCT_RES_ID,PRE_CYCLE_BAL,DUE,CHARGE,CUR_CYCLE_BAL
    2、保证每个subs_id的每个ACCT_RES_ID只有一条记录，（同一个subs_id可能有多条记录）
    3、建立索引：SUBS_ID,ACCT_ID，ACCT_RES_ID*/
  
    -- 删除临时表
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_CU_BAL_CHECK || 'TMP1_');
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_CU_BAL_CHECK || 'TMP2_');
  
    -- 创建本金账本的临时表
    V_SQL := 'CREATE TABLE ' || GC_CU_BAL_CHECK || 'tmp1_' ||
             INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              AS 
              SELECT u.SUBS_ID,
                     c.ACCT_ID,
                     C.BAL_ID,
                     NVL(C.CHARGE_FEE, 0) "PRE_CYCLE_BALANCE",
                     NVL(B.CHARGE_FEE, 0) "DUE",
                     NVL(A.CHARGE_FEE, 0) "CHARGE",
                     NVL(D.CHARGE_FEE, 0) "CUR_CYCLE_BAL",
                     c.acct_res_id
                FROM ' || GC_USER_TAB_NAME ||
             INV_BILLINGCYCLEID || ' u
                ,(SELECT BAL_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                        FROM ' || GC_ACCTBOOK_TAB_NAME ||
             'tmp_' || INV_BILLINGCYCLEID || '
                       GROUP BY BAL_ID) A,
                     (SELECT SUBS_ID, BAL_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                        FROM ' || GC_CDR_TAB_NAME || 'tmp_' ||
             INV_BILLINGCYCLEID || '
                       GROUP BY SUBS_ID, BAL_ID) B,
                     (SELECT acct_res_id, BAL_ID, acct_id,
                             SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                        FROM ' || INV_TBAL_A || '
                       GROUP BY acct_res_id,BAL_ID,acct_id) C,
                     (SELECT BAL_ID,
                             SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                        FROM ' || INV_TBAL_B || '
                       GROUP BY BAL_ID) D
               WHERE C.BAL_ID = B.BAL_ID(+)
                 AND C.BAL_ID = A.BAL_ID(+)
                 AND C.BAL_ID = D.BAL_ID(+)
                 AND c.acct_id = u.acct_id
               GROUP BY u.SUBS_ID,
                        c.ACCT_ID,
                        C.BAL_ID,
                        A.CHARGE_FEE,
                        B.CHARGE_FEE,
                        C.CHARGE_FEE,
                        D.CHARGE_FEE,
                        c.acct_res_id
          ';
  
    -- DBMS_OUTPUT.PUT_LINE('V_SQL=' || V_SQL);
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
  
    PP_PRINTLOG(3,
                'PP_INSERT_CHECK',
                SQLCODE,
                '新建临时表完成' || GC_CU_BAL_CHECK || 'tmp1_' ||
                INV_BILLINGCYCLEID);
  
    -- 创建信用账本的临时表
    V_SQL := 'CREATE TABLE ' || GC_CU_BAL_CHECK || 'tmp2_' ||
             INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              AS 
              SELECT u.SUBS_ID,
                     c.ACCT_ID,
                     C.BAL_ID,
                     NVL(C.CHARGE_FEE, 0) "PRE_CYCLE_BALANCE",
                     NVL(B.CHARGE_FEE, 0) "DUE",
                     NVL(A.CHARGE_FEE, 0) "CHARGE",
                     NVL(D.CHARGE_FEE, 0) "CUR_CYCLE_BAL",
                     c.acct_res_id
                FROM ' || GC_USER_TAB_NAME ||
             INV_BILLINGCYCLEID || ' u
                ,(SELECT BAL_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                        FROM ' || GC_ACCTBOOK_TAB_NAME ||
             'tmp_' || INV_BILLINGCYCLEID || '
                       GROUP BY BAL_ID) A,
                     (SELECT SUBS_ID, BAL_ID, SUM(CHARGE_FEE) AS "CHARGE_FEE"
                        FROM ' || GC_CDR_TAB_NAME || 'tmp_' ||
             INV_BILLINGCYCLEID || '
                       GROUP BY SUBS_ID, BAL_ID) B,
                     (SELECT acct_res_id, BAL_ID, acct_id,
                             SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                        FROM ' || INV_TBAL_A || '
                       GROUP BY acct_res_id,BAL_ID,acct_id) C,
                     (SELECT BAL_ID,
                             SUM(GROSS_BAL + RESERVE_BAL + CONSUME_BAL) AS "CHARGE_FEE"
                        FROM ' || INV_TBAL_B || '
                       GROUP BY BAL_ID) D
               WHERE C.BAL_ID = B.BAL_ID(+)
                 AND C.BAL_ID = A.BAL_ID(+)
                 AND C.BAL_ID = D.BAL_ID(+)
                 AND c.acct_id = u.CREDIT_ACCT
               GROUP BY u.SUBS_ID,
                        c.ACCT_ID,
                        C.BAL_ID,
                        A.CHARGE_FEE,
                        B.CHARGE_FEE,
                        C.CHARGE_FEE,
                        D.CHARGE_FEE,
                        c.acct_res_id
          ';
  
    -- DBMS_OUTPUT.PUT_LINE('V_SQL=' || V_SQL);
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t25' || INV_BILLINGCYCLEID || ' ON ' ||
             GC_CU_BAL_CHECK || 'tmp2_' || INV_BILLINGCYCLEID || '
                           (SUBS_ID,ACCT_RES_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    PP_PRINTLOG(3,
                'PP_INSERT_CHECK',
                SQLCODE,
                '新建临时表完成' || GC_CU_BAL_CHECK || 'tmp2_' ||
                INV_BILLINGCYCLEID);
  
    -- 生成最终新的CU_BAL_CHECK表
    V_SQL := 'CREATE TABLE ' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID || '
              TABLESPACE TAB_RB
              AS 
              SELECT SUBS_ID,
                     ACCT_ID,
                     ACCT_RES_ID,
                     SUM(PRE_CYCLE_BALANCE) "PRE_CYCLE_BALANCE",
                     SUM(DUE) "DUE",
                     SUM(CHARGE) "CHARGE",
                     SUM(CUR_CYCLE_BAL) "CUR_CYCLE_BAL"
                FROM ' || GC_CU_BAL_CHECK || 'tmp1_' ||
             INV_BILLINGCYCLEID || '
               GROUP BY SUBS_ID, ACCT_ID, ACCT_RES_ID
               ';
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
  
    PP_PRINTLOG(3,
                'PP_INSERT_CHECK',
                SQLCODE,
                '新cu_bal_check表建立完成,插入本金账本数据：' || GC_CU_BAL_CHECK ||
                INV_BILLINGCYCLEID);
  
    -- 建立索引
    V_SQL := 'CREATE INDEX IDX_balrp_t22' || INV_BILLINGCYCLEID || ' ON ' ||
             GC_CU_BAL_CHECK || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t23' || INV_BILLINGCYCLEID || ' ON ' ||
             GC_CU_BAL_CHECK || INV_BILLINGCYCLEID || '
                           (ACCT_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    V_SQL := 'CREATE INDEX IDX_balrp_t24' || INV_BILLINGCYCLEID || ' ON ' ||
             GC_CU_BAL_CHECK || INV_BILLINGCYCLEID || '
                           (ACCT_RES_ID) TABLESPACE IDX_RB';
    EXECUTE IMMEDIATE V_SQL;
  
    PP_PRINTLOG(3,
                'PP_INSERT_CHECK',
                SQLCODE,
                '索引建立完成：' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID);
  
    -- 更新信用账本数据到本金账本
    V_SQL := 'UPDATE /*+ rule */ ' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID ||
             ' A SET A.PRE_CYCLE_BALANCE = nvl(A.PRE_CYCLE_BALANCE,0) +
                             nvl((SELECT PRE_CYCLE_BALANCE
                                FROM ' || GC_CU_BAL_CHECK ||
             'tmp2_' || INV_BILLINGCYCLEID || ' B
                               WHERE A.SUBS_ID = B.SUBS_ID
                                 AND A.ACCT_RES_ID = B.ACCT_RES_ID),0)
             ';
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
    PP_PRINTLOG(3,
                'PP_INSERT_CHECK',
                SQLCODE,
                '更新信用账本帐前余额' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID);
  
    V_SQL := 'UPDATE /*+ rule */ ' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID ||
             ' A SET A.CUR_CYCLE_BAL = nvl(A.CUR_CYCLE_BAL,0) +
                             nvl((SELECT CUR_CYCLE_BAL
                                FROM ' || GC_CU_BAL_CHECK ||
             'tmp2_' || INV_BILLINGCYCLEID || ' B
                               WHERE A.SUBS_ID = B.SUBS_ID
                                 AND A.ACCT_RES_ID = B.ACCT_RES_ID),0)
             ';
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
    PP_PRINTLOG(3,
                'PP_INSERT_CHECK',
                SQLCODE,
                '更新信用账本帐后余额' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID);
  
    V_SQL := 'UPDATE /*+ rule */ ' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID ||
             ' A SET A.DUE = nvl(A.DUE,0) +
                             nvl((SELECT DUE
                                FROM ' || GC_CU_BAL_CHECK ||
             'tmp2_' || INV_BILLINGCYCLEID || ' B
                               WHERE A.SUBS_ID = B.SUBS_ID
                                 AND A.ACCT_RES_ID = B.ACCT_RES_ID),0)
             ';
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
    PP_PRINTLOG(3,
                'PP_INSERT_CHECK',
                SQLCODE,
                '更新信用账本消费' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID);
  
    V_SQL := 'UPDATE /*+ rule */ ' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID ||
             ' A SET A.CHARGE = nvl(A.CHARGE,0) +
                             nvl((SELECT CHARGE
                                FROM ' || GC_CU_BAL_CHECK ||
             'tmp2_' || INV_BILLINGCYCLEID || ' B
                               WHERE A.SUBS_ID = B.SUBS_ID
                                 AND A.ACCT_RES_ID = B.ACCT_RES_ID),0)
             ';
    EXECUTE IMMEDIATE V_SQL;
    COMMIT;
    PP_PRINTLOG(3,
                'PP_INSERT_CHECK',
                SQLCODE,
                '更新信用账本帐充值' || GC_CU_BAL_CHECK || INV_BILLINGCYCLEID);
  
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_CLEAR_TMP_TAB(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE) IS
  BEGIN
    -- PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_USER_TAB_NAME);
  
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_CDR_TAB_NAME);
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_CDR_TAB_NAME || 'TMP_');
  
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME);
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_ACCTBOOK_TAB_NAME || 'TMP_');
  
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_BAL_TAB_NAME || 'A_');
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_BAL_TAB_NAME || 'B_');
  
    -- PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_CU_BAL_CHECK);
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_CU_BAL_CHECK || 'TMP1_');
    PP_DEL_TMP_TAB(INV_BILLINGCYCLEID, GC_CU_BAL_CHECK || 'TMP2_');
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
  --开启DML多CPU
  EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SQLCODE=' || SQLCODE);
    DBMS_OUTPUT.PUT_LINE('SQLERRM=' || SQLERRM);
END BALRP_PKG_FOR_CUC;
/
