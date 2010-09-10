CREATE TABLE BAL_WAP(
    BAL_ID          NUMBER(38),
    ACCT_ID         INTEGER,
    ACCT_RES_ID     INTEGER,
    GROSS_BAL       NUMBER(38),
    RESERVE_BAL     NUMBER(38),
    CONSUME_BAL     NUMBER(38),
    RATING_BAL      NUMBER(38),
    BILLING_BAL     NUMBER(38),
    EFF_DATE        DATE,
    EXP_DATE        DATE,
    UPDATE_DATE     DATE,
    CEIL_LIMIT      NUMBER(38),
    FLOOR_LIMIT     NUMBER(38),
    DAILY_CEIL_LIMIT   NUMBER(38),
    DAILY_FLOOR_LIMIT  NUMBER(38),
    PRIORITY           INTEGER,
    LAST_BAL           NUMBER(38),
    LAST_RECHARGE      NUMBER(38),
    BAL_CODE           NUMBER(38),
    PRIMARY KEY(BAL_ID)
) tablespace tab_rb;

CREATE INDEX bal_wap_bal_id ON bal_wap (bal_id) TABLESPACE idx_rb;
--CREATE UNIQUE INDEX bal_wap_bal_code ON bal_wap (bal_code) TABLESPACE idx_rb;