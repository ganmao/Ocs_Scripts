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

#字符串格式:传输类型|传输模式|主机用户|主机密码|主机IP|本地文件|替换的远程文件
#传输类型:  U上传   D下载
#传输模式:  I二进制模式  A ascii模式
#'U|A|user|passwd|127.0.0.1|/cygdrive/z/OcsFileRateEngine.cpp|/ztesoft/ocs/zdl/OcsFileRateEngine.cpp'

#获取当前时间
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
        die "未知的返回时间类型!\$_r_type=$_r_type\n";
    }

    return $__now_time;
}

sub p_usage{
    my $u=<<"END";
    Usage:
       autoftp [-u] [-d] [-f IniFileName]
       -s string    按照串中格式进行传输
       -f filename  批量执行的Ftp文件列表
       -c pathname  update时,校验远程是否有对应路径,没有则建立
                    download时,校验本地是否有对应路径,没有则建立
                    
       FtpString格式(文件中也按照这个格式设置):
            字符串格式:传输类型|传输模式|主机用户|主机密码|主机IP|本地文件|替换的远程文件
            传输类型:  U上传   D下载
            传输模式:  I二进制模式  A ascii模式
            'U|A|ocs|ocs321|172.31.1.142|/cygdrive/z/OcsFileRateEngine.cpp|/ztesoft/ocs/zdl/OcsFileRateEngine.cpp'
            行前添加 # 为注释

zdl0812\@163.com    Version ${VERSION}
END

    print $u;
    print "\n\n输入回车退出程序!\n";
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
        print "设置传输类型为二进制!\n";
        $ftp->binary or die "Set Trancfer Mode ERR:", $ftp->message;
    }else{
        print "设置传输类型为ASCII!\n";
        $ftp->ascii or die "Set Trancfer Mode ERR:", $ftp->message;
    }
    
    #判断远程是否存在需要上传的目录
    #如果定义了强制校验创建则创建不存在路径
    if ($needCreateDir eq 'NEEDCREATEDIR'){
        $ftp->cwd($r_path) or $ftp->mkdir($r_path) or die "don't create dir:$r_path\n",$ftp->message;
    }
    
    $ftp->cwd($r_path)
            or die "Cannot change remote working directory:$r_path;", $ftp->message;
    printf "改变远程服务器路径到: [%s] \n", $ftp->pwd() or die "Get Curr Path err:", $ftp->message;;
            
    my @remoteFileList = $ftp->ls($r_path);
    
    #print "路径下存在文件:\n";
    #print join "\n", @remoteFileList;
    #根据取得的文件列表判断是否有重名文件
    foreach my $filname (@remoteFileList){
        my ($v, $p ,$f) = File::Spec->splitpath( $filname );
        #print "本地文件名称为:$l_filename\n";
        #print "需要比较的文件名称为:$f\n";
        if ($f eq $l_filename){
            print "[WARN]存在重名文件!需要将原文件备份为:\n\t$bakFileName\n";
            $ftp->rename($RomateFilePath, $bakFileName)
                or die "Cannot rename remote file \n[$RomateFilePath] to [$bakFileName] ;\n\t:", $ftp->message;
        }
    }
    
    $ftp->put($localFilepath) or die "Update file failed:$localFilepath;", $ftp->message;
    
    my $l_fileSize = (stat($localFilepath))[7];
    my $r_fileSize = $ftp->size($RomateFilePath) or die "Get romate file size err:", $ftp->message;
    
    printf "上传文件完成: \n\t%s [%d] byte\n",$RomateFilePath , $r_fileSize;
    
    if ( $l_fileSize != $r_fileSize ){
        print "上传文件大小和本地文件不一致,开始回退!请试用 [ASCII] 方式进行传输!\n" if ($transferMode eq 'I');
        print "上传文件大小和本地文件不一致,开始回退!请试用 [二进制] 方式进行传输!\n" if ($transferMode eq 'A');
        
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
        print "回退完成!\n";
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
    
    #判断本地是否存在下载文件需要的目录
    #如果定义了强制校验创建则创建不存在路径
    if ($needCreateDir eq 'NEEDCREATEDIR'){
        mkdir $l_path if (! -e $l_path);
    }
    
    chdir $l_path or die "cannot change local download directory:$l_path; $!\n";
    
    my $ftp = Net::FTP->new($ftpIP, Debug => 0, Port => 21, Timeout =>10)
            or die "cannot connect ftp server: $ftpIP; $@";
          
    $ftp->login($ftpUser, $ftpPasswd)
            or die 'Cannot login :', $ftp->message;
    
    if ($transferMode eq 'I'){
        print "设置传输类型为二进制!\n";
        $ftp->binary or die "Set Trancfer Mode ERR:", $ftp->message;
    }else{
        print "设置传输类型为ASCII!\n";
        $ftp->ascii or die "Set Trancfer Mode ERR:", $ftp->message;
    }
    
    $ftp->cwd($r_path)
            or die "Cannot change remote working directory:$r_path;", $ftp->message;
    printf "改变远程服务器路径到: [%s] \n", $ftp->pwd() or die "Get Curr Path err:", $ftp->message;;
    
    #判断本地是否有重名文件
    if (-e $localFilepath){
        print "[WARN]本地存在重名文件,将文件重命名为:\n\t$bakFileName\n";
        rename($localFilepath, $bakFileName)
            or die "Cannot rename remote file \n[$localFilepath] to [$bakFileName] ;\n\t:$!";
    }
    
    $ftp->get($RomateFilePath) or die "Download file failed:$RomateFilePath;", $ftp->message;
    
    my $l_fileSize = (stat($localFilepath))[7];
    my $r_fileSize = $ftp->size($RomateFilePath) or die "Get romate file size err:", $ftp->message;
    
    printf "远程文件大小: \n\t%s [%d] byte\n",$RomateFilePath , $r_fileSize;
    printf "下载文件完成: \n\t%s [%d] byte\n",$localFilepath , $l_fileSize;
    
    if ( $l_fileSize != $r_fileSize ){
        print "下载文件大小和本地文件不一致,开始回退!请试用 [ASCII] 方式进行传输!\n" if ($transferMode eq 'I');
        print "下载文件大小和本地文件不一致,开始回退!请试用 [二进制] 方式进行传输!\n" if ($transferMode eq 'A');
        
        unlink ($localFilepath) or die "Delete local file $localFilepath err;$!";
        
        if (-e $bakFileName){
            rename ($bakFileName, $localFilepath)
                or die "Cannot change remote file name;$!";
        }
        print "回退完成!\n";
    }
    
    $ftp->close() or die "When close ftp link errs;", $ftp->message;
}

