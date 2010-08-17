#!/usr/bin/env jython
#-*- coding:utf-8 -*-
#导入所有java类
from java.lang import *
from java.sql import *
#导入配置文件处理模块
import ConfigParser
from time import localtime, strftime, sleep
import logging
import signal
from sys import exit

def initLogging(inLogFile):
    myLog = None
    
    #设置日志名称属性
    myLog = logging.getLogger("BALWAP")
    
    #设置日志级别
    if ini.getConf('COMMON','LOG_LEVEL') == 'DEBUG':
        myLog.setLevel(logging.DEBUG)
    elif ini.getConf('COMMON','LOG_LEVEL') == 'INFO':
        myLog.setLevel(logging.INFO)
    elif ini.getConf('COMMON','LOG_LEVEL') == 'WARNING':
        myLog.setLevel(logging.WARNING)
    elif ini.getConf('COMMON','LOG_LEVEL') == 'ERROR':
        myLog.setLevel(logging.ERROR)
    elif ini.getConf('COMMON','LOG_LEVEL') == 'CRITICAL':
        myLog.setLevel(logging.CRITICAL)
    else:
        print u"错误的日志级别[%s]".encode('utf8') % ini.getConf('COMMON','LOG_LEVEL')
        
    #设置日志内容格式
    formatter = logging.Formatter("%(asctime)s [%(levelname)s|%(process)d] <%(module)s|%(funcName)s|%(lineno)d> %(message)s")
    
    #添加输出到文件句柄
    fh = logging.FileHandler(inLogFile)
    #fh.setLevel(logging.DEBUG)
    fh.setFormatter(formatter)
    myLog.addHandler(fh)
    
    #添加输出到屏幕句柄
    if int(ini.getConf('COMMON','LOG_TERM_SHOW')) == 1:
        ch = logging.StreamHandler()
        #ch.setLevel(logging.ERROR)
        ch.setFormatter(formatter)
        myLog.addHandler(ch)
    
    return myLog
    
class InitFile(object):
    '''处理配置文件类'''
    def __init__(self, inFile='bal_wap.ini'):
        self.iniFile = inFile
        self.conf = ConfigParser.ConfigParser()
        self.conf.readfp(open(self.iniFile))
        
    def getConf(self, section, option):
        '''获取指定配置的值'''
        return self.conf.get(section, option)
        
    def setConf(self, section, option, value):
        '''设置指定配置的值'''
        return self.conf.set(section, option, value)
        
    def writeConf(self):
        '''将配置写入配置文件'''
        fh = open(self.iniFile, 'wb')
        self.conf.write(fh)
        fh.close()
        
    def defaults(self):
        '''获取defaults的值，即配置文件中的[DEFAULT]'''
        return self.conf.defaults()
            
