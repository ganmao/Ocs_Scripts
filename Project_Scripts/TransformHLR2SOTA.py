#!/usr/bin/env python
# coding=utf-8

from ftplib import FTP;
from os.path import exists, isdir
from os import rename, chdir, mkdir, sep
from time import localtime, strftime
from re import match
import logging
import socket
from sys import argv
'''
使用帮助:
    #开始一次从FTP采集的活动
    TransformHLR2SOTA.pyc --DownLoadFile
    
    #开始一次转换HLR文件，并且发送给SOTA的活动，需要文件名，
    #路径默认为采集路径，一次处理一个文件
    TransformHLR2SOTA.pyc --TransformFile=<FILENAME>
    
    #开始一次从FTP采集，并且将采集文件进行格式转换，且发送给SOTA的过程（即，以上两个过程的联合）
    TransformHLR2SOTA.pyc --HLR2SOTA


修改说明：
====================================================
2010-05-13  添加了采集后删除远程ftp文件的功能

'''
#=================================================
#基本配置说明：需要2.6版本的Python，不要使用3.x的版本

#程序日志存放路径
Log_FileName='z:\\alog.txt'

#Ftp服务器的IP，端口(默认21)，用户名，密码，超时等待时间(默认60秒)
FTP_Host = '10.45.4.129'
FTP_Port = 21
FTP_User = 'cc611'
FTP_Passwd = 'cc611'
FTP_TimeOut = 60

#Ftp服务器远端路径
FTP_RemotePath = '/ocs/cc611/scripts/SFone'

#下载文件本地存放路径
Local_DownLoadPath = 'z:\\'

#Ftp服务器文件名匹配模式（正则表达式）
FTP_FileRegex='^hlr_status(0|1|233)_(.+?).txt$'

#调试日志级别
#DEBUG, INFO, WARNING, ERROR, CRITICAL
Debug_level='INFO'

#文件传输方式：1-ASCII，2-Binary
FTP_TransferMode = 1

#Ftp服务器的链接模式：1-主动，0-被动（默认）
FTP_ConnMode = 0

#=================================================
#如果python版本小于2.6设定超时的方法
#import socket
socket.setdefaulttimeout(FTP_TimeOut)

#下载文件本地备份路径
Local_BackPath = Local_DownLoadPath + sep +'bak'

#正确记录输出文件路径
Local_FinalRecordPath = Local_DownLoadPath + sep + 'out'

#错误记录输出文件路径
Local_BadRecordPath = Local_DownLoadPath + sep + 'bad'

FTP_FileList = []

def Usage():
    print '''
使用帮助:
        #开始一次从FTP采集的活动
        TransformHLR2SOTA.pyc --DownLoadFile
        
        #开始一次转换HLR文件，并且发送给SOTA的活动，需要文件名，
        #路径默认为采集路径，一次处理一个文件
        TransformHLR2SOTA.pyc --TransformFile=<FILENAME>
        
        #开始一次从FTP采集，并且将采集文件进行格式转换，且发送给SOTA的过程（即，以上两个过程的联合）
        TransformHLR2SOTA.pyc --HLR2SOTA
    '''

def GetSystemTime():
    TIMEFORMAT = '%Y%m%d%H%M%S'
    return strftime( TIMEFORMAT, localtime() )
    
def InitLog():
    if Debug_level == 'DEBUG':
        logLevel = logging.DEBUG
    elif Debug_level == 'INFO':
        logLevel = logging.INFO
    elif Debug_level == 'WARNING':
        logLevel = logging.WARNING
    elif Debug_level == 'ERROR':
        logLevel = logging.ERROR
    elif Debug_level == 'CRITICAL':
        logLevel = logging.CRITICAL
    else:
        print '错误的日志级别：[%s]' % logLevel
        exit()
    
    logger = logging.getLogger("Transform_Log")
    logger.setLevel(logLevel)
    
    fhdlr = logging.FileHandler(Log_FileName)
    fhdlr.setLevel(logLevel)
    
    chdlr = logging.StreamHandler()
    chdlr.setLevel(logLevel)
    
    if Debug_level == 'DEBUG':
        formatter = logging.Formatter('%(asctime)s[%(levelname)s]%(funcName)s:%(lineno)s:%(message)s')
    if Debug_level == 'INFO':
        formatter = logging.Formatter('%(asctime)s[%(levelname)s]%(funcName)s:%(message)s')
    else:
        formatter = logging.Formatter('%(asctime)s[%(levelname)s]%(message)s')
        
    fhdlr.setFormatter(formatter)
    chdlr.setFormatter(formatter)
    
    logger.addHandler(fhdlr)
    logger.addHandler(chdlr)
    
    logger.info('日志初始化完成!')
    return logger
    
