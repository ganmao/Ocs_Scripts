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
ʹ�ð���:
    #��ʼһ�δ�FTP�ɼ��Ļ
    TransformHLR2SOTA.pyc --DownLoadFile
    
    #��ʼһ��ת��HLR�ļ������ҷ��͸�SOTA�Ļ����Ҫ�ļ�����
    #·��Ĭ��Ϊ�ɼ�·����һ�δ���һ���ļ�
    TransformHLR2SOTA.pyc --TransformFile=<FILENAME>
    
    #��ʼһ�δ�FTP�ɼ������ҽ��ɼ��ļ����и�ʽת�����ҷ��͸�SOTA�Ĺ��̣����������������̵����ϣ�
    TransformHLR2SOTA.pyc --HLR2SOTA


�޸�˵����
====================================================
2010-05-13  ����˲ɼ���ɾ��Զ��ftp�ļ��Ĺ���

'''
#=================================================
#��������˵������Ҫ2.6�汾��Python����Ҫʹ��3.x�İ汾

#������־���·��
Log_FileName='z:\\alog.txt'

#Ftp��������IP���˿�(Ĭ��21)���û��������룬��ʱ�ȴ�ʱ��(Ĭ��60��)
FTP_Host = '10.45.4.129'
FTP_Port = 21
FTP_User = 'cc611'
FTP_Passwd = 'cc611'
FTP_TimeOut = 60

#Ftp������Զ��·��
FTP_RemotePath = '/ocs/cc611/scripts/SFone'

#�����ļ����ش��·��
Local_DownLoadPath = 'z:\\'

#Ftp�������ļ���ƥ��ģʽ��������ʽ��
FTP_FileRegex='^hlr_status(0|1|233)_(.+?).txt$'

#������־����
#DEBUG, INFO, WARNING, ERROR, CRITICAL
Debug_level='INFO'

#�ļ����䷽ʽ��1-ASCII��2-Binary
FTP_TransferMode = 1

#Ftp������������ģʽ��1-������0-������Ĭ�ϣ�
FTP_ConnMode = 0

#=================================================
#���python�汾С��2.6�趨��ʱ�ķ���
#import socket
socket.setdefaulttimeout(FTP_TimeOut)

#�����ļ����ر���·��
Local_BackPath = Local_DownLoadPath + sep +'bak'

#��ȷ��¼����ļ�·��
Local_FinalRecordPath = Local_DownLoadPath + sep + 'out'

#�����¼����ļ�·��
Local_BadRecordPath = Local_DownLoadPath + sep + 'bad'

FTP_FileList = []

def Usage():
    print '''
ʹ�ð���:
        #��ʼһ�δ�FTP�ɼ��Ļ
        TransformHLR2SOTA.pyc --DownLoadFile
        
        #��ʼһ��ת��HLR�ļ������ҷ��͸�SOTA�Ļ����Ҫ�ļ�����
        #·��Ĭ��Ϊ�ɼ�·����һ�δ���һ���ļ�
        TransformHLR2SOTA.pyc --TransformFile=<FILENAME>
        
        #��ʼһ�δ�FTP�ɼ������ҽ��ɼ��ļ����и�ʽת�����ҷ��͸�SOTA�Ĺ��̣����������������̵����ϣ�
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
        print '�������־����[%s]' % logLevel
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
    
    logger.info('��־��ʼ�����!')
    return logger
    
def Init():
    if len(argv) != 2:
        Usage()
        exit()
    
    global myLogger
    myLogger = InitLog()
    myLogger.info('��ʼ���г����ʼ����')
    
    global TIMESTRING
    TIMESTRING = GetSystemTime()
    myLogger.info('��ȡ����ʱ��ɹ���[%s]' % TIMESTRING)
    
    chdir(Local_DownLoadPath)
    myLogger.info('�������ش��Ŀ¼��[%s]' % Local_DownLoadPath)
    
    if ( not exists( Local_BackPath ) or not isdir( Local_BackPath ) ):
        mkdir(Local_BackPath)
        myLogger.info('����Ŀ¼�� %s' % Local_BackPath)
    
    if ( not exists( Local_FinalRecordPath ) or not isdir( Local_FinalRecordPath ) ):
        mkdir(Local_FinalRecordPath)
        myLogger.info('����Ŀ¼�� %s' % Local_FinalRecordPath)
    
    if ( not exists( Local_BadRecordPath ) or not isdir( Local_BadRecordPath ) ):
        mkdir(Local_BadRecordPath)
        myLogger.info('����Ŀ¼�� %s' % Local_BadRecordPath)
        
    myLogger.info('��ʼ��������ɣ�')

    
#�ж��Ƿ���ڱ����ļ����������������б���
def JudgeExistLocalFile(myFile):
    if exists(myFile):
        bakFileName = myFile + '.' + TIMESTRING
        myLogger.info('���ش��������ļ����������Ϊ��%s' % bakFileName)
        
        rename (myFile, bakFileName)
        
    return 0
    