class DB_JDBC(object):
    '''JDBC内部重载'''
    def __init__(self):
        '''
        初始化JDBC链接
        '''
        self.con   = None
        self.pStmt = None
        self.re    = None
        self.sql   = None
        self.fetchSize = int(ini.getConf('COMMON','FETCH_LIMIT'))
        
    def __del__(self):
        '''
        类的清理，需要将数据库链接关闭
        '''
        del self.sql
        
        self.con.commit()
        myLog.info(u'强制提交未提交事物！')
        
        self.re.close()
        self.pStmt.close()
        self.con.close()
        myLog.info(u'关闭数据库连接!')
        
        del self.re
        del self.pStmt
        del self.con
        
    def queryData(self, sqlTemplate, sqlParam, paramFiledType):
        '''
        查询数据
        sqlTemplate         为sql模板
        sqlParam            为sql参数的数组
            参数1           获取数据的截至时间
            参数2           [SQL_TEMPLATE×]=>SELECT_FIELD_TYPE 解析为Dict的数据类型
        返回查询的结果
        '''
        myLog.debug("sqlParam=%s" % repr(sqlParam))
        myLog.debug("_n=%d" % len(sqlParam))
        self.sql = sqlTemplate
        
        self.preStmt(self.sql)
        
        self.pStmt.setFetchSize(self.fetchSize)
        
        #根据设置的数据类型，设置查询参数
        for _n in range(1, len(sqlParam) + 1):
            if paramFiledType[_n] == 'string':
                self.pStmt.setString(_n, sqlParam[_n-1])
            elif paramFiledType[_n] == 'int':
                self.pStmt.setInt(_n, sqlParam[_n-1])
            elif paramFiledType[_n] == 'long':
                self.pStmt.setLong(_n, sqlParam[_n-1])
            elif paramFiledType[_n] == 'float':
                self.pStmt.setFloat(_n, sqlParam[_n-1])
            else:
                myLog.critical(u'配置错误，未知的类型：%s'
                                % paramFiledType[_n])
        
        self.rs = self.pStmt.executeQuery()
        return self.rs
        
    def fetchNext(self):
        '''选择下一条数据'''
        return self.rs.next()
        
    def getString(self, inString):
        '''根据字段名称获取具体字段值，也可以根据字段位置获取'''
        return self.rs.getString(inString)
        
    def getInt(self, inInt):
        '''根据字段名称获取具体字段值'''
        return self.rs.getInt(inInt)
        
    def getFloat(self, inFloat):
        '''根据字段名称获取具体字段值'''
        return self.rs.getFloat(inFloat)
        
    def getLong(self, inLong):
        '''根据字段名称获取具体字段值'''
        return self.rs.getLong(inLong)
        
    def preStmt(self, inSql):
        self.pStmt = self.con.prepareStatement(inSql)
        return self.pStmt
        
    def dataDelete(self, inArray, fieldTypeDict):
        '''
        根据DELETE_SQL和对应的DELETE_KEY删除表中原有数据
        注意DELETE_KEY就是SELECT_SQL中的select字段位置
        inarray         为一个数组,每个数组元素均为一个dict
                        [{1:'', 2:'' ...},{},{}...]
        fieldtypedict   是表示字段数据类型的一个dict
        '''
        _dNumber = 0
        
        #获取删除key
        _deleteKey = ini_sql.getConf('SQL_TEMPLATE1','DELETE_KEY').split(',')
        
        #根据删除key从数据中获取删除参数
        for _dict in inArray:
            myLog.debug(u'从当前数组中获取删除KEY：%s' % _dict)
            _dNumber += 1
            
            #解析传入字典，从中获取DELETE_KEY
            for _k in _deleteKey:
                myLog.debug(u'添加DELETE_KEY=[%s]' % repr(_k))
                myLog.debug(u'添加DELETE_VALUE=[%s]' % repr(_dict[int(_k)]))
                #self.pStmt.setInt(int(_k), _dict[int(_k))])
                
                if fieldTypeDict[int(_k)] in ['int']:
                    self.pStmt.setInt(int(_k), _dict[int(_k)])
                elif fieldTypeDict[int(_k)] in ['long']:
                    self.pStmt.setLong(int(_k), _dict[int(_k)])
                elif fieldTypeDict[int(_k)] == 'string':
                    self.pStmt.setString(int(_k), _dict[int(_k)])
                elif fieldTypeDict[int(_k)] == 'float':
                    self.pStmt.setFloat(int(_k), _dict[int(_k)])
                else:
                    myLog.critical(u'配置错误，不支持的数据类型：%s'
                                    % fieldTypeDict[int(_k)])
                
            myLog.debug(u'数据完成初始化![%s]' % _dict)
            self.pStmt.addBatch()
            
            if (_dNumber % self.fetchSize == 0):
                myLog.info(u'已删除数据[%d]条！' % _dNumber)
                self.pStmt.executeBatch()
                self.con.commit()
        
        myLog.debug(u'所有数据[%d]初始化完成！%s' % (_dNumber, inArray))
        
        #提交数据
        myLog.debug(u'批量提交数据！')
        self.pStmt.executeBatch()
        myLog.debug(u'批量Commit数据！')
        self.con.commit()
        
        return _dNumber
        
    def dataInsert(self, inArray, fieldTypeDict):
        '''
        根据传入的数据与字段类型，将如数插入表中
        inarray         为一个数组,每个数组元素均为一个dict
                        [{1:'', 2:'' ...},{},{}...]
        fieldtypedict   是表示字段数据类型的一个dict
        '''
        _inumber = 0
        for _dict in inArray:
            myLog.debug(u'准备提交数据：%s' % _dict)
            _inumber += 1
            
            #根据数据类型，将字段分别压入insert语句
            for (_dkey, _dvalue) in _dict.items():
                if fieldTypeDict[_dkey] in ['int']:
                    myLog.debug( "%d=%d" % (_dkey, _dvalue ))
                    self.pStmt.setInt(_dkey, _dvalue)
                elif fieldTypeDict[_dkey] in ['long']:
                    myLog.debug( "%d=%d" % (_dkey, _dvalue ))
                    self.pStmt.setLong(_dkey, _dvalue)
                elif fieldTypeDict[_dkey] == 'string':
                    myLog.debug( "%d=%s" % (_dkey, _dvalue ))
                    self.pStmt.setString(_dkey, _dvalue)
                elif fieldTypeDict[_dkey] == 'float':
                    myLog.debug( "%d=%f" % (_dkey, _dvalue ))
                    self.pStmt.setFloat(_dkey, _dvalue)
                else:
                    myLog.critical(u'配置错误，不支持的数据类型：%s'
                                   % fieldTypeDict[_dkey])
                    
            myLog.debug(u'数据完成初始化![%s]' % _dict)
            self.pStmt.addBatch()
            
            if ( _inumber % self.fetchSize == 0):
                myLog.info(u'已插入数据[%d]条！' % _inumber)
                self.pStmt.executeBatch()
                self.con.commit()
        
        myLog.debug(u'所有数据初始化完成！%s' % inArray)
        
        #提交数据
        myLog.debug(u'批量提交数据！')
        self.pStmt.executeBatch()
        myLog.debug(u'批量Commit数据！')
        self.con.commit()
        
        return _inumber
        
