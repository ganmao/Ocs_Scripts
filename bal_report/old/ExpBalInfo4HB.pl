#!/bin/perl -w

use lib '/ocs/cc611/scripts/perllib/lib/site_perl/5.8.2/aix-thread-multi';
use strict;
use DBI;
use Data::Dumper;
use Getopt::Std;
use Time::Local;

#=================================================
#   定义链接Oracle的用户名，密码等
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

#导出Bal表数据
#=================================================
sub expBalTableDate{
    my ($fvOutFile) = @_;
    my $fvCmd = 'ttBulkCp -Cnone -o -tsformat YYYYMMDDHH24MISS -connStr ' . $tt_connStr . ' ocs.bal ' . $fvOutFile . &getLocalTime();
    my $fvResult = readpipe($fvCmd);
    
    $fvResult =~ m/(\b.+)?\/(.+)/;
    #print 'Export Bal Info:',$fvResult,"\n";
    print "Export Bal Date count = [$1]!\n";
}

#获取当前时间
#=================================================
sub getLocalTime{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    return "$year$mon$yday$hour$min$sec";
}

#使用帮助
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

#加载用户信息到内存，只加载'G'|'A'|'D'|'E'状态的用户
#加载subs_id（主键），acc_nbr，area_id（地区区号），credit_acct_id（信用账户ID），acct_id（本金账户ID|多个账户依次向后增加）
#按有效时间来查找，如果同一个有效时间内有多少记录，则只记录找到的第一条，并且报错
#=================================================
sub getUserInfo{
    #解析SQL
    my $sth = $dbh->prepare($sql_userInfo)
      or die "Can't prepare SQL statement: $DBI::errstr\n";
      
    #执行数据选取
    $sth->execute or die "Can't execute SQL statement: $DBI::errstr\n";
    
    #读取记录数据
    my $line_num = 0;
    print "开始加载用户信息数据：\n";
    while ( my @recs = $sth->fetchrow_array ) {
        $line_num++;
        #print "@recs\n";
        if (exists $userInfo{$recs[0]}){
            #print "已经存在用户记录,subs_id = [$userInfo{$recs[0]}[0]]\n";
            push @{$userInfo{$recs[0]}},$recs[4];
            #my $a = $#{$userInfo{$recs[0]}} - 3;
            #print "用户共有本金账本：【$a】个\n";
        }else{
            $userInfo{$recs[0]} = [@recs];
            #print "加载用户记录,subs_id = [$recs[0]]\n";
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
    }
    print "共加载数据：[$line_num]条\n";
    
    #print Dumper(\%userInfo);
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#加载Acct_Book信息到内存
#加载ACCT_BOOK_TYPE = 'P'|'H'的数据
#加载acct_id（主键|多条记录累加到一条），contact_channel_id，CHARGE
#=================================================
sub getAcctBook{
    #解析SQL
    my $sth = $dbh->prepare($sql_acctBook)
      or die "Can't prepare SQL statement: $DBI::errstr\n";
      
    #执行数据选取
    $sth->execute or die "Can't execute SQL statement: $DBI::errstr\n";
    
    #读取记录数据
    my $line_num = 0;
    print "开始加载【ACCT_BOOK】信息数据：\n";
    while ( my @recs = $sth->fetchrow_array ) {
        $line_num++;
        #print "@recs\n";
        if (exists $acctBook{$recs[0]}){
            #print "存在重复的记录，需要进行累加!acct_id=[$acctBook{$recs[0]}[0]]\n";
            $acctBook{$recs[0]}[2] += $recs[2];
        }else{
            $acctBook{$recs[0]} = [@recs];
            #print "加载用户记录,subs_id = [$recs[0]]\n";
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
    }
    print "共加载数据：[$line_num]条\n";
    
    #print Dumper(\%acctBook);
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#加载acct_item_billing_xxx到内存
#加载ACCT_ID（主键），subs_id，ACCT_ITEM_TYPE_ID，CHARGE
#加载多条记录，进行费用的累加
#=================================================
sub getAcctItemBillingData{
    #解析SQL
    my $sth = $dbh->prepare($sql_acctItemBilling)
      or die "Can't prepare SQL statement: $DBI::errstr\n";
      
    #执行数据选取
    $sth->execute or die "Can't execute SQL statement: $DBI::errstr\n";
    
    #读取记录数据
    my $line_num = 0;
    print "开始加载【ACCT_ITEM_BILLING_$billing_cycle_id】信息数据：\n";
    while ( my @recs = $sth->fetchrow_array ) {
        $line_num++;
        #print "@recs\n";
        if (exists $acctItemBilling{$recs[0]}){
            #print "存在重复的记录!ACCT_ID=[$acctItemBilling{$recs[0]}[0]]\n";
            $acctItemBilling{$recs[0]}[3] += $recs[3];
        }else{
            $acctItemBilling{$recs[0]} = [@recs];
            #print "加载用户记录,subs_id = [$recs[0]]\n";
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
    }
    print "共加载数据：[$line_num]条\n";
    
    #print Dumper(\%acctItemBilling);
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#获取缺省余额类型
#=================================================
sub getDefResType{
    #解析SQL
    my $sth = $dbh->prepare($sql_getDefResType)
      or die "Can't prepare SQL statement: $DBI::errstr\n";
      
    #执行数据选取
    $sth->execute or die "Can't execute SQL statement: $DBI::errstr\n";
    
    #读取记录数据
    while ( my @recs = $sth->fetchrow_array ) {
        #print "@recs\n";
        if (defined $recs[0]){
            chomp $recs[0];
            return $recs[0];
        }else{
            die "获取缺省余额类型失败！";
        }
    }

    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#加载出帐前bal信息到内存
#加载：ACCT_ID（主键），ACCT_RES_ID，charge（GROSS_BAL+CONSUME_BAL）
#只加载缺省余额类型，多条记录进行累计
#=================================================
sub getPer_BalInfo{
    open BALINFOFILE, $Per_BalFile or die "open bal.dat file fail: $!\n";
    
    #读取记录数据
    my $line_num = 0;
    print "开始加载出帐前bal备份【$Per_BalFile】文件：\n";
    #foreach my $fvRecsStr (<BALINFOFILE>) {
    while (defined(my $fvRecsStr = <BALINFOFILE>)) {
        #print "$fvRecsStr\n";
        chomp $fvRecsStr;
        next if $fvRecsStr =~ /^#/;
        
        $line_num ++;
        my @fvRecs = split /,/,$fvRecsStr;
        next if $fvRecs[2] != $DefResType;    #只加载缺省余额类型
        
        $fvRecs[3] = 0 if (!defined $fvRecs[3] or $fvRecs[3] eq '' or $fvRecs[3] eq 'NULL');
        $fvRecs[5] = 0 if (!defined $fvRecs[5] or $fvRecs[5] eq '' or $fvRecs[5] eq 'NULL');
        
        #当存在多条记录
        if (exists $perBalInfo{$fvRecs[1]}){
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            $perBalInfo{$fvRecs[1]}[2] += $fvCharge;
        }else{
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            @{$aftBalInfo{$fvRecs[1]}} = ($fvRecs[1], $fvRecs[2], $fvCharge);
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
        undef $fvRecsStr;
        undef @fvRecs;
    }
    
    close BALINFOFILE;
    
    print "共加载数据：[$line_num]条\n";
    #print Dumper(\%perBalInfo);
    return $line_num;
}

#加载出帐后bal信息到内存
#加载：ACCT_ID（主键），ACCT_RES_ID，charge（GROSS_BAL+CONSUME_BAL）
#只加载缺省余额类型，多条记录进行累计
#=================================================
sub getAft_BalInfo{
    open BALINFOFILE, $Aft_BalFile or die "open bal.dat file fail: $!\n";
    
    #读取记录数据
    my $line_num = 0;
    print "开始加载出帐后bal备份【$Aft_BalFile】文件：\n";
    #foreach my $fvRecsStr (<BALINFOFILE>) {
    while (defined(my $fvRecsStr = <BALINFOFILE>)) {
        #print "$fvRecsStr\n";
        chomp $fvRecsStr;
        next if $fvRecsStr =~ /^#/;
        
        $line_num ++;
        my @fvRecs = split /,/,$fvRecsStr;
        next if $fvRecs[2] != $DefResType;    #只加载缺省余额类型
        
        $fvRecs[3] = 0 if (!defined $fvRecs[3] or $fvRecs[3] eq '' or $fvRecs[3] eq 'NULL');
        $fvRecs[5] = 0 if (!defined $fvRecs[5] or $fvRecs[5] eq '' or $fvRecs[5] eq 'NULL');
        
        #当存在多条记录
        if (exists $aftBalInfo{$fvRecs[1]}){
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            $aftBalInfo{$fvRecs[1]}[2] += $fvCharge;
        }else{
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            @{$aftBalInfo{$fvRecs[1]}} = ($fvRecs[1], $fvRecs[2], $fvCharge);
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
    }
    
    close BALINFOFILE;
    
    print "共加载数据：[$line_num]条\n";
    #print Dumper(\%aftBalInfo);
    return $line_num;
}

#=================================================
sub init{
    #连接数据库
    $dbh    = DBI->connect( "dbi:Oracle:$dbname", $user, $passwd )
      or die "Can't connect to Oracle database: $DBI::errstr\n";
      
    $DefResType = &getDefResType();
      
    &getUserInfo();
    
    print "初始化完成，开始运行！\n";
}

#=================================================
sub unInit{
    #断开连接
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
        die "未知的内存类型\n";
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

#根据加载到内存的数据匹配输出结果
#地市，号码，月初余额，本月充值，本月实际消费，月末余额
#=================================================
sub Run{
    for my $fvSubs_id (keys %userInfo){
        my $fvSubsAcctNum = $#{$userInfo{$fvSubs_id}} - 3;
        
        #地市
        push @{ $outPutInfo{$fvSubs_id} },$userInfo{$fvSubs_id}[2];
        
        #号码
        push @{ $outPutInfo{$fvSubs_id} },$userInfo{$fvSubs_id}[1];
        
        #月初余额
        &getPer_BalInfo();
        push @{ $outPutInfo{$fvSubs_id} }, &addCharge('perBalInfo',$fvSubsAcctNum,$fvSubs_id);
        undef %perBalInfo;
        
        #本月充值
        &getAcctBook();
        push @{ $outPutInfo{$fvSubs_id} }, &addCharge('acctBook',$fvSubsAcctNum,$fvSubs_id);
        undef %acctBook;
        
        #本月实际消费
        &getAcctItemBillingData();
        push @{ $outPutInfo{$fvSubs_id} }, &addCharge('acctItemBilling',$fvSubsAcctNum,$fvSubs_id);
        undef %acctItemBilling;
        
        #月末余额
        &getAft_BalInfo();
        push @{ $outPutInfo{$fvSubs_id} }, &addCharge('aftBalInfo',$fvSubsAcctNum,$fvSubs_id);
        undef %aftBalInfo;
    }
}

#组合输出文件名
#=================================================
sub CreateOutFileName{
    return $_[0] . &getLocalTime();
}


#将匹配数据输出
#=================================================
sub OutPutCdr{
    my $fvOutFileName = &CreateOutFileName($_[0]);
    print '输出文件名称:',$fvOutFileName,"\n";
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
        print "开始到处Bal表数据到：$options{p}\n";
        &expBalTableDate($options{p});
    }elsif(defined $options{b} && defined $options{n} && defined $options{o} && defined $options{z}){
        print "开始生成给BSS的数据!\n";
        
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