def DownLoadFile(myFile):
    if FTP_TransferMode == 0:       #�����Ʒ�ʽ����
        myLogger.info('���ö����Ʒ�ʽ�ɼ�HLR�ļ���%s' % myFile)
        fh = open(myFile, 'wb')
        myFtp.retrbinary('RETR ' + r_fileName, fh.write)
        fh.close()
    elif FTP_TransferMode == 1:     #ASCII��ʽ����
        myLogger.info('����ASCII��ʽ�ɼ�HLR�ļ���%s' % myFile)
        fh = open(myFile, 'w')
        myFtp.retrlines('RETR ' + myFile, lambda s, w=fh.write: w(s+"\n"))
        fh.close()
    else:
        myLogger.error('δ֪�Ĵ��䷽ʽ��FTP_TransferMode=%s' % FTP_TransferMode)
        myLogger.error('�����쳣�˳�')
        exit()
        
    try:
        myFtp.delete(myFile)
    except error_perm, e:
        myLogger.error('ɾ��Զ�̷��������ļ�����%s:%s' % (myFile, e))
    else:
        myLogger.info('�ɹ�ɾ��Զ�̷������ļ���%s' % myFile)
    

def SplitField(inStr):
    myStrList = inStr.split(r',')
    myStrList[2] = int(myStrList[2], 16)
    myStrList[3] = myStrList[3].replace('"', '')
    
    if myStrList[3] not in ('0', '1', '233'):
        #myLogger.warning("��������ݣ�%s" % inStr)
        return [-1, ]
    else:
        myLogger.debug("ת�����б�%s" % myStrList)
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
        myLogger.warning("��������ݣ�%s" % inOutList)
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
    
    myLogger.debug('���������Ϊ�� %s' % outFmtList)
    return outFmtList

#�ļ���������
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
                
                myLogger.debug('��ʼ��������Ϣ��%s' % eachLine)
                
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
    myLogger.info('��ʼ����FTP���ؽ���!')
    
    global myFtp
    myFtp = FTP()
    
    #FTP���Լ�¼�ȼ�:0~2
    if Debug_level == 'DEBUG':
        myFtp.set_debuglevel(1)
    else:
        myFtp.set_debuglevel(0)
    
    if FTP_ConnMode == 1:
        myLogger.warning('����FTPΪ����ģʽ��')
        myFtp.set_pasv(False)
    
    #���python�汾С��2.6
    myFtp.connect(FTP_Host, FTP_Port)
    #myFtp.connect(FTP_Host, FTP_Port, FTP_TimeOut)
    myFtp.login(FTP_User, FTP_Passwd)
    myLogger.info('�Ѿ���¼��������%s���û�����%s' % (FTP_Host, FTP_User) )
    
    myFtp.cwd(FTP_RemotePath)
    myLogger.info('�Ѿ��л���Զ��·����%s' % FTP_RemotePath)
    
    myFileList = myFtp.nlst()
    myLogger.info('��ȡԶ�������ļ��б�%s' % FTP_FileList)
    
    for myFile in myFileList:
        myLogger.debug('ƥ��������ʽ��%s' % FTP_FileRegex)
        if match(FTP_FileRegex, myFile):
            myLogger.debug('��Ҫ�����ļ���%s' % myFile)
            JudgeExistLocalFile(myFile)
            DownLoadFile(myFile)
            FTP_FileList.append(myFile)
        else:
            myLogger.debug('�����ļ���%s' % myFile)
            pass
    
    myFtp.close
    myFtp.quit
    return FTP_FileList
    
def WriteBadRecord(inFileName, inStr):
    #�����¼�����ļ���
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
            myLogger.info('��ʼ��HLR����FTP�ɼ���')
            
            try:
                myFile = GetHLRFile()
                #myLogger.info('��ȡ���ļ���\n%s' % '\n'.join(myFile))
            except (socket.error, socket.gaierror):
                myLogger.error('FTP DownLoadFile ERROR ![%s][%s]' % (socket.error, socket.gaierror))
                myLogger.error('�����쳣�˳�')
                exit()
        elif argv[1] == '--HLR2SOTA':
            myLogger.info('��ʼ��HLR����FTP�ɼ�,����ת��ΪSOTAҪ��ĸ�ʽ')
            
            try:
                myFile = GetHLRFile()
            except (socket.error, socket.gaierror):
                myLogger.error('FTP DownLoadFile ERROR ![%s][%s]' % (socket.error, socket.gaierror))
                myLogger.error('�����쳣�˳�')
                exit()
                
            TransformFormat()
        else:
            if argv[1][:16] == '--TransformFile=':
                myLogger.info('���ļ�ת��ΪSOTAҪ��ĸ�ʽ! %s' % argv[1][16:])
                
                global FTP_FileList
                FTP_FileList.append(argv[1][16:])
                TransformFormat()
            else:
                print "�������ݴ�������ϸ��һ�°�����"
                Usage()
    except Exception, e:
        myLogger.error('�����쳣�˳�: %s' % e)
        exit()
    
if (__name__ == '__main__'):
    main()