class JDBC_TimesTen(DB_JDBC):
    '''TimesTen的JDBC类'''
    def __init__(self,ttIn_dsn,ttIn_uid,ttIn_pwd):
        '''
        对TimesTen的JDBC链接进行初始化
        ttIn_dsn    TimesTen的DSN名称
        ttIn_uid    TimesTen的用户名
        ttIn_pwd    TimesTen的密码
        '''
        DB_JDBC.__init__(self)
        
        #建立JDBC链接
        Class.forName("com.timesten.jdbc.TimesTenDriver")
        DriverManager.setLoginTimeout(5)
        self.con = DriverManager.getConnection("jdbc:timesten:direct:dsn=%s;uid=%s;pwd=%s;"
                                        % (ttIn_dsn, ttIn_uid, ttIn_pwd))
        
        #取消自动commit
        self.con.setAutoCommit(False)
        
        #创建链接声明
        self.stmt = self.con.createStatement()
        
        #设置查询超时时间
        self.stmt.setQueryTimeout(10)
        
    def __del__(self):
        DB_JDBC.__del__(self)
        
class JDBC_Altibase(DB_JDBC):
    '''Altibase的JDBC类'''
    def __init__(self,abIn_ip, abIn_port, abIn_dsn, abIn_uid, abIn_pwd, abIn_Enc='US7ASCII'):
        '''
        对TimesTen的JDBC链接进行初始化
        abIn_ip     Altibase的主机IP
        abIn_port   Altibase的监听端口
        abIn_dsn    Altibase的DB_NAME名称
        abIn_uid    Altibase的用户名
        abIn_pwd    Altibase的密码
        abIn_Enc    Altibase的编码类型
        '''
        DB_JDBC.__init__(self)
        
        #建立JDBC链接
        Class.forName("Altibase.jdbc.driver.AltibaseDriver")
        DriverManager.setLoginTimeout(5)
        self.con = DriverManager.getConnection(
                   "jdbc:Altibase://%s:%s/%s?user=%s&password=%s&encoding=%s"
                   % (abIn_ip, abIn_port, abIn_dsn, abIn_uid, abIn_pwd, abIn_Enc))
        
        #取消自动commit
        self.con.setAutoCommit(False)
        
        #创建链接声明
        self.stmt = self.con.createStatement()
        
        #设置查询超时时间
        self.stmt.setQueryTimeout(10)
        
    def __del__(self):
        DB_JDBC.__del__(self)
        