sub analyzeFtpStr{
    my $fileStr = $_[0];
    printf "传入字符串: [%s]\n",$_[0];
    my @__ftpStr = split /\|/, $fileStr;
    
    if ($#__ftpStr != 6){
        print "错误的字符串格式:$fileStr\n";
        return -1;
    }
    
    #print join "\n", @__ftpStr;
    return @__ftpStr;
}

sub readFtpListFile{
    my $filename = $_[0];
    my @__ftpList;
    open( FILEHD, $filename ) or die "打开FTP列表文件错误：$!";
    
    while (<FILEHD>) {
        chomp;
        next if (substr($_,0,1) eq '#');
        push @__ftpList, $_;
    }
    
    close(FILEHD) or die "关闭FTP列表文件错误：$!";
    
    return @__ftpList;
}

sub main{
    my $n_time = &now_time(1);
    print "##################$n_time#####################\n";
    print "启动FTP更新文件 ...\n";
    getopts('cs:f:');
    
    if (!defined $opt_f && !defined $opt_s){
        print "参数输入错误!\n";
        &p_usage;
        exit -1;
    }
    
    #如果按照指定文件中配置传输
    if (defined $opt_f){
        print "读取更新列表文件: $opt_f\n";
        #读取FTP文件列表
        my @ftpList = &readFtpListFile($opt_f);
        foreach my $ftpStr (@ftpList){
            #解析FTP串,开始传输
            my @ftpStruct = &analyzeFtpStr($ftpStr);
            
            #判断是否需要建立不存在的目录
            print "defined opt_c!\n" if ($opt_c);
            push @ftpStruct,'NEEDCREATEDIR' if ($opt_c);
            
            if ($ftpStruct[0] eq 'U'){
                printf "需要上传文件: \n\t%s [%d] byte \n",$ftpStruct[5],(stat($ftpStruct[5]))[7];
                if (-e $ftpStruct[5]){
                    &updateFile(@ftpStruct);
                }else{
                    print "需上传文件不存在!\n";
                    exit -1;
                }
            }elsif ($ftpStruct[0] eq 'D'){
                printf "需要下载文件: \n\t%s\n",$ftpStruct[6];
                &downloadFile(@ftpStruct);
            }else{
                print "未知的操作类型:$ftpStruct[0]\n";
                exit -1;
            }
            $n_time = &now_time(1);
            print "---------------$n_time-----------------------\n";
        }
        
        $n_time = &now_time(1);
        print "##################$n_time#####################\n";
    }
    #按照输入串中配置传输
    elsif (defined $opt_s){
        #解析FTP串,开始传输
        my @ftpStruct = &analyzeFtpStr($opt_s);
        
        #判断是否需要建立不存在的目录
        print "defined opt_c!\n" if ($opt_c);
        push @ftpStruct,'NEEDCREATEDIR' if ($opt_c);
        
        if ($ftpStruct[0] eq 'U'){
            printf "需要上传文件: \n\t%s [%d] byte \n",$ftpStruct[5],(stat($ftpStruct[5]))[7];
            if (-e $ftpStruct[5]){
                &updateFile(@ftpStruct);
            }else{
                print "需上传文件不存在!\n";
                exit -1;
            }
        }elsif ($ftpStruct[0] eq 'D'){
            printf "需要下载文件: \n\t%s\n",$ftpStruct[6];
            &downloadFile(@ftpStruct);
        }else{
            print "未知的操作类型:$ftpStruct[0]\n";
            exit -1;
        }
        $n_time = &now_time(1);
        print "##################$n_time#####################\n";
    }else{
        print "未知参数:@ARGV\n";
        &p_usage;
        exit -1;
    }
}

main()