def Init():
    if len(argv) != 2:
        Usage()
        exit()
    
    global myLogger
    myLogger = InitLog()
    myLogger.info('开始进行程序初始化！')
    
    global TIMESTRING
    TIMESTRING = GetSystemTime()
    myLogger.info('获取处理时间成功：[%s]' % TIMESTRING)
    
    chdir(Local_DownLoadPath)
    myLogger.info('进入下载存放目录：[%s]' % Local_DownLoadPath)
    
    if ( not exists( Local_BackPath ) or not isdir( Local_BackPath ) ):
        mkdir(Local_BackPath)
        myLogger.info('创建目录： %s' % Local_BackPath)
    
    if ( not exists( Local_FinalRecordPath ) or not isdir( Local_FinalRecordPath ) ):
        mkdir(Local_FinalRecordPath)
        myLogger.info('创建目录： %s' % Local_FinalRecordPath)
    
    if ( not exists( Local_BadRecordPath ) or not isdir( Local_BadRecordPath ) ):
        mkdir(Local_BadRecordPath)
        myLogger.info('创建目录： %s' % Local_BadRecordPath)
        
    myLogger.info('初始化处理完成！')

    
#判断是否存在本地文件，如果存在则需进行备份
def JudgeExistLocalFile(myFile):
    if exists(myFile):
        bakFileName = myFile + '.' + TIMESTRING
        myLogger.info('本地存在重名文件，将其改名为：%s' % bakFileName)
        
        rename (myFile, bakFileName)
        
    return 0
    
def DownLoadFile(myFile):
    if FTP_TransferMode == 0:       #二进制方式传输
        myLogger.info('采用二进制方式采集HLR文件：%s' % myFile)
        fh = open(myFile, 'wb')
        myFtp.retrbinary('RETR ' + r_fileName, fh.write)
        fh.close()
    elif FTP_TransferMode == 1:     #ASCII方式传输
        myLogger.info('采用ASCII方式采集HLR文件：%s' % myFile)
        fh = open(myFile, 'w')
        myFtp.retrlines('RETR ' + myFile, lambda s, w=fh.write: w(s+"\n"))
        fh.close()
    else:
        myLogger.error('未知的传输方式：FTP_TransferMode=%s' % FTP_TransferMode)
        myLogger.error('程序异常退出')
        exit()
        
    try:
        myFtp.delete(myFile)
    except error_perm, e:
        myLogger.error('删除远程服务器上文件错误：%s:%s' % (myFile, e))
    else:
        myLogger.info('成功删除远程服务器文件：%s' % myFile)
    

def SplitField(inStr):
    myStrList = inStr.split(r',')
    myStrList[2] = int(myStrList[2], 16)
    myStrList[3] = myStrList[3].replace('"', '')
    
    if myStrList[3] not in ('0', '1', '233'):
        #myLogger.warning("错误的数据：%s" % inStr)
        return [-1, ]
    else:
        myLogger.debug("转化后列表：%s" % myStrList)
        return myStrList

def FormatOutField(inOutList):
    inOutList[0] = int(inOutList[0])
    inOutList[1] = int(inOutList[1])
    inOutList[2] = int(inOutList[2])
    if inOutList[3] == '1':
        inOutList[3] = 2
        return inOutList
    elif inOutList[3] == '233':
        inOutList[3] = 1
        return inOutList
    elif inOutList[3] == '0':
        inOutList[3] = 3
        return inOutList
    else:
        myLogger.warning("错误的数据：%s" % inOutList)
        return (-1, )

def JoinOutField(inFmtList):
    outFmtList = []
    
    outTime = GetSystemTime()
    
    outFmtList.append('         SMIN = 0x%X' % inFmtList[0])
    outFmtList.append('          MDN = 0x%X' % inFmtList[1])
    outFmtList.append('          MSN = 0x%X' % inFmtList[2])
    outFmtList.append('  UPDATE_FLAG = <null>')
    outFmtList.append('   CreateTime = %s-%s-%s %s:%s:%s' % (outTime[0:4],outTime[4:6],outTime[6:8],outTime[8:10],outTime[10:12],outTime[12:]) )
    outFmtList.append('    SUBS_TYPE = 0x%X' % inFmtList[3])
    outFmtList.append(' PAYMENT_TYPE = <null>')
    outFmtList.append('    RESERVED1 = <null>')
    outFmtList.append('    RESERVED2 = <null>')
    outFmtList.append('    RESERVED3 = <null>')
    outFmtList.append('')
    
    myLogger.debug('需输出内容为： %s' % outFmtList)
    return outFmtList