class JDBC_Oracle(DB_JDBC):
    '''TimesTen的JDBC类'''
    def __init__(self, oraIn_ip, oraIn_port, oraIn_dsn, oraIn_uid, oraIn_pwd):
        '''
        对TimesTen的JDBC链接进行初始化
        oraIn_ip        Oracle主机IP
        oraIn_port      Oracle主机监听端口
        oraIn_dsn       Oracle的SID名称
        oraIn_uid       Oracle的用户名
        oraIn_pwd       Oracle的密码
        '''
        DB_JDBC.__init__(self)
        
        #建立JDBC链接
        Class.forName("oracle.jdbc.driver.OracleDriver")
        DriverManager.setLoginTimeout(10)
        self.con = DriverManager.getConnection("jdbc:oracle:thin:@%s:%s:%s" %
                                           ( oraIn_ip, oraIn_port, oraIn_dsn),
                                             oraIn_uid, oraIn_pwd )
        
        #取消自动commit
        self.con.setAutoCommit(False)
        
        #创建链接声明
        self.stmt = self.con.createStatement()
        
        #设置查询超时时间
        self.stmt.setQueryTimeout(20)
        
    def __del__(self):
        DB_JDBC.__del__(self)
        
class UpdateArray(object):
    '''需要更新的数据类'''
    def __init__(self):
        self.array=[]
        self.dict={}
        self.count=1
        
    def __del__(self):
        myLog.debug(u'清理临时数据对象！')
        del self.array
        del self.dict
        del self.count
        
    def add(self, inVar):
        if self.count not in (7, 8, 9):
            self.dict[self.count] = inVar
        else:
            self.dict[self.count] = str(inVar)
            
        self.count += 1
        
    def addBatch(self):
        self.count=1
        self.array.append(self.dict)
        self.dict={}
        
    def out(self):
        print self.array
        
