#!/usr/bin/perl -w

use strict;
use Net::FTP;
use File::Spec;
use File::Copy;
use Getopt::Std;
use vars;

our $VERSION=qw(0.0.1);
our @ftpList;
our($opt_s, $opt_f, $opt_c);

#�ַ�����ʽ:��������|����ģʽ|�����û�|��������|����IP|�����ļ�|�滻��Զ���ļ�
#��������:  U�ϴ�   D����
#����ģʽ:  I������ģʽ  A asciiģʽ
#'U|A|user|passwd|127.0.0.1|/cygdrive/z/OcsFileRateEngine.cpp|/ztesoft/ocs/zdl/OcsFileRateEngine.cpp'

#��ȡ��ǰʱ��
sub now_time{
    my ($_r_type) = @_;
    
    my ($__now_time);
    
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime;
    $year += 1900 if ( $year >= 100 );
    $mon++;
    
    if ( $_r_type == 1 || !defined $_r_type ){
        $__now_time = sprintf( "%4s-%02s-%02s %02s:%02s:%02s",
            $year, $mon, $mday, $hour, $min, $sec );
    }
    elsif( $_r_type == 2 ){
        $__now_time = sprintf( "%4s%02s%02s%02s%02s%02s", $year, $mon, $mday, $hour, $min, $sec );
    }
    elsif( $_r_type == 3 ){
        $__now_time = sprintf( "%02s%02s", $hour, $min );
    }
    else{
        die "δ֪�ķ���ʱ������!\$_r_type=$_r_type\n";
    }

    return $__now_time;
}

sub p_usage{
    my $u=<<"END";
    Usage:
       autoftp [-u] [-d] [-f IniFileName]
       -s string    ���մ��и�ʽ���д���
       -f filename  ����ִ�е�Ftp�ļ��б�
       -c pathname  updateʱ,У��Զ���Ƿ��ж�Ӧ·��,û������
                    downloadʱ,У�鱾���Ƿ��ж�Ӧ·��,û������
                    
       FtpString��ʽ(�ļ���Ҳ���������ʽ����):
            �ַ�����ʽ:��������|����ģʽ|�����û�|��������|����IP|�����ļ�|�滻��Զ���ļ�
            ��������:  U�ϴ�   D����
            ����ģʽ:  I������ģʽ  A asciiģʽ
            'U|A|ocs|ocs321|172.31.1.142|/cygdrive/z/OcsFileRateEngine.cpp|/ztesoft/ocs/zdl/OcsFileRateEngine.cpp'
            ��ǰ��� # Ϊע��

zdl0812\@163.com    Version ${VERSION}
END

    print $u;
    print "\n\n����س��˳�����!\n";
    <>;
    exit;
}