#文件解析函数
def TransformFormat():
    myOutFieldList = []
    myFmtFieldList = []
    
    global FTP_FileList
    for myFile in FTP_FileList:
        with open(myFile, 'rU') as fh:
            for eachLine in fh:
                eachLine = eachLine.strip()
                eachLine = eachLine.replace('\n', '')
                if match('^Query', eachLine): continue
                if match('^BeginTime: ', eachLine): continue
                if match('^EndTime: ', eachLine): continue
                if match('^TotalNum: ', eachLine): continue
                
                myLogger.debug('开始处理行信息：%s' % eachLine)
                
                myFieldList = SplitField(eachLine)
                
                if myFieldList[0] != -1:
                    myOutFieldList = FormatOutField(myFieldList)
                    myFmtFieldList.append( JoinOutField(myOutFieldList) )
                else:
                    WriteBadRecord(myFile, eachLine)
                    
        BackOrgFile(myFile)
        
        WriteFmtOutField(myFile, myFmtFieldList)
        
    myLogger.debug('myFmtFieldList= %s' % myFmtFieldList)
    return myFmtFieldList


def GetHLRFile():
    myLogger.info('开始运行FTP下载进程!')
    
    global myFtp
    myFtp = FTP()
    
    #FTP调试记录等级:0~2
    if Debug_level == 'DEBUG':
        myFtp.set_debuglevel(1)
    else:
        myFtp.set_debuglevel(0)
    
    if FTP_ConnMode == 1:
        myLogger.warning('设置FTP为主动模式！')
        myFtp.set_pasv(False)
    
    #如果python版本小于2.6
    myFtp.connect(FTP_Host, FTP_Port)
    #myFtp.connect(FTP_Host, FTP_Port, FTP_TimeOut)
    myFtp.login(FTP_User, FTP_Passwd)
    myLogger.info('已经登录到主机：%s，用户名：%s' % (FTP_Host, FTP_User) )
    
    myFtp.cwd(FTP_RemotePath)
    myLogger.info('已经切换到远程路径：%s' % FTP_RemotePath)
    
    myFileList = myFtp.nlst()
    myLogger.info('获取远程主机文件列表：%s' % FTP_FileList)
    
    for myFile in myFileList:
        myLogger.debug('匹配正则表达式：%s' % FTP_FileRegex)
        if match(FTP_FileRegex, myFile):
            myLogger.debug('需要处理文件：%s' % myFile)
            JudgeExistLocalFile(myFile)
            DownLoadFile(myFile)
            FTP_FileList.append(myFile)
        else:
            myLogger.debug('跳过文件：%s' % myFile)
            pass
    
    myFtp.close
    myFtp.quit
    return FTP_FileList
    
def WriteBadRecord(inFileName, inStr):
    #错误记录备份文件名
    global TIMESTRING
    myBadRecordFileName = Local_BadRecordPath + sep + inFileName + '.' + TIMESTRING + '.bad'
    
    with open(myBadRecordFileName, 'a') as hf:
        hf.write(inStr)
        hf.write('\n')
        
    return 0
    
def WriteFmtOutField(inFileName, inList):
    global TIMESTRING
    myBackOrgFileName = Local_FinalRecordPath + sep + inFileName + '.' + TIMESTRING + '.out'
    
    with open(myBackOrgFileName, 'w') as hf:
        for myBlockList in inList:
            for eachList in myBlockList:
                hf.write(eachList + '\n')
    
    return 0
        
def BackOrgFile(inFilename):
    global TIMESTRING
    myBackOrgFileName = Local_BackPath + sep + inFilename + '.' + TIMESTRING + '.bak'
    inFilename = Local_DownLoadPath + sep + inFilename
    
    rename(inFilename, myBackOrgFileName)
    return 0
    
def main():
    Init()
    
    try:
        if argv[1] == '--DownLoadFile':
            myLogger.info('开始从HLR进行FTP采集！')
            
            try:
                myFile = GetHLRFile()
                #myLogger.info('获取到文件：\n%s' % '\n'.join(myFile))
            except (socket.error, socket.gaierror):
                myLogger.error('FTP DownLoadFile ERROR ![%s][%s]' % (socket.error, socket.gaierror))
                myLogger.error('程序异常退出')
                exit()
        elif argv[1] == '--HLR2SOTA':
            myLogger.info('开始从HLR进行FTP采集,并且转化为SOTA要求的格式')
            
            try:
                myFile = GetHLRFile()
            except (socket.error, socket.gaierror):
                myLogger.error('FTP DownLoadFile ERROR ![%s][%s]' % (socket.error, socket.gaierror))
                myLogger.error('程序异常退出')
                exit()
                
            TransformFormat()
        else:
            if argv[1][:16] == '--TransformFile=':
                myLogger.info('将文件转化为SOTA要求的格式! %s' % argv[1][16:])
                
                global FTP_FileList
                FTP_FileList.append(argv[1][16:])
                TransformFormat()
            else:
                print "参数数据错误，请详细看一下帮助！"
                Usage()
    except Exception, e:
        myLogger.error('程序异常退出: %s' % e)
        exit()
    
if (__name__ == '__main__'):
    main()