class SyncEngine(object):
    '''同步数据管理引擎'''
    def __init__(self, inTemplateNumber, inUpTime):
        '''
        inDbSeq         传入数据库模板编号
        '''
        #实例化数组管理类
        self.myArray = UpdateArray()
        
        self.templateNumber = inTemplateNumber
        
        #获取更新的截至时间
        self.localTime = inUpTime
        
        #获取MDB链接信息
        self.mdbType = ini.getConf('COMMON','MDB_TYPE')
        
        if self.mdbType == 'TT':
            self.mdbDsn = ini.getConf('TIMESTEN','TT_DSN')
            self.mdbUid = ini.getConf('TIMESTEN','TT_UID')
            self.mdbPwd = ini.getConf('TIMESTEN','TT_PWD')
        elif self.mdbType == 'AB':
            self.mdbIp  = ini.getConf('ALITBASE','AB_IP')
            self.mdbPort= ini.getConf('ALITBASE','AB_PORT')
            self.mdbDsn = ini.getConf('ALITBASE','AB_DBNAME')
            self.mdbUid = ini.getConf('ALITBASE','AB_USER')
            self.mdbPwd = ini.getConf('ALITBASE','AB_PASSWORD')
            self.mdbEnc = ini.getConf('ALITBASE','AB_ENCODING')
        else:
            myLog.critical(u'配置错误，不可识别的MDB类型：%s' % self.mdbType)
        
        #获取Oracle链接信息
        self.oraUsr = ini.getConf('COMMON','ORA_USR')
        self.oraPwd = ini.getConf('COMMON','ORA_PWD')
        self.oraIp  = ini.getConf('COMMON','ORA_IP')
        self.oraPort = ini.getConf('COMMON','ORA_PORT')
        self.oraSid = ini.getConf('COMMON','ORA_SID')
        
        myLog.info('链接Oracle：[%s/%s@%s:%s:%s]' % ( self.oraUsr, self.oraPwd,
                    self.oraIp, self.oraPort, self.oraSid))
        self.ora = JDBC_Oracle(self.oraIp, self.oraPort,
                               self.oraSid, self.oraUsr, self.oraPwd )
        
        self.mdb = None
        
    def wConf(self):
        '''将更新时间写入配置文件'''
        myLog.info(u'将更新时间写入配置文件')
        ini_sql.defaults()['update_date']=self.localTime
        ini_sql.writeConf()
        
    def __del__(self):
        del self.myArray
        del self.mdb
        del self.ora
        
    def loadData(self):
        '''从MDB中获取数据'''
        if (self.mdbType == 'TT'):
            myLog.info(u'从TimesTen库中获取数据：[%s/%s@%s]'
                            % ( self.mdbDsn, self.mdbUid, self.mdbPwd )
                      )
                      
            #链接MDB数据库
            self.mdb = JDBC_TimesTen( self.mdbDsn, self.mdbUid, self.mdbPwd )
            myLog.info(u'链接数据库成功！')
        elif (self.mdbType == 'AB'):
            myLog.info(u'从Altibase库中获取数据：[//%s:%s/%s?user=%s&password=%s&encoding=%s]'
              % (self.mdbIp, self.mdbPort, self.mdbDsn, self.mdbUid, self.mdbPwd, self.mdbEnc )
                  )
                  
            #链接MDB数据库
            self.mdb = JDBC_Altibase( self.mdbIp, self.mdbPort, self.mdbDsn,
                                     self.mdbUid, self.mdbPwd, self.mdbEnc )
            myLog.info(u'链接数据库成功！')
        
        #解析字段类型
        ft = FiledType(ini_sql.getConf('SQL_TEMPLATE' + self.templateNumber,
                                       'SELECT_FIELD_TYPE'))
        fieldTypeDict = ft.parseStr()
        
        ft = FiledType(ini_sql.getConf('SQL_TEMPLATE' + self.templateNumber,
                                       'SELECT_PARAM_TYPE'))
        _dict = ft.parseStr()
        myLog.debug(u'sql参数数据类型为：%s' % repr(_dict))
        
        #获取模板信息
        selSqlTemplate = ini_sql.getConf('SQL_TEMPLATE' + self.templateNumber,
                                         'SELECT_SQL')
        myLog.debug(u'获取数据模板：[%s]' % selSqlTemplate)
        
        #获取数据集
        self.mdb.queryData(selSqlTemplate, (self.localTime,), _dict )
        
        _qNumber = 0
        while (self.mdb.fetchNext()):
            _qNumber += 1
            for _num in range(1,max(fieldTypeDict)+1):
                if fieldTypeDict[_num] in ['int']:
                    myLog.debug( "%d=%d" % (_num, self.mdb.getInt(_num)) )
                    self.myArray.add(self.mdb.getInt(_num))
                elif fieldTypeDict[_num] == 'long':
                    myLog.debug( "%d=%d" % (_num, self.mdb.getLong(_num)) )
                    self.myArray.add(self.mdb.getLong(_num))
                elif fieldTypeDict[_num] == 'string':
                    myLog.debug( "%d=%s" % (_num, self.mdb.getString(_num)) )
                    self.myArray.add(self.mdb.getString(_num))
                elif fieldTypeDict[_num] == 'float':
                    myLog.debug( "%d=%f" % (_num, self.mdb.getFloat(_num)) )
                    self.myArray.add(self.mdb.getFloat(_num))
                else:
                    myLog.critical(u'配置错误，不支持的数据类型：%s' % fieldTypeDict[_num])
                    
            #一条数据加载完毕
            myLog.debug(u'本批数据已经获取完毕：%s' % self.myArray.dict)
            self.myArray.addBatch()
            
            if (_qNumber % int(ini.getConf('COMMON','FETCH_LIMIT')) == 0):
                myLog.info(u'加载数据[%s]条！' % _qNumber)
                
        return _qNumber
        
    def out(self):
        '''将需入库数据打印出来'''
        self.myArray.out()
        
    def insertData(self):
        '''将数据插入Oracle'''
        insSqlTemplate = ini_sql.getConf('SQL_TEMPLATE' + self.templateNumber,
                                         'INSERT_SQL')
        
        myLog.debug(u'获取数据模板：[%s]' % insSqlTemplate)
        
        myLog.info(u'预编译插入数据模板。。。')
        self.ora.preStmt(insSqlTemplate)
        
        ft = FiledType(ini_sql.getConf('SQL_TEMPLATE' + self.templateNumber, 'SELECT_FIELD_TYPE'))
        _dict = ft.parseStr()
        myLog.debug(u'字段数据类型为：%s' % repr(_dict))
        
        myLog.info(u'开始插入数据。。。')
        iNumber = self.ora.dataInsert(self.myArray.array, _dict)
        myLog.info(u'插入数据完成！共插入数据[%s]条' % iNumber)
        
        #将更新时间写入配置文件
        #self.wConf()
        
    def deleteData(self):
        '''删除Oracle中需更新数据'''
        delSqlTemplate = ini_sql.getConf('SQL_TEMPLATE' + self.templateNumber,
                                         'DELETE_SQL')
        myLog.debug(u'获取数据模板：[%s]' % delSqlTemplate)
        
        myLog.info(u'预编译删除数据模板。。。')
        self.ora.preStmt(delSqlTemplate)
        
        ft = FiledType(ini_sql.getConf('SQL_TEMPLATE' + self.templateNumber, 'DELETE_PARAM_TYPE'))
        _dict = ft.parseStr()
        myLog.debug(u'字段数据类型为：%s' % repr(_dict))
        
        myLog.info(u'开始删除数据。。。')
        iNumber = self.ora.dataDelete(self.myArray.array, _dict)
        myLog.info(u'删除数据完成！删除数据[%s]条' % iNumber)
        
