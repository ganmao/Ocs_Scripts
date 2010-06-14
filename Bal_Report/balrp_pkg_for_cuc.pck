CREATE OR REPLACE PACKAGE BALRP_PKG_FOR_CUC IS

  -- Author  : zhang.dongliang@zte.com.cn
  -- Created : 2010-06-03 13:33:33
  -- Purpose : the balance report for CUC

  -- ==================================================
  -- 以下部分需要现场根据情况自己配置
  -- ==================================================
  -- 定义具体的使用地市
  -- 河北(HB)，山东(SD)，内蒙(NM)，甘肃(GS)
  GC_PROVINCE CONSTANT CHAR(2) := 'HB';

  -- 需要统计的余额类型
  GC_RES_TYPE CONSTANT VARCHAR2(100) := '52';

  -- 指定采用CPU数,危险参数！需要根据现场cpu进行设置，一般为cpu的两倍
  GC_CPU_NUM CONSTANT NUMBER := 24;

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
                               INV_TABLENAME      USER_TABLES.TABLE_NAME%TYPE,
                               INV_TBAL_A         USER_TABLES.TABLE_NAME%TYPE,
                               INV_TBAL_B         USER_TABLES.TABLE_NAME%TYPE);

  -- 根据各个地市生成不同统计报表
  PROCEDURE PP_BUILD_REPORT(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE);

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
    DBMS_OUTPUT.PUT_LINE('开始调用存储过程[balrp_pkg_for_cuc.pp_main]，详细日志请见：' ||
                         GC_PROC_LOG || ',报表结果详见：' || GC_REPORT_TAB ||
                         V_BILLINGCYCLEID);
    --EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
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
  
    -- 获取上月帐务周期ID
    V_BILLINGCYCLEID := PF_GETLOCALCYCLEID();
  
    -- 采集用户信息数据
    PP_PRINTLOG(3, 'PP_MAIN', 0, '开始采集用户信息...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
    PP_COLLECT_USERINFO(V_BILLINGCYCLEID, GC_USER_TAB_NAME);
    PP_PRINTLOG(3, 'PP_MAIN', 0, '采集用户信息完成！');
  
    -- 采集用户语音话单
    PP_PRINTLOG(3, 'PP_MAIN', 0, '开始采集CDR信息...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_CDR_TAB_NAME);
    PP_COLLECT_CDR(V_BILLINGCYCLEID, GC_CDR_TAB_NAME);
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
  
    -- 开始生成报表
    PP_PRINTLOG(3, 'PP_MAIN', 0, '开始生成报表...');
    PP_DEL_TMP_TAB(V_BILLINGCYCLEID, GC_REPORT_TAB);
    PP_BUILD_REPORT(V_BILLINGCYCLEID);
    PP_PRINTLOG(3,
                'PP_MAIN',
                0,
                '用户余额报表生成完毕，见表：' || GC_REPORT_TAB || V_BILLINGCYCLEID);
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
                  '表创建成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
    
      -- 创建表索引
      V_SQL := 'CREATE INDEX IDX_balrp_usr_sub' || INV_BILLINGCYCLEID ||
               ' ON ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
                           (SUBS_ID) TABLESPACE IDX_RB';
      EXECUTE IMMEDIATE V_SQL;
    
      PP_PRINTLOG(5,
                  'PP_COLLECT_USERINFO',
                  SQLCODE,
                  '表索引创建成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
    
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
                '插入EVENT_CHARGE数据完成！' || V_TMP_TABLE || INV_BILLINGCYCLEID);
    COMMIT;
  
    ------------------数据合并----------------------
    -- 将采集的各个数据进行再次合并后放入正式CDR表
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
                '话单信息收集完毕！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    V_SQL := 'alter table ' || INV_TABLENAME || INV_BILLINGCYCLEID ||
             ' modify RE_ID null';
    EXECUTE IMMEDIATE V_SQL;
  
    -- 创建表索引
    V_SQL := 'CREATE INDEX IDX_balrp_cdr_sub' || INV_BILLINGCYCLEID ||
             ' ON ' || INV_TABLENAME || INV_BILLINGCYCLEID || '
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
                '本帐期一次性费费用插入完毕！' || GC_CDR_TAB_NAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 创建用户缴费信息统计表
    -- 统计用户 现金缴费 SERVICE_TYPE = 200
    -- 999001是开户预存款，999999是预存转兑（可以在配置文件中配置）
    -- 现在将999999归入先进缴费统计中,现场可以根据余额类型将其剔除
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
                '本帐期用户缴费信息表建立完毕！' || INV_TABLENAME || INV_BILLINGCYCLEID);
  
    PP_PRINTLOG(3,
                'PP_COLLECT_ACCTBOOK',
                0,
                '插入用户现金缴费完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 一卡冲缴费 SERVICE_TYPE = 201
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
                '插入用户一卡冲缴费数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 开户预存款 SERVICE_TYPE = 202
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
                '插入用户开户预存款数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 银行卡充值 SERVICE_TYPE = 203
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
                '插入用户银行卡充值数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 统计用户 空中充值 SERVICE_TYPE = 204
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
                '插入用户空中充值数据完成！' || INV_TABLENAME || INV_BILLINGCYCLEID);
    COMMIT;
  
    -- 创建表索引
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
    
      -- 生成A表的中间表（筛选数据）
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
    
      -- 生成B表的中间表（筛选数据）
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
                  '用户月末信息表收集完成：' || INV_TABLENAME || 'B_' ||
                  INV_BILLINGCYCLEID);
      COMMIT;
    
      -- 创建索引
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
                  '表索引创建成功：' || INV_TABLENAME || INV_BILLINGCYCLEID);
    ELSE
      PP_PRINTLOG(1,
                  'PP_COLLECT_BALINFO',
                  SQLCODE,
                  '传入的余额信息表不存在！A=' || INV_TBAL_A || ' B=' || INV_TBAL_B);
    END IF;
  END;

  -------------------------------------------------------------------------------
  PROCEDURE PP_BUILD_REPORT(INV_BILLINGCYCLEID BILLING_CYCLE.BILLING_CYCLE_ID@LINK_CC%TYPE) IS
    V_SQL VARCHAR2(4000);
  BEGIN
  
    -- 开始生成内蒙报表
    IF GC_PROVINCE = 'NM' THEN
      V_SQL := 'CREATE TABLE ' || GC_REPORT_TAB || INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT U.ACC_NBR "用户号码",
                       U.AREA_ID "地区ID",
                       U.SUBS_CODE "用户标识",
                       SUM(B1.GROSS_BAL + B1.RESERVE_BAL + B1.CONSUME_BAL) "月初余额",
                       SUM(A.CHARGE_FEE) "本月充值",
                       SUM(C.CHARGE_FEE) "本月消费",
                       SUM(B2.GROSS_BAL + B1.RESERVE_BAL + B1.CONSUME_BAL) "月末余额"
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
               ' "帐务月份",
                       A.AREA_ID "地市编码",
                       NVL(ABS(SUM(B1.CHARGE_FEE)),0) "期初",
                       NVL(ABS(SUM(A1.CHARGE_FEE)),0) "现金缴费",
                       NVL(ABS(SUM(A2.CHARGE_FEE)),0) "开户预存款",
                       NVL(ABS(SUM(A3.CHARGE_FEE)),0) "一卡充",
                       NVL(ABS(SUM(A4.CHARGE_FEE)),0) "空中充值",
                       NVL(ABS(SUM(C.CHARGE_FEE)),0) "本期减少",
                       NVL(ABS(SUM(B2.CHARGE_FEE)),0) "月末余额",
                       NVL(ABS(SUM(B3.CHARGE_FEE)),0) "月末余额（正）",
                       NVL(ABS(SUM(B4.CHARGE_FEE)),0) "月末余额（负）",
                       NVL((ABS(SUM(B2.CHARGE_FEE)) - ABS(SUM(B3.CHARGE_FEE)) +
                       ABS(SUM(B4.CHARGE_FEE))),0) "校验"
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
      -- 地市、号码、月初余额、月中充值、月中消费、月末余额。
      -- 月初余额+月中充值-月中消费=月末余额
      NULL;
      V_SQL := 'CREATE TABLE ' || GC_REPORT_TAB || INV_BILLINGCYCLEID || '
                TABLESPACE TAB_RB
                NOLOGGING
                AS
                SELECT U.ACC_NBR "用户号码",
                       U.AREA_ID "地市",
                       NVL(SUM(BA.GROSS_BAL + BA.RESERVE_BAL + BA.CONSUME_BAL), 0) "月初余额",
                       NVL(SUM(A.CHARGE_FEE), 0) "月中充值",
                       NVL(SUM(C.CHARGE_FEE), 0) "月中消费",
                       NVL(SUM(BB.GROSS_BAL + BB.RESERVE_BAL + BB.CONSUME_BAL), 0) "月末余额",
                       NVL((SUM(BA.GROSS_BAL + BA.RESERVE_BAL + BA.CONSUME_BAL) +
                           SUM(A.CHARGE_FEE) - SUM(C.CHARGE_FEE)),
                           0) "月末余额校验"
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
  --开启DML多CPU
  EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SQLCODE=' || SQLCODE);
    DBMS_OUTPUT.PUT_LINE('SQLERRM=' || SQLERRM);
END BALRP_PKG_FOR_CUC;
/