sub updateFile{
    my $transferMode   = $_[1];
    my $ftpUser        = $_[2];
    my $ftpPasswd      = $_[3];
    my $ftpIP          = $_[4];
    my $localFilepath  = $_[5];
    my $RomateFilePath = $_[6];
    my $needCreateDir  = $_[7];
    my $bakFileName    = $RomateFilePath . '_' . &now_time(2);
    
    my ($l_volume,$l_path,$l_filename) = File::Spec->splitpath( $localFilepath );
    my ($r_volume,$r_path,$r_filename) = File::Spec->splitpath( $RomateFilePath );
    
    chdir $l_path or die "cannot change local download directory:$l_path; $!\n";
    
    my $ftp = Net::FTP->new($ftpIP, Debug => 0, Port => 21, Timeout =>10)
            or die "cannot connect ftp server: $ftpIP; $@";
          
    $ftp->login($ftpUser, $ftpPasswd)
            or die 'Cannot login :', $ftp->message;
    
    if ($transferMode eq 'I'){
        print "���ô�������Ϊ������!\n";
        $ftp->binary or die "Set Trancfer Mode ERR:", $ftp->message;
    }else{
        print "���ô�������ΪASCII!\n";
        $ftp->ascii or die "Set Trancfer Mode ERR:", $ftp->message;
    }
    
    #�ж�Զ���Ƿ������Ҫ�ϴ���Ŀ¼
    #���������ǿ��У�鴴���򴴽�������·��
    if ($needCreateDir eq 'NEEDCREATEDIR'){
        $ftp->cwd($r_path) or $ftp->mkdir($r_path) or die "don't create dir:$r_path\n",$ftp->message;
    }
    
    $ftp->cwd($r_path)
            or die "Cannot change remote working directory:$r_path;", $ftp->message;
    printf "�ı�Զ�̷�����·����: [%s] \n", $ftp->pwd() or die "Get Curr Path err:", $ftp->message;;
            
    my @remoteFileList = $ftp->ls($r_path);
    
    #print "·���´����ļ�:\n";
    #print join "\n", @remoteFileList;
    #����ȡ�õ��ļ��б��ж��Ƿ��������ļ�
    foreach my $filname (@remoteFileList){
        my ($v, $p ,$f) = File::Spec->splitpath( $filname );
        #print "�����ļ�����Ϊ:$l_filename\n";
        #print "��Ҫ�Ƚϵ��ļ�����Ϊ:$f\n";
        if ($f eq $l_filename){
            print "[WARN]���������ļ�!��Ҫ��ԭ�ļ�����Ϊ:\n\t$bakFileName\n";
            $ftp->rename($RomateFilePath, $bakFileName)
                or die "Cannot rename remote file \n[$RomateFilePath] to [$bakFileName] ;\n\t:", $ftp->message;
        }
    }
    
    $ftp->put($localFilepath) or die "Update file failed:$localFilepath;", $ftp->message;
    
    my $l_fileSize = (stat($localFilepath))[7];
    my $r_fileSize = $ftp->size($RomateFilePath) or die "Get romate file size err:", $ftp->message;
    
    printf "�ϴ��ļ����: \n\t%s [%d] byte\n",$RomateFilePath , $r_fileSize;
    
    if ( $l_fileSize != $r_fileSize ){
        print "�ϴ��ļ���С�ͱ����ļ���һ��,��ʼ����!������ [ASCII] ��ʽ���д���!\n" if ($transferMode eq 'I');
        print "�ϴ��ļ���С�ͱ����ļ���һ��,��ʼ����!������ [������] ��ʽ���д���!\n" if ($transferMode eq 'A');
        
        my @remoteFileList = $ftp->ls($r_path) or die "FTP ls err;", $ftp->message;
        foreach my $f (@remoteFileList){
            if ($f eq $bakFileName){
                $ftp->rename($bakFileName, $RomateFilePath)
                    or die "Cannot change remote file name;", $ftp->message;
            }
            
            if ($f eq $RomateFilePath){
                $ftp->delete($RomateFilePath) or die "Delete FTP server's file $RomateFilePath err;", $ftp->message;
            }
        }
        print "�������!\n";
    }
    
    $ftp->close() or die "When close ftp link errs;", $ftp->message;
}

sub downloadFile{
    my $transferMode   = $_[1];
    my $ftpUser        = $_[2];
    my $ftpPasswd      = $_[3];
    my $ftpIP          = $_[4];
    my $localFilepath  = $_[5];
    my $RomateFilePath = $_[6];
    my $needCreateDir  = $_[7];
    my $bakFileName    = $localFilepath . '_' . &now_time(2);
    
    my ($l_volume,$l_path,$l_filename) = File::Spec->splitpath( $localFilepath );
    my ($r_volume,$r_path,$r_filename) = File::Spec->splitpath( $RomateFilePath );
    
    #�жϱ����Ƿ���������ļ���Ҫ��Ŀ¼
    #���������ǿ��У�鴴���򴴽�������·��
    if ($needCreateDir eq 'NEEDCREATEDIR'){
        mkdir $l_path if (! -e $l_path);
    }
    
    chdir $l_path or die "cannot change local download directory:$l_path; $!\n";
    
    my $ftp = Net::FTP->new($ftpIP, Debug => 0, Port => 21, Timeout =>10)
            or die "cannot connect ftp server: $ftpIP; $@";
          
    $ftp->login($ftpUser, $ftpPasswd)
            or die 'Cannot login :', $ftp->message;
    
    if ($transferMode eq 'I'){
        print "���ô�������Ϊ������!\n";
        $ftp->binary or die "Set Trancfer Mode ERR:", $ftp->message;
    }else{
        print "���ô�������ΪASCII!\n";
        $ftp->ascii or die "Set Trancfer Mode ERR:", $ftp->message;
    }
    
    $ftp->cwd($r_path)
            or die "Cannot change remote working directory:$r_path;", $ftp->message;
    printf "�ı�Զ�̷�����·����: [%s] \n", $ftp->pwd() or die "Get Curr Path err:", $ftp->message;;
    
    #�жϱ����Ƿ��������ļ�
    if (-e $localFilepath){
        print "[WARN]���ش��������ļ�,���ļ�������Ϊ:\n\t$bakFileName\n";
        rename($localFilepath, $bakFileName)
            or die "Cannot rename remote file \n[$localFilepath] to [$bakFileName] ;\n\t:$!";
    }
    
    $ftp->get($RomateFilePath) or die "Download file failed:$RomateFilePath;", $ftp->message;
    
    my $l_fileSize = (stat($localFilepath))[7];
    my $r_fileSize = $ftp->size($RomateFilePath) or die "Get romate file size err:", $ftp->message;
    
    printf "Զ���ļ���С: \n\t%s [%d] byte\n",$RomateFilePath , $r_fileSize;
    printf "�����ļ����: \n\t%s [%d] byte\n",$localFilepath , $l_fileSize;
    
    if ( $l_fileSize != $r_fileSize ){
        print "�����ļ���С�ͱ����ļ���һ��,��ʼ����!������ [ASCII] ��ʽ���д���!\n" if ($transferMode eq 'I');
        print "�����ļ���С�ͱ����ļ���һ��,��ʼ����!������ [������] ��ʽ���д���!\n" if ($transferMode eq 'A');
        
        unlink ($localFilepath) or die "Delete local file $localFilepath err;$!";
        
        if (-e $bakFileName){
            rename ($bakFileName, $localFilepath)
                or die "Cannot change remote file name;$!";
        }
        print "�������!\n";
    }
    
    $ftp->close() or die "When close ftp link errs;", $ftp->message;
}

