#!/bin/perl -w

use lib '/ocs/cc611/scripts/perllib/lib/site_perl/5.8.2/aix-thread-multi';
use strict;
use DBI;
use Data::Dumper;
use Getopt::Std;
use Time::Local;

#=================================================
#   ��������Oracle���û����������
#=================================================
my %options;
getopts('hp:b:n:o:z:', \%options);
$options{h} && &usage;
#=================================================
my $dbname = "cc";
my $user   = "cc";
my $passwd = "smart123";

my $tt_connStr = '"uid=ocs;pwd=ocs123;dsn=ocs"';
#=================================================
my $BalExpFile;
my $billing_cycle_id = $options{b} if (defined $options{b});
my $Per_BalFile;
my $Aft_BalFile;

my %userInfo;
my %acctBook;
my %acctItemBilling;
my %perBalInfo;
my %aftBalInfo;
my %outPutInfo;

my $dbh;
my $DefResType;

my $sql_userInfo = '
SELECT S.SUBS_ID,
       NVL(S.ACC_NBR, \'NULL\'),
       NVL(S.AREA_ID, 0),
       NVL(S.ACCT_ID, 0),
       NVL(SA.ACCT_ID, 0)
  FROM SUBS S, SUBS_ACCT SA, prod p
 WHERE S.SUBS_ID = SA.SUBS_ID
   AND S.subs_id = P.prod_id
   AND P.prod_state IN (\'G\',\'A\',\'D\',\'E\')
';

my $sql_acctBook = '
SELECT AB.ACCT_ID, NVL(AB.CONTACT_CHANNEL_ID, 0), NVL(AB.CHARGE, 0)
  FROM ACCT_BOOK AB
 WHERE ACCT_BOOK_TYPE IN (\'P\', \'H\')
';

my $sql_acctItemBilling = '
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
  
my $sql_getDefResType = 'SELECT current_value FROM System_Param WHERE mask = \'DEFAULT_ACCT_RES_ID\'';

#����Bal������
#=================================================
sub expBalTableDate{
    my ($fvOutFile) = @_;
    my $fvCmd = 'ttBulkCp -Cnone -o -tsformat YYYYMMDDHH24MISS -connStr ' . $tt_connStr . ' ocs.bal ' . $fvOutFile . &getLocalTime();
    my $fvResult = readpipe($fvCmd);
    
    $fvResult =~ m/(\b.+)?\/(.+)/;
    #print 'Export Bal Info:',$fvResult,"\n";
    print "Export Bal Date count = [$1]!\n";
}

#��ȡ��ǰʱ��
#=================================================
sub getLocalTime{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    return "$year$mon$yday$hour$min$sec";
}

#ʹ�ð���
#=================================================
sub usage{
    print<<ECHO;
ExpBalInfo4HB.pl
    1,Export Bal Table Date
    2,OutPut BalInfoFile For Bss

    -p BalTableBackFile
    -b BillingCycleId
    -n BeforeAccountBalFile
    -o AfterAccountBalFile
    -z OutPutFile

Export Bal Table To File
ExpBalInfo4HB.pl -p BalTableBackPath [-h]

OutPut BalInfoFile For Bss
ExpBalInfo4HB.pl -b BillingCycleId -n BeforeAccountBalFile -o AfterAccountBalFile -z OutPutFile [-h]

ECHO
exit -1;
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
        if (exists $userInfo{$recs[0]}){
            #print "�Ѿ������û���¼,subs_id = [$userInfo{$recs[0]}[0]]\n";
            push @{$userInfo{$recs[0]}},$recs[4];
            #my $a = $#{$userInfo{$recs[0]}} - 3;
            #print "�û����б����˱�����$a����\n";
        }else{
            $userInfo{$recs[0]} = [@recs];
            #print "�����û���¼,subs_id = [$recs[0]]\n";
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
    }
    print "���������ݣ�[$line_num]��\n";
    
    #print Dumper(\%userInfo);
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#����Acct_Book��Ϣ���ڴ�
#����ACCT_BOOK_TYPE = 'P'|'H'������
#����acct_id������|������¼�ۼӵ�һ������contact_channel_id��CHARGE
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
        if (exists $acctBook{$recs[0]}){
            #print "�����ظ��ļ�¼����Ҫ�����ۼ�!acct_id=[$acctBook{$recs[0]}[0]]\n";
            $acctBook{$recs[0]}[2] += $recs[2];
        }else{
            $acctBook{$recs[0]} = [@recs];
            #print "�����û���¼,subs_id = [$recs[0]]\n";
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
    }
    print "���������ݣ�[$line_num]��\n";
    
    #print Dumper(\%acctBook);
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#����acct_item_billing_xxx���ڴ�
#����ACCT_ID����������subs_id��ACCT_ITEM_TYPE_ID��CHARGE
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
        if (exists $acctItemBilling{$recs[0]}){
            #print "�����ظ��ļ�¼!ACCT_ID=[$acctItemBilling{$recs[0]}[0]]\n";
            $acctItemBilling{$recs[0]}[3] += $recs[3];
        }else{
            $acctItemBilling{$recs[0]} = [@recs];
            #print "�����û���¼,subs_id = [$recs[0]]\n";
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
    }
    print "���������ݣ�[$line_num]��\n";
    
    #print Dumper(\%acctItemBilling);
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
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

#���س���ǰbal��Ϣ���ڴ�
#���أ�ACCT_ID����������ACCT_RES_ID��charge��GROSS_BAL+CONSUME_BAL��
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
        if (exists $perBalInfo{$fvRecs[1]}){
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            $perBalInfo{$fvRecs[1]}[2] += $fvCharge;
        }else{
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            @{$aftBalInfo{$fvRecs[1]}} = ($fvRecs[1], $fvRecs[2], $fvCharge);
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
        undef $fvRecsStr;
        undef @fvRecs;
    }
    
    close BALINFOFILE;
    
    print "���������ݣ�[$line_num]��\n";
    #print Dumper(\%perBalInfo);
    return $line_num;
}

#���س��ʺ�bal��Ϣ���ڴ�
#���أ�ACCT_ID����������ACCT_RES_ID��charge��GROSS_BAL+CONSUME_BAL��
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
        if (exists $aftBalInfo{$fvRecs[1]}){
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            $aftBalInfo{$fvRecs[1]}[2] += $fvCharge;
        }else{
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            @{$aftBalInfo{$fvRecs[1]}} = ($fvRecs[1], $fvRecs[2], $fvCharge);
        }
        
        print "�Ѿ��������ݣ�[$line_num]��\n" if ($line_num % 10000 == 0);
    }
    
    close BALINFOFILE;
    
    print "���������ݣ�[$line_num]��\n";
    #print Dumper(\%aftBalInfo);
    return $line_num;
}

#=================================================
sub init{
    #�������ݿ�
    $dbh    = DBI->connect( "dbi:Oracle:$dbname", $user, $passwd )
      or die "Can't connect to Oracle database: $DBI::errstr\n";
      
    $DefResType = &getDefResType();
      
    &getUserInfo();
    
    print "��ʼ����ɣ���ʼ���У�\n";
}

#=================================================
sub unInit{
    #�Ͽ�����
    $dbh->disconnect or warn "Disconnection failed: $DBI::errstr\n";
    
    undef %userInfo;
    
    undef %outPutInfo;
}

#=================================================
sub addCharge{
    my ($fvChargeType, $fvSubsAcctNum, $fvSubsId) = @_;
    my $fvHash;
    
    if ($fvChargeType eq 'acctBook'){
        $fvHash = \%acctBook;
    }elsif ($fvChargeType eq 'acctItemBilling'){
        $fvHash = \%acctItemBilling;
    }elsif ($fvChargeType eq 'perBalInfo'){
        $fvHash = \%perBalInfo;
    }elsif ($fvChargeType eq 'aftBalInfo'){
        $fvHash = \%aftBalInfo;
    }else{
        die "δ֪���ڴ�����\n";
    }
    my $fvCharge = 0;
    $fvCharge += $$fvHash{$userInfo{$fvSubsId}[3]}[2] if (exists $$fvHash{$userInfo{$fvSubsId}[3]});
    if ( $fvSubsAcctNum > 1 ){
        
        for (my $i=1; $i<=$fvSubsAcctNum; $i++){
            $fvCharge += $$fvHash{$userInfo{$fvSubsId}[$i+3]}[2] if (exists $$fvHash{$userInfo{$fvSubsId}[3]});
        }
        return $fvCharge;
    }else{
        my $fvCharge += $$fvHash{$userInfo{$fvSubsId}[4]}[2] if (exists $$fvHash{$userInfo{$fvSubsId}[4]});
        return $fvCharge;
    }
    
    $fvHash = undef;
}

#���ݼ��ص��ڴ������ƥ��������
#���У����룬�³������³�ֵ������ʵ�����ѣ���ĩ���
#=================================================
sub Run{
    for my $fvSubs_id (keys %userInfo){
        my $fvSubsAcctNum = $#{$userInfo{$fvSubs_id}} - 3;
        
        #����
        push @{ $outPutInfo{$fvSubs_id} },$userInfo{$fvSubs_id}[2];
        
        #����
        push @{ $outPutInfo{$fvSubs_id} },$userInfo{$fvSubs_id}[1];
        
        #�³����
        &getPer_BalInfo();
        push @{ $outPutInfo{$fvSubs_id} }, &addCharge('perBalInfo',$fvSubsAcctNum,$fvSubs_id);
        undef %perBalInfo;
        
        #���³�ֵ
        &getAcctBook();
        push @{ $outPutInfo{$fvSubs_id} }, &addCharge('acctBook',$fvSubsAcctNum,$fvSubs_id);
        undef %acctBook;
        
        #����ʵ������
        &getAcctItemBillingData();
        push @{ $outPutInfo{$fvSubs_id} }, &addCharge('acctItemBilling',$fvSubsAcctNum,$fvSubs_id);
        undef %acctItemBilling;
        
        #��ĩ���
        &getAft_BalInfo();
        push @{ $outPutInfo{$fvSubs_id} }, &addCharge('aftBalInfo',$fvSubsAcctNum,$fvSubs_id);
        undef %aftBalInfo;
    }
}

#�������ļ���
#=================================================
sub CreateOutFileName{
    return $_[0] . &getLocalTime();
}


#��ƥ���������
#=================================================
sub OutPutCdr{
    my $fvOutFileName = &CreateOutFileName($_[0]);
    print '����ļ�����:',$fvOutFileName,"\n";
    open OUTCDR, ">$fvOutFileName" or die "open OUTCDR file fail: $!\n";
    
    for my $fvRowKey (keys %outPutInfo){
        if (defined $outPutInfo{$fvRowKey}){
            $outPutInfo{$fvRowKey}[2] = 'NULL' if (!defined $outPutInfo{$fvRowKey}[2]);
            $outPutInfo{$fvRowKey}[3] = 'NULL' if (!defined $outPutInfo{$fvRowKey}[3]);
            $outPutInfo{$fvRowKey}[4] = 'NULL' if (!defined $outPutInfo{$fvRowKey}[4]);
            $outPutInfo{$fvRowKey}[5] = 'NULL' if (!defined $outPutInfo{$fvRowKey}[5]);
            
            print OUTCDR join '|',@{ $outPutInfo{$fvRowKey} };
            print OUTCDR "\n";
        }
    }
    
    close OUTCDR;
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

        &Run();
        &OutPutCdr($options{z});

        &unInit();
    }else{
        &usage();
    }
}

#=================================================
main;

exit 0;