class FiledType(object):
    '''用来保存，解析字段类型的类'''
    def __init__(self, inFiledTypeStr):
        self.fileTypeStr = inFiledTypeStr
        self.dict = {}
        
    def __del__(self):
        del self.fileTypeStr
        del self.dict
        
    def parseStr(self):
        '''将字段类型的字符串解析为一个字典类型返回'''
        myLog.debug('准备解析字符串：%s' % self.fileTypeStr)
        for _s in self.fileTypeStr.split(','):
            myLog.debug('切割后元素：%s' % _s)
            [_key, _value] = _s.split(':')
            myLog.debug('_key=%s, _value=%s' % (_key, _value))
            self.dict[int(_key)] = _value
            
        return self.dict
        
    def out(self, inKey):
        '''将解析后的字典打印出来'''
        print self.dict[inKey]
        
def sigHdTerm(n=0, e=0):
    '''当收到Kill信号后需要做的操作'''
    myLog.warning(u'收到结束信号，准备退出程序，请稍候。。。')
    exit(2)
    
if __name__ == '__main__':
    signal.signal(signal.SIGTERM, sigHdTerm)
    signal.signal(signal.SIGINT, sigHdTerm)
    
    try:
        # 实例化配置文件
        ini = InitFile()
        # 实例化模板配置文件
        ini_sql = InitFile('bal_wap_sql.ini')
    
        # 初始化日志
        myLog = initLogging(ini.getConf('COMMON','LOG_FILENAME'))
        
        #获取需要同步的模板数
        defTmpNbr = int(ini_sql.defaults()['template_num'])
        
        #获取UP_RATE，扫描间隔时间，默认不小于600秒AST
        upRate = int(ini.getConf('COMMON','UP_RATE'))
        myLog.info(u'获取到更新时间间隔：%s' % upRate)
        if upRate < 600:
            myLog.warning(u'同步间隔小于600秒，强制设置为600秒')
            upRate = 600
            
        sTime = ini_sql.defaults()['update_date']
        myLog.info(u'更新开始时间：[%s]' % sTime)
        
    except Exception, e:
        myLog.error(u'配置读取错误：%s' % e)
        exit(1)
    
    try:
        #死循环，让程序不停运行
        while True:
            #获取同步更新时间点
            procTime = str(strftime("%Y%m%d%H%M%S", localtime()))
            myLog.info(u'更新截止时间：[%s]' % procTime)
            
            #开始一次同步
            for tNbr in range(1,defTmpNbr+1):
                myLog.info(u'开始同步模板：[SQL_TEMPLATE%d]' % tNbr)
                #从MDB库中获取数据
                se = SyncEngine(str(tNbr), procTime)
                
                myCount = se.loadData()
                myLog.info(u'共获取到数据[%d]条！' % myCount)
                if (myCount > 0):
                    #se.out()
                    #删除表中已有数据
                    se.deleteData()
                    #插入需更新数据
                    se.insertData()
                    #将跟新时间点写入配置文件
                    se.wConf()
                
                del se
                
            #同步间隔
            myLog.info(u'同步间隔休息。。。[%d]秒' % upRate)
            sleep(upRate)
    except Exception, e:
        myLog.error(u'程序异常错误，退出:%s' % e)
        exit(1)