sub analyzeFtpStr{
    my $fileStr = $_[0];
    printf "�����ַ���: [%s]\n",$_[0];
    my @__ftpStr = split /\|/, $fileStr;
    
    if ($#__ftpStr != 6){
        print "������ַ�����ʽ:$fileStr\n";
        return -1;
    }
    
    #print join "\n", @__ftpStr;
    return @__ftpStr;
}

sub readFtpListFile{
    my $filename = $_[0];
    my @__ftpList;
    open( FILEHD, $filename ) or die "��FTP�б��ļ�����$!";
    
    while (<FILEHD>) {
        chomp;
        next if (substr($_,0,1) eq '#');
        push @__ftpList, $_;
    }
    
    close(FILEHD) or die "�ر�FTP�б��ļ�����$!";
    
    return @__ftpList;
}

sub main{
    my $n_time = &now_time(1);
    print "##################$n_time#####################\n";
    print "����FTP�����ļ� ...\n";
    getopts('cs:f:');
    
    if (!defined $opt_f && !defined $opt_s){
        print "�����������!\n";
        &p_usage;
        exit -1;
    }
    
    #�������ָ���ļ������ô���
    if (defined $opt_f){
        print "��ȡ�����б��ļ�: $opt_f\n";
        #��ȡFTP�ļ��б�
        my @ftpList = &readFtpListFile($opt_f);
        foreach my $ftpStr (@ftpList){
            #����FTP��,��ʼ����
            my @ftpStruct = &analyzeFtpStr($ftpStr);
            
            #�ж��Ƿ���Ҫ���������ڵ�Ŀ¼
            print "defined opt_c!\n" if ($opt_c);
            push @ftpStruct,'NEEDCREATEDIR' if ($opt_c);
            
            if ($ftpStruct[0] eq 'U'){
                printf "��Ҫ�ϴ��ļ�: \n\t%s [%d] byte \n",$ftpStruct[5],(stat($ftpStruct[5]))[7];
                if (-e $ftpStruct[5]){
                    &updateFile(@ftpStruct);
                }else{
                    print "���ϴ��ļ�������!\n";
                    exit -1;
                }
            }elsif ($ftpStruct[0] eq 'D'){
                printf "��Ҫ�����ļ�: \n\t%s\n",$ftpStruct[6];
                &downloadFile(@ftpStruct);
            }else{
                print "δ֪�Ĳ�������:$ftpStruct[0]\n";
                exit -1;
            }
            $n_time = &now_time(1);
            print "---------------$n_time-----------------------\n";
        }
        
        $n_time = &now_time(1);
        print "##################$n_time#####################\n";
    }
    #�������봮�����ô���
    elsif (defined $opt_s){
        #����FTP��,��ʼ����
        my @ftpStruct = &analyzeFtpStr($opt_s);
        
        #�ж��Ƿ���Ҫ���������ڵ�Ŀ¼
        print "defined opt_c!\n" if ($opt_c);
        push @ftpStruct,'NEEDCREATEDIR' if ($opt_c);
        
        if ($ftpStruct[0] eq 'U'){
            printf "��Ҫ�ϴ��ļ�: \n\t%s [%d] byte \n",$ftpStruct[5],(stat($ftpStruct[5]))[7];
            if (-e $ftpStruct[5]){
                &updateFile(@ftpStruct);
            }else{
                print "���ϴ��ļ�������!\n";
                exit -1;
            }
        }elsif ($ftpStruct[0] eq 'D'){
            printf "��Ҫ�����ļ�: \n\t%s\n",$ftpStruct[6];
            &downloadFile(@ftpStruct);
        }else{
            print "δ֪�Ĳ�������:$ftpStruct[0]\n";
            exit -1;
        }
        $n_time = &now_time(1);
        print "##################$n_time#####################\n";
    }else{
        print "δ֪����:@ARGV\n";
        &p_usage;
        exit -1;
    }
}

main()