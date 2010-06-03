#!/bin/perl -w

#use lib '/ocs/cc611/scripts/perllib/lib/site_perl/5.8.2/aix-thread-multi';
use strict;
use DBI;
use Getopt::Std;
use Time::Local;

#=================================================
#   ��������Oracle���û����������
#=================================================
my %options;
getopts('hp:b:n:o:z:', \%options);
$options{h} && &usage;

#�������Ҫ�޸�һ������
#=================================================
my $dbname = "cc";
my $user   = "cc4cuc";
my $passwd = "cc4cuc";

my $tt_connStr = '"uid=ocs4cuc;pwd=ocs4cuc;dsn=ocs"';

#���ü��ص��ڴ淽ʽ��ܿ죬����һ��������ʹ���ڴ������ƣ����ز�����ô������
my $procType_userInfo = 0;      #0-�����ڴ�ķ�ʽ����,1-����DBM�ļ���ʽ����
my $procType_acctFeeInfo = 1;   #0-�����ڴ�ķ�ʽ����,1-����DBM�ļ���ʽ����
my $workPath = './tmp/';        #��ʱ����Ŀ¼
#=================================================

my $BalExpFile;
my $billing_cycle_id = $options{b} if (defined $options{b});
my $Per_BalFile;
my $Aft_BalFile;

my %userInfo;
my %AcctFeeInfo;

my $dbh;
my $DefResType;

my $sql_userInfo;
my $sql_acctBook;
my $sql_acctItemBilling;
my $sql_getDefResType;

#����Bal������
#=================================================
sub expBalTableDate{
    my ($fvOutFile) = @_;
    print 'ttBulkCp -Cnone -o -tsformat YYYYMMDDHH24MISS -connStr ' . $tt_connStr . ' bal ' . $fvOutFile . '.' . &getLocalTime(),"\n";
    my $fvCmd = 'ttBulkCp -Cnone -o -tsformat YYYYMMDDHH24MISS -connStr ' . $tt_connStr . ' bal ' . $fvOutFile . '.' . &getLocalTime();
    my $fvResult = readpipe($fvCmd);
    
    $fvResult =~ m/(\b.+)?\/(.+)/;
    #print 'Export Bal Info:',$fvResult,"\n";
    print "Export Bal Data count = [$1]!\n";
}

#��ȡ��ǰʱ��
#=================================================
sub getLocalTime{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon = sprintf "%02d", $mon + 1;
    $min = sprintf "%02d", $min;
    $sec = sprintf "%02d", $sec;
    
    return "$year$mon$mday$hour$min$sec";
}

#ʹ�ð���
#=================================================
sub usage{
    print<<ECHO;
ExpBalInfo4HB_lite.pl
    1,����TT��Bal����ϢΪ�ļ�
    2,���ɷ���BSS���û���Ϣ�ļ�

    -p BalTableBackFile     ����BAL����ļ����ƣ���·����
    -b BillingCycleId       ����ID
    -n BeforeAccountBalFile ����ǰ���ݵ�BAL�ļ�����·����
    -o AfterAccountBalFile  ���ʺ󱸷ݵ�BAL�ļ�����·����
    -z OutPutFile           ����ļ�����·����

Export Bal Table To File
ExpBalInfo4HB_lite.pl -p BalTableBackPath [-h]

OutPut BalInfoFile For Bss
ExpBalInfo4HB_lite.pl -b BillingCycleId -n BeforeAccountBalFile -o AfterAccountBalFile -z OutPutFile [-h]

ECHO
exit -1;
}

#��������ӵ�hash��ĳ��λ��
sub addItem4Hash{
    my ($hashName, $hashId, $hashSite, $value) = @_;
    my $fvHash;
    
    if ($hashName eq 'AcctFeeInfo'){
        $fvHash = \%AcctFeeInfo;
    }elsif($hashName eq 'userInfo'){
        $fvHash = \%userInfo;
    }
    
    my @recs = split /\|/,$$fvHash{$hashId};
    $recs[$hashSite] += $value;
    return join '|',@recs;
}

#��ȡȱʡ�������
#=================================================
sub getDefResType{
    #����SQL
    my $sth = $dbh->prepare($sql_getDefResType)
      or die "Can't prepare SQL statement: $DBI::errstr\n";
      
    #ִ������ѡȡ
    $sth->execute or die "Can't execute SQL statement: $DBI::errstr\n";
    
    #��ȡ��¼����
    while ( my @recs = $sth->fetchrow_array ) {
        #print "@recs\n";
        if (defined $recs[0]){
            chomp $recs[0];
            return $recs[0];
        }else{
            die "��ȡȱʡ�������ʧ�ܣ�";
        }
    }

    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#�����û���Ϣ���ڴ棬ֻ����'G'|'A'|'D'|'E'״̬���û�
#����subs_id����������acc_nbr��area_id���������ţ���credit_acct_id�������˻�ID����acct_id�������˻�ID|����˻�����������ӣ�
#����Чʱ�������ң����ͬһ����Чʱ�����ж��ټ�¼����ֻ��¼�ҵ��ĵ�һ�������ұ���
#=================================================
sub getUserInfo{
    #����SQL
    my $sth = $dbh->prepare($sql_userInfo)
      or die "Can't prepare SQL statement: $DBI::errstr\n";
      
    #ִ������ѡȡ
    $sth->execute or die "Can't execute SQL statement: $DBI::errstr\n";
    
    #��ȡ��¼����
    my $line_num = 0;
    print "��ʼ�����û���Ϣ���ݣ�\n";
    while ( my @recs = $sth->fetchrow_array ) {
        $line_num++;
        #print "@recs\n";
        if (defined $userInfo{$recs[0]}){
            #print "�Ѿ������û���¼,subs_id = [$userInfo{$recs[0]}[0]]\n";
            #push @{$userInfo{$recs[0]}},$recs[4];
            $userInfo{$recs[0]} = $userInfo{$recs[0]} . "|$recs[4]";
        }else{
            $userInfo{$recs[0]} = join '|',@recs;
            #print "�����û���¼,subs_id = [$recs[0]]\n";
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
    }
    print "���������ݣ�[$line_num]��\n";
    
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#����Acct_Book��Ϣ���ڴ�
#����ACCT_BOOK_TYPE = 'P'|'H'������
#����acct_id�����������³������³�ֵ(*)������ʵ�����ѣ���ĩ���
#=================================================
sub getAcctBook{
    #����SQL
    my $sth = $dbh->prepare($sql_acctBook)
      or die "Can't prepare SQL statement: $DBI::errstr\n";
      
    #ִ������ѡȡ
    $sth->execute or die "Can't execute SQL statement: $DBI::errstr\n";
    
    #��ȡ��¼����
    my $line_num = 0;
    print "��ʼ���ء�ACCT_BOOK����Ϣ���ݣ�\n";
    while ( my @recs = $sth->fetchrow_array ) {
        $line_num++;
        #print "@recs\n";
        if (defined $AcctFeeInfo{$recs[0]}){
            #print "�����ظ��ļ�¼����Ҫ�����ۼ�!acct_id=[$acctBook{$recs[0]}[0]]\n";
            #$AcctFeeInfo{$recs[0]}[1] += $recs[2];
            $AcctFeeInfo{$recs[0]} = &addItem4Hash('AcctFeeInfo', $recs[0], 1, $recs[2]);
        }else{
            $AcctFeeInfo{$recs[0]} = "0|$recs[2]|0|0";
            #print "�����û���¼,subs_id = [$recs[0]]\n";
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
    }
    print "���������ݣ�[$line_num]��\n";
    
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#����acct_item_billing_xxx���ڴ�
#����acct_id�����������³������³�ֵ������ʵ������(*)����ĩ���
#���ض�����¼�����з��õ��ۼ�
#=================================================
sub getAcctItemBillingData{
    #����SQL
    my $sth = $dbh->prepare($sql_acctItemBilling)
      or die "Can't prepare SQL statement: $DBI::errstr\n";
      
    #ִ������ѡȡ
    $sth->execute or die "Can't execute SQL statement: $DBI::errstr\n";
    
    #��ȡ��¼����
    my $line_num = 0;
    print "��ʼ���ء�ACCT_ITEM_BILLING_$billing_cycle_id����Ϣ���ݣ�\n";
    while ( my @recs = $sth->fetchrow_array ) {
        $line_num++;
        #print "@recs\n";
        if (defined $AcctFeeInfo{$recs[0]}){
            #print "�����ظ��ļ�¼!ACCT_ID=[$acctItemBilling{$recs[0]}[0]]\n";
            #$AcctFeeInfo{$recs[0]}[2] += $recs[2];
            $AcctFeeInfo{$recs[0]} = &addItem4Hash('AcctFeeInfo', $recs[0], 2, $recs[2]);
        }else{
            $AcctFeeInfo{$recs[0]} = "0|0|$recs[2]|0";
            #print "�����û���¼,subs_id = [$recs[0]]\n";
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
    }
    print "���������ݣ�[$line_num]��\n";
    
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#���س���ǰbal��Ϣ���ڴ�
#���أ�acct_id�����������³����(*)�����³�ֵ������ʵ�����ѣ���ĩ���
#ֻ����ȱʡ������ͣ�������¼�����ۼ�
#=================================================
sub getPer_BalInfo{
    open BALINFOFILE, $Per_BalFile or die "open bal.dat file fail: $!\n";
    
    #��ȡ��¼����
    my $line_num = 0;
    print "��ʼ���س���ǰbal���ݡ�$Per_BalFile���ļ���\n";
    #foreach my $fvRecsStr (<BALINFOFILE>) {
    while (defined(my $fvRecsStr = <BALINFOFILE>)) {
        #print "$fvRecsStr\n";
        chomp $fvRecsStr;
        next if $fvRecsStr =~ /^#/;
        
        $line_num ++;
        my @fvRecs = split /,/,$fvRecsStr;
        next if $fvRecs[2] != $DefResType;    #ֻ����ȱʡ�������
        
        $fvRecs[3] = 0 if (!defined $fvRecs[3] or $fvRecs[3] eq '' or $fvRecs[3] eq 'NULL');
        $fvRecs[5] = 0 if (!defined $fvRecs[5] or $fvRecs[5] eq '' or $fvRecs[5] eq 'NULL');
        
        #�����ڶ�����¼
        if (defined $AcctFeeInfo{$fvRecs[1]}){
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            #$AcctFeeInfo{$fvRecs[1]}[0] += $fvCharge;
            $AcctFeeInfo{$fvRecs[1]} = &addItem4Hash('AcctFeeInfo', $fvRecs[1], 0, $fvCharge);
        }else{
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            $AcctFeeInfo{$fvRecs[1]} = "$fvCharge|0|0|0";
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
        undef $fvRecsStr;
        undef @fvRecs;
    }
    
    close BALINFOFILE;
    
    print "���������ݣ�[$line_num]��\n";
    return $line_num;
}

#���س��ʺ�bal��Ϣ���ڴ�
#���أ�acct_id�����������³������³�ֵ������ʵ������(*)����ĩ���
#ֻ����ȱʡ������ͣ�������¼�����ۼ�
#=================================================
sub getAft_BalInfo{
    open BALINFOFILE, $Aft_BalFile or die "open bal.dat file fail: $!\n";
    
    #��ȡ��¼����
    my $line_num = 0;
    print "��ʼ���س��ʺ�bal���ݡ�$Aft_BalFile���ļ���\n";
    #foreach my $fvRecsStr (<BALINFOFILE>) {
    while (defined(my $fvRecsStr = <BALINFOFILE>)) {
        #print "$fvRecsStr\n";
        chomp $fvRecsStr;
        next if $fvRecsStr =~ /^#/;
        
        $line_num ++;
        my @fvRecs = split /,/,$fvRecsStr;
        next if $fvRecs[2] != $DefResType;    #ֻ����ȱʡ�������
        
        $fvRecs[3] = 0 if (!defined $fvRecs[3] or $fvRecs[3] eq '' or $fvRecs[3] eq 'NULL');
        $fvRecs[5] = 0 if (!defined $fvRecs[5] or $fvRecs[5] eq '' or $fvRecs[5] eq 'NULL');
        
        #�����ڶ�����¼
        if (defined $AcctFeeInfo{$fvRecs[1]}){
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            #$AcctFeeInfo{$fvRecs[1]}[3] += $fvCharge;
            $AcctFeeInfo{$fvRecs[1]} = &addItem4Hash('AcctFeeInfo', $fvRecs[1], 3, $fvCharge);
        }else{
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            $AcctFeeInfo{$fvRecs[1]} = "0|0|0|$fvCharge";
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
    }
    
    close BALINFOFILE;
    
    print "���������ݣ�[$line_num]��\n";
    return $line_num;
}

#=================================================
sub init{
    if (!-e $workPath){
        mkdir $workPath or die "Create Dir $workPath ERROR: $!\n";
    }
    
    $sql_userInfo = '
    SELECT S.SUBS_ID,
           NVL(S.ACC_NBR, \'NULL\'),
           NVL(S.AREA_ID, 0),
           NVL(S.ACCT_ID, 0),
           NVL(SA.ACCT_ID, 0)
      FROM SUBS S, SUBS_ACCT SA, prod p
     WHERE S.SUBS_ID = SA.SUBS_ID
       AND S.subs_id = P.prod_id
       AND P.prod_state IN (\'G\',\'A\',\'D\',\'E\')
       --and rownum < 10001
    ';
    
    $sql_acctBook = '
    SELECT AB.ACCT_ID, NVL(AB.CONTACT_CHANNEL_ID, 0), NVL(AB.CHARGE, 0)
      FROM ACCT_BOOK AB
     WHERE ACCT_BOOK_TYPE IN (\'P\', \'H\')
       AND ab.created_date >= (SELECT cycle_begin_date
                                 FROM billing_cycle
                                WHERE billing_cycle_id = ' . $billing_cycle_id . ')
       AND ab.created_date < (SELECT cycle_end_date
                                FROM billing_cycle
                               WHERE billing_cycle_id = ' . $billing_cycle_id . ')
    ';
    
    $sql_acctItemBilling = '
    SELECT AIB.ACCT_ID,
           AIB.SUBS_ID,
           NVL(AIB.CHARGE, 0),
           NVL(AIB.ACCT_ITEM_TYPE_ID, 0)
      FROM ACCT_ITEM_BILLING_' . $billing_cycle_id . '@LINK_RB AIB, ACCT_ITEM_TYPE AIT
     WHERE AIB.ACCT_ITEM_TYPE_ID = AIT.ACCT_ITEM_TYPE_ID
       AND AIT.ACCT_RES_ID =
           (SELECT CURRENT_VALUE
              FROM SYSTEM_PARAM
             WHERE MASK = \'DEFAULT_ACCT_RES_ID\')
    ';
      
    $sql_getDefResType = 'SELECT current_value FROM System_Param WHERE mask = \'DEFAULT_ACCT_RES_ID\'';
    
    #�������ݿ�
    $dbh    = DBI->connect( "dbi:Oracle:$dbname", $user, $passwd )
      or die "Can't connect to Oracle database: $DBI::errstr\n";
    
    #�����ݱ��浽DBM
    if ($procType_userInfo == 1){
        unlink "$workPath/userInfo_dbm.dir" or warn "����DBM�ļ�[userInfo_dbm.dir]��\n";
        unlink "$workPath/userInfo_dbm.pag" or warn "����DBM�ļ�[userInfo_dbm.pag]��$!\n";
        
        dbmopen(%userInfo, "$workPath/userInfo_dbm", 0644) || die "Cannot open DBM userInfo_dbm: $!";
    }
    if ($procType_acctFeeInfo == 1){
        unlink "$workPath/AcctFeeInfo_dbm.dir" or warn "����DBM�ļ�[AcctFeeInfo_dbm.dir]��\n";
        unlink "$workPath/AcctFeeInfo_dbm.pag" or warn "����DBM�ļ�[AcctFeeInfo_dbm.pag]��\n";
        
        dbmopen(%AcctFeeInfo, "$workPath/AcctFeeInfo_dbm", 0644) || die "Cannot open DBM AcctFeeInfo_dbm: $!";
    }
      
    $DefResType = &getDefResType();
      
    &getUserInfo();
    
    print "��ʼ����ɣ���ʼ���У�\n";
}

#=================================================
sub unInit{
    #�Ͽ�����
    $dbh->disconnect or warn "Disconnection failed: $DBI::errstr\n";
    
    undef %userInfo;
    if ($procType_userInfo == 1){
        dbmclose(%userInfo);
        #ɾ������Ŀ¼�´�ŵ�DBM�ļ�
        unlink "$workPath/userInfo_dbm.dir" or warn "ɾ��DBM�ļ�[userInfo_dbm.dir]����$!\n";
        unlink "$workPath/userInfo_dbm.pag" or warn "ɾ��DBM�ļ�[userInfo_dbm.pag]����$!\n";
    }
    
    undef %AcctFeeInfo;
    if ($procType_acctFeeInfo == 1){
        dbmclose(%AcctFeeInfo);
        #ɾ������Ŀ¼�´�ŵ�DBM�ļ�
        unlink "$workPath/AcctFeeInfo_dbm.dir" or warn "ɾ��DBM�ļ�[AcctFeeInfo_dbm.dir]����$!\n";
        unlink "$workPath/AcctFeeInfo_dbm.pag" or warn "ɾ��DBM�ļ�[AcctFeeInfo_dbm.pag]����$!\n";
    }
}

#���³������³�ֵ������ʵ�����ѣ���ĩ�����д�������һ���ṹ��
#acct_id�����������³������³�ֵ������ʵ�����ѣ���ĩ���
sub ProcAcctFee{
    &getPer_BalInfo();
    
    &getAcctBook();
    
    &getAcctItemBillingData();
    
    &getAft_BalInfo();
}

sub getValue{
    my ($str, $site) = @_;
    
    my @fvRecs = split /\|/,$str;
    
    return $fvRecs[$site];
}

#���ݼ��ص��ڴ������ƥ��������
#���У����룬�³������³�ֵ������ʵ�����ѣ���ĩ���
#=================================================
sub Run{
    my ($fvOutFileName) = @_;
    $fvOutFileName = &CreateOutFileName($fvOutFileName);
    print '����ļ�����:',$fvOutFileName,"\n";
    open OUTCDR, ">$fvOutFileName" or die "open OUTCDR file fail: $!\n";
    
    for my $fvSubs_id (keys %userInfo){
        my @fv_userInfo = split /\|/,$userInfo{$fvSubs_id};
        my @out_info;
        
        my $fvSubsAcctNum = $#fv_userInfo - 3;
        
        #����
        push @out_info, $fv_userInfo[2];
        
        #����
        push @out_info, $fv_userInfo[1];
        
        if (defined $AcctFeeInfo{$fv_userInfo[3]}){     #�ȸ�ֵ�����˱�
            push @out_info, &getValue($AcctFeeInfo{$fv_userInfo[3]}, 0) && 0;
            push @out_info, &getValue($AcctFeeInfo{$fv_userInfo[3]}, 1) && 0;
            push @out_info, &getValue($AcctFeeInfo{$fv_userInfo[3]}, 2) && 0;
            push @out_info, &getValue($AcctFeeInfo{$fv_userInfo[3]}, 3) && 0;
            #��ʼ�ۼӱ����˱�
            if ($fvSubsAcctNum == 1){                   #���û�ֻ��һ�������˱���ʱ��
                $out_info[2] += &getValue($AcctFeeInfo{$fv_userInfo[4]}, 0);
                $out_info[3] += &getValue($AcctFeeInfo{$fv_userInfo[4]}, 1);
                $out_info[4] += &getValue($AcctFeeInfo{$fv_userInfo[4]}, 2);
                $out_info[5] += &getValue($AcctFeeInfo{$fv_userInfo[4]}, 3);
            }elsif($fvSubsAcctNum > 1){                 #���û������˱�������1
                for (my $i=1; $i<=$fvSubsAcctNum; $i++){
                    $out_info[2] += &getValue($AcctFeeInfo{$fv_userInfo[$i + 3]}, 0);
                    $out_info[3] += &getValue($AcctFeeInfo{$fv_userInfo[$i + 3]}, 1);
                    $out_info[4] += &getValue($AcctFeeInfo{$fv_userInfo[$i + 3]}, 2);
                    $out_info[5] += &getValue($AcctFeeInfo{$fv_userInfo[$i + 3]}, 3);
                }
            }
        }else{
            push @out_info, 0;
            push @out_info, 0;
            push @out_info, 0;
            push @out_info, 0;
        }
        
        print OUTCDR join '|',@out_info;
        print OUTCDR "\n";
    }
    
    close OUTCDR;
}

#�������ļ���
#=================================================
sub CreateOutFileName{
    return $_[0] . '.' . &getLocalTime();
}

#=================================================
sub main{
    if (defined $options{p}){
        print "��ʼ����Bal�����ݵ���$options{p}\n";
        &expBalTableDate($options{p});
    }elsif(defined $options{b} && defined $options{n} && defined $options{o} && defined $options{z}){
        print "��ʼ���ɸ�BSS������!\n";
        
        $BalExpFile       = $options{p};
        $billing_cycle_id = $options{b};
        $Per_BalFile      = $options{n};
        $Aft_BalFile      = $options{o};
        
        &init();
        
        #�����³������³�ֵ������ʵ�����ѣ���ĩ���
        &ProcAcctFee();
        
        &Run($options{z});
        
        &unInit();
    }else{
        &usage();
    }
}

#=================================================
main;

exit 0;
