jython安装方法：
==============================================================================
1，将jython_installer-2.5.1.jar上传到scripts目录下

2，在scripts目录下建立目录jython
scripts >mkdir jython
scripts >cd jython

3，保证本机安装java 1.5或以上版本
scripts >which java
/usr/java5/jre/bin/java

4，安装过程：
scripts >/usr/java5/jre/bin/java -jar jython_installer-2.5.1.jar -c
Welcome to Jython !
You are about to install Jython version 2.5.1
(at any time, answer c to cancel the installation)
For the installation process, the following languages are available: English, German
Please select your language [E/g] >>> E
Do you want to read the license agreement now ? [y/N] >>> N
Do you accept the license agreement ? [Y/n] >>> Y
The following installation types are available:
  1. All (everything, including sources)
  2. Standard (core, library modules, demos and examples, documentation)
  3. Minimum (core)
  9. Standalone (a single, executable .jar)
Please select the installation type [ 1 /2/3/9] >>> 2
Do you want to install additional parts ? [y/N] >>> N
Do you want to exclude parts from the installation ? [y/N] >>> N
Please enter the target directory >>> /ztesoft/ocsr11/scripts/jython
Please enter the java home directory (empty for using the current java runtime) >>>                        
Your java version to start Jython is: IBM Corporation / 1.5.0
Your operating system version is: AIX / 5.3
This operating system might not be fully supported.
Please press Enter to proceed anyway >>> 
Summary:
  - mod: true
  - demo: true
  - doc: true
  - src: false
  - JRE: /usr/java5/jre
Please confirm copying of files to directory /ztesoft/ocsr11/scripts/jython [Y/n] >>> Y
 10 %
 20 %
 30 %
 40 %
 50 %
 60 %
 70 %
 80 %
 90 %
Generating start scripts ...
 100 %
Do you want to show the contents of README ? [y/N] >>> 
Congratulations! You successfully installed Jython 2.5.1 to directory /ztesoft/ocsr11/scripts/jython.

5，替换原有执行脚本
scripts >cd jython
scripts/jython >mv jython jython_bash
将附件中提供的jython文件放入目录下
scripts/jython >chmod 755 jython
    
6，修改jython文件中的环境变量
JAVA_HOME，JYTHON_HOME，CLASSPATH 都需要根据实际情况修改
CP需要根据现场情况，
    TT库要找到对应的ttjdbc5.jar
    DB库要找到对应的Altibase.jar

7，同步脚本放入scripts目录，根据需要修改ini的配置文件

8，首次使用请将bal_wap_sql.ini文件中的DEFAULT=>update_date修改为一个较早前时间，以便将数据初始化入oracle

9，运行，检查一下配置是否存在问题
scripts/jython >jython
*sys-package-mgr*: processing new jar, '/ztesoft/ocsr11/scripts/jython/jython.jar'
*sys-package-mgr*: processing new jar, '/oracle/product/102/jdbc/lib/ojdbc14_g.jar'
*sys-package-mgr*: processing new jar, '/ztesoft/altibase/altibase_home/lib/Altibase.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/vm.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/core.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/charsets.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/graphics.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/security.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ibmpkcs.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ibmorb.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ibmcfw.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ibmorbapi.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ibmjcefw.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ibmjgssprovider.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ibmjsseprovider2.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ibmjaaslm.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ibmcertpathprovider.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/server.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/xml.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/CmpCrmf.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/IBMKeyManagementServer.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/dtfj-interface.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/dtfj.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/gskikm.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/indicim.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/ibmcmsprovider.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/ibmsaslprovider.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/ibmjcefips.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/ibmjceprovider.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/ibmkeycert.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/ibmpkcs11.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/ibmpkcs11impl.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/jaccess.jar'
*sys-package-mgr*: processing new jar, '/usr/java5/jre/lib/ext/jdmpview.jar'
Jython 2.5.1 (Release_2_5_1:6813, Sep 26 2009, 13:47:54) 
[IBM J9 VM (IBM Corporation)] on java1.5.0
Type "help", "copyright", "credits" or "license" for more information.
>>>

10，上传脚本
BAL_WAP.py -- 主程序
bal_wap.ini -- 通用配置
bal_wap_sql.ini -- sql配置

11，采用 create_table.sql 中的脚本在RB库中建立相应同步信息表

12，执行方式
scripts >jython/jython BAL_WAP.py

==============================================================================
同步表模板配置方法：
==============================================================================
1，现在rb库中建立相应的内存数据库对应表
2，配置bal_wap_sql.ini模板
    ##################################################
    [DEFAULT]
    ;指定更新的开始时间，可以带入模板的sql中,每次更新后程序也会更新这个参数
    ;如SELECT_SQL中使用的 %(UPDATE_DATE)s 即为获取本参数
    update_date=20000810000000
    ;执行需要执行的模板数，程序会根据模板数遍历
    template_num=1

    [SQL_TEMPLATE1]
    ;从MDB选择数据的sql，注意：date类型要转为char类型
    SELECT_SQL=select BAL_ID,ACCT_ID,ACCT_RES_ID,GROSS_BAL,RESERVE_BAL,CONSUME_BAL,TO_CHAR(EFF_DATE, 'yyyymmddhh24miss'),NVL(TO_CHAR(EXP_DATE, 'yyyymmddhh24miss'),'20500101000000'),TO_CHAR(UPDATE_DATE, 'yyyymmddhh24miss'),NVL(CEIL_LIMIT,0),NVL(BAL_CODE,0) from bal where UPDATE_DATE > to_date('%(UPDATE_DATE)s', 'yyyymmddhh24miss') and UPDATE_DATE <= to_date(?, 'yyyymmddhh24miss')
    ;插入Oracle数据的sql，注意：1，字段要与SELECT_SQL的字段一致。2，日期的字符串要转为date类型
    INSERT_SQL=INSERT INTO BAL_WAP (BAL_ID,ACCT_ID,ACCT_RES_ID,GROSS_BAL,RESERVE_BAL,CONSUME_BAL,EFF_DATE,EXP_DATE,UPDATE_DATE,CEIL_LIMIT,BAL_CODE) VALUES (?,?,?,?,?,?,TO_DATE(?, 'yyyymmddhh24miss'),TO_DATE(?, 'yyyymmddhh24miss'),TO_DATE(?, 'yyyymmddhh24miss'),?,?)
    ;数据类型定义，目前支持的数据类型：int,long,string,float
    ;注意：字段个数要与SELEXT_SQL中的对应，类型也要一一对应
    SELECT_FIELD_TYPE=1:int,2:int,3:int,4:long,5:long,6:long,7:string,8:string,9:string,10:int,11:long
    ;SELECT_SQL可以支持参数，见例子中的 ？
    ;此处设定参数的数据类型
    SELECT_PARAM_TYPE=1:string
    
    ;因为同步数据不做UPDATE操作，直接根据DELETE_KEY指定的字段进行删除，删除配置根据一下三个设定
    ;指定删除的语句，?代表参数
    DELETE_SQL=delete from bal_wap where bal_id = ?
    ;指定参数的数据类型
    DELETE_PARAM_TYPE=1:int
    ;指定删除时的关键字段，根据SELECT_SQL中对应字段获取值，多个参数用逗号分隔
    DELETE_KEY=1
    ###################################################
    
    
    