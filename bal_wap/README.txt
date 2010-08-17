jython安装方法：
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