#!/usr/bin/perl -w

use DBI;
use File::Spec;

#数据库连接配置
#=====================================================
my $vDBName     = "cc";
my $vDBUserName = "cc";
my $vDBPasswd   = "smart123";
my $vDBHead     = "";
my $vSTH        = "";
my %vSubs       = ();
my @vOutCdr     = ();

#获取数据库中用户信息SQL
my $vUserSqlStr='SELECT S.PREFIX || S.ACC_NBR, P.PROD_STATE FROM SUBS S, PROD P WHERE S.SUBS_ID = P.PROD_ID';

#短信网关文件处理路径配置
#=====================================================
#短信网关补款话单路径
my $vSmbSrcPath="/ztesoft/ocs/data/pp/smb/src/download_smb/";
#短信网关备份话单路径
my $vSmbBakPath="/ztesoft/ocs/data/pp/smb/src/bak/";
#短信网关话单处理临时路径,处理的临时文件都会放在这个目录
my $vSmbWorkPath="/ztesoft/ocs/data/pp/smb/src/download_smb/tmp/";
#短信网关处理后话单输出路径
my $vSmbOutputPath="/ztesoft/ocs/data/pp/smb/src/";

#停顿时间间隔,单位为秒
my $vSleepTime=10;

#建立的临时文件,其中包含处理的文件名称,处理到第多少条的信息,
#程序运行之前先检查是否有这个文件,如果有则接着处理
my $vTmpInfoFile="${vSmbWorkPath}/FileterSmbCdr_TmpInfoFile.txt";
my $vTmpCdrFile="${vSmbWorkPath}/FileterSmbCdr_TmpCdr.txt";

#=====================================================
my $vHeadNetType      = "G";
my $vHeadFileVersion  = "00";
my $vHeadFileTime     = &vGetLocalTime;
my $vHeadFileCountOrg = 0;
my $vHeadFileCountNew = 0;

#=====================================================


#定义子程序
#=====================================================
#获取当时系统时间
sub vGetLocalTime{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $yday = $yday + 1900;
    return "$year$mon$yday$hour$min$sec";
}

#=====================================================
#获取数据库中订购信息
sub vGetSubsInfo{
    $vDBHead = DBI->connect( "dbi:Oracle:$vDBName", $vDBUserName, $vDBPasswd )
      or die "Can't connect to Oracle database: $DBI::errstr\n";

    #连接数据库
    my $vSTH = $vDBHead->prepare($vUserSqlStr)
      or die "Can't prepare SQL statement: $DBI::errstr\n";

    $vSTH->execute or die "Can't execute SQL statement: $DBI::errstr\n";

    #读取记录数据
    while ( my @vRecs = $vSTH->fetchrow_array ) {
        #print "@vRecs\n";
        #当已经存在相同的号码时
        if (exists $vSubs{$vRecs[0]}){
            $vSubs{$vRecs[0]} = $vRecs[1] if ( $vSubs{$vRecs[0]} ne 'A' );
        #不存在相同号码时
        }else{
            $vSubs{$vRecs[0]} = $vRecs[1];
        }
    }
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;

    #断开连接
    $vDBHead->disconnect or warn "Disconnection failed: $DBI::errstr\n";
}

#=====================================================
#获取扫描目录下文件列表的数组
sub vGetFileList{
    my ($gvSmbSrcPath) = @_;
    my @vFileList=();

    opendir DIRHEAD,$gvSmbSrcPath or die "Cannot open $gvSmbSrcPath: $!";

    foreach my $vFile (readdir DIRHEAD){
        my $v_tfilename = File::Spec->catpath('', $gvSmbSrcPath, $vFile );
        push @vFileList, $v_tfilename if ( -f $v_tfilename );
    }

    closedir DIRHEAD;

    return @vFileList;
}

#=====================================================
#判断话单中号码是否OCS号码
sub vJudgeIsOcsNumber{
    my ($vCdrNumber) = @_;

    while ( substr($vCdrNumber, 0, 1) eq '0' ){
        $vCdrNumber = substr($vCdrNumber, 1);
    }

    if (substr($vCdrNumber, 0, 2) ne '86' && substr($vCdrNumber, 0, 1) eq '1'){
        $vCdrNumber = '86' . $vCdrNumber
    }

    if (exists $vSubs{$vCdrNumber}){
        return 1;
    }else{
        return 0;
    }
}

#=====================================================
#处理文件头信息
sub vProcessFileHead{
    my ($vHeadString) = @_;

    $vHeadNetType      = substr($vHeadString, 0, 1);
    $vHeadFileVersion  = substr($vHeadString, 1, 2);
    $vHeadFileTime     = substr($vHeadString, 3, 14);
    $vHeadFileCountOrg = substr($vHeadString, 17, 12);
}

#=====================================================
#生成新的文件
sub vCreateOutFile{
    my ($v_file) = @_;
    my $v_OutFile = File::Spec->catpath('', $vSmbOutputPath, $v_file );

    return 0 if ($vHeadFileCountNew == 0);

    open FILEHEAD, ">$v_OutFile" or die "Cannot open $v_OutFile: $!";

    #写入文件头
    $vHeadFileCountNew = sprintf "%012d",$vHeadFileCountNew;
    print FILEHEAD "$vHeadNetType$vHeadFileVersion$vHeadFileTime$vHeadFileCountNew\n";

    #写入文件内容话单
    foreach (@vOutCdr){
        print FILEHEAD "$_\n";
    }

    close FILEHEAD;
}

#=====================================================
#处理单个文件
sub vProcessOneFile{
    my ($vFile)        = @_;
    $vHeadFileCountNew = -1;
    @vOutCdr = ();

    my $fv_netFlag    = "";
    my $fv_misdn      = "";
    my $fv_msgid      = "";

    my ($v_volume, $v_directories, $v_file) = File::Spec->splitpath( $vFile );
    my $v_TmpFile = File::Spec->catpath( $v_volume, $vSmbWorkPath, $v_file );
    my $v_BakFile = File::Spec->catpath( $v_volume, $vSmbBakPath, $v_file );

    rename $vFile, $v_TmpFile or die "can’ t rename $vFile to $v_TmpFile: $!\n";

    open FILEHEAD,$v_TmpFile or die "Cannot open $v_TmpFile: $!";

    while (<FILEHEAD>){
        chomp;
        if ($vHeadFileCountNew == -1){
            &vProcessFileHead($_);
            $vHeadFileCountNew++;
        }else{
            $fv_netFlag = substr($_, 0, 21);
            $fv_misdn   = substr($_, 21, 21);
            $fv_msgid   = substr($_, 42, 9);

            if( &vJudgeIsOcsNumber($fv_misdn) ){
                push @vOutCdr, $_;
                $vHeadFileCountNew++;
            }
        }
    }

    close FILEHEAD;

    &vCreateOutFile($v_file);

    rename $v_TmpFile, $v_BakFile or die "can’ t rename $v_TmpFile to $v_BakFile: $!\n";
}

#=====================================================
#处理上次一场退出的文件
sub vProcessTrash{
    my @vFileList = &vGetFileList($vSmbWorkPath);

    foreach (@vFileList){
        &vProcessOneFile($_);
    }
}

#=====================================================
#main
sub main{
    #加载资料到内存
    &vGetSubsInfo;

    #处理上次一场退出的临时文件
    &vProcessTrash;

    #获取需要处理的原始文件
    my @vFileList = &vGetFileList($vSmbSrcPath);

    #循环处理每个文件
    foreach (@vFileList){
        &vProcessOneFile($_);
    }

    undef %vSubs;
}

&main;

exit 0;