#!/usr/bin/perl -w

use DBI;
use File::Spec;

#���ݿ���������
#=====================================================
my $vDBName     = "cc";
my $vDBUserName = "cc";
my $vDBPasswd   = "smart123";
my $vDBHead     = "";
my $vSTH        = "";
my %vSubs       = ();
my @vOutCdr     = ();

#��ȡ���ݿ����û���ϢSQL
my $vUserSqlStr='SELECT S.PREFIX || S.ACC_NBR, P.PROD_STATE FROM SUBS S, PROD P WHERE S.SUBS_ID = P.PROD_ID';

#���������ļ�����·������
#=====================================================
#�������ز����·��
my $vSmbSrcPath="/ztesoft/ocs/data/pp/smb/src/download_smb/";
#�������ر��ݻ���·��
my $vSmbBakPath="/ztesoft/ocs/data/pp/smb/src/bak/";
#�������ػ���������ʱ·��,�������ʱ�ļ�����������Ŀ¼
my $vSmbWorkPath="/ztesoft/ocs/data/pp/smb/src/download_smb/tmp/";
#�������ش���󻰵����·��
my $vSmbOutputPath="/ztesoft/ocs/data/pp/smb/src/";

#ͣ��ʱ����,��λΪ��
my $vSleepTime=10;

#��������ʱ�ļ�,���а���������ļ�����,�����ڶ���������Ϣ,
#��������֮ǰ�ȼ���Ƿ�������ļ�,���������Ŵ���
my $vTmpInfoFile="${vSmbWorkPath}/FileterSmbCdr_TmpInfoFile.txt";
my $vTmpCdrFile="${vSmbWorkPath}/FileterSmbCdr_TmpCdr.txt";

#=====================================================
my $vHeadNetType      = "G";
my $vHeadFileVersion  = "00";
my $vHeadFileTime     = &vGetLocalTime;
my $vHeadFileCountOrg = 0;
my $vHeadFileCountNew = 0;

#=====================================================


#�����ӳ���
#=====================================================
#��ȡ��ʱϵͳʱ��
sub vGetLocalTime{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $yday = $yday + 1900;
    return "$year$mon$yday$hour$min$sec";
}

#=====================================================
#��ȡ���ݿ��ж�����Ϣ
sub vGetSubsInfo{
    $vDBHead = DBI->connect( "dbi:Oracle:$vDBName", $vDBUserName, $vDBPasswd )
      or die "Can't connect to Oracle database: $DBI::errstr\n";

    #�������ݿ�
    my $vSTH = $vDBHead->prepare($vUserSqlStr)
      or die "Can't prepare SQL statement: $DBI::errstr\n";

    $vSTH->execute or die "Can't execute SQL statement: $DBI::errstr\n";

    #��ȡ��¼����
    while ( my @vRecs = $vSTH->fetchrow_array ) {
        #print "@vRecs\n";
        #���Ѿ�������ͬ�ĺ���ʱ
        if (exists $vSubs{$vRecs[0]}){
            $vSubs{$vRecs[0]} = $vRecs[1] if ( $vSubs{$vRecs[0]} ne 'A' );
        #��������ͬ����ʱ
        }else{
            $vSubs{$vRecs[0]} = $vRecs[1];
        }
    }
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;

    #�Ͽ�����
    $vDBHead->disconnect or warn "Disconnection failed: $DBI::errstr\n";
}

#=====================================================
#��ȡɨ��Ŀ¼���ļ��б������
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
#�жϻ����к����Ƿ�OCS����
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
#�����ļ�ͷ��Ϣ
sub vProcessFileHead{
    my ($vHeadString) = @_;

    $vHeadNetType      = substr($vHeadString, 0, 1);
    $vHeadFileVersion  = substr($vHeadString, 1, 2);
    $vHeadFileTime     = substr($vHeadString, 3, 14);
    $vHeadFileCountOrg = substr($vHeadString, 17, 12);
}

#=====================================================
#�����µ��ļ�
sub vCreateOutFile{
    my ($v_file) = @_;
    my $v_OutFile = File::Spec->catpath('', $vSmbOutputPath, $v_file );

    return 0 if ($vHeadFileCountNew == 0);

    open FILEHEAD, ">$v_OutFile" or die "Cannot open $v_OutFile: $!";

    #д���ļ�ͷ
    $vHeadFileCountNew = sprintf "%012d",$vHeadFileCountNew;
    print FILEHEAD "$vHeadNetType$vHeadFileVersion$vHeadFileTime$vHeadFileCountNew\n";

    #д���ļ����ݻ���
    foreach (@vOutCdr){
        print FILEHEAD "$_\n";
    }

    close FILEHEAD;
}

#=====================================================
#�������ļ�
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

    rename $vFile, $v_TmpFile or die "can�� t rename $vFile to $v_TmpFile: $!\n";

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

    rename $v_TmpFile, $v_BakFile or die "can�� t rename $v_TmpFile to $v_BakFile: $!\n";
}

#=====================================================
#�����ϴ�һ���˳����ļ�
sub vProcessTrash{
    my @vFileList = &vGetFileList($vSmbWorkPath);

    foreach (@vFileList){
        &vProcessOneFile($_);
    }
}

#=====================================================
#main
sub main{
    #�������ϵ��ڴ�
    &vGetSubsInfo;

    #�����ϴ�һ���˳�����ʱ�ļ�
    &vProcessTrash;

    #��ȡ��Ҫ�����ԭʼ�ļ�
    my @vFileList = &vGetFileList($vSmbSrcPath);

    #ѭ������ÿ���ļ�
    foreach (@vFileList){
        &vProcessOneFile($_);
    }

    undef %vSubs;
}

&main;

exit 0;