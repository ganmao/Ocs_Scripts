#!/bin/perl -w

#use lib '/ocs/cc611/scripts/perllib/lib/site_perl/5.8.2/aix-thread-multi';
use strict;
use DBI;
use Getopt::Std;
use Time::Local;

#=================================================
#   定义链接Oracle的用户名，密码等
#=================================================
my %options;
getopts('hp:b:n:o:z:', \%options);
$options{h} && &usage;

#请根据需要修改一下内容
#=================================================
my $dbname = "cc";
my $user   = "cc4cuc";
my $passwd = "cc4cuc";

my $tt_connStr = '"uid=ocs4cuc;pwd=ocs4cuc;dsn=ocs"';

#采用加载到内存方式会很快，但是一般主机对使用内存有限制，加载不了那么多资料
my $procType_userInfo = 0;      #0-采用内存的方式加载,1-采用DBM文件形式加载
my $procType_acctFeeInfo = 1;   #0-采用内存的方式加载,1-采用DBM文件形式加载
my $workPath = './tmp/';        #临时工作目录
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

#导出Bal表数据
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

#获取当前时间
#=================================================
sub getLocalTime{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon = sprintf "%02d", $mon + 1;
    $min = sprintf "%02d", $min;
    $sec = sprintf "%02d", $sec;
    
    return "$year$mon$mday$hour$min$sec";
}

#使用帮助
#=================================================
sub usage{
    print<<ECHO;
ExpBalInfo4HB_lite.pl
    1,导出TT中Bal表信息为文件
    2,生成发给BSS的用户信息文件

    -p BalTableBackFile     导出BAL表的文件名称（含路径）
    -b BillingCycleId       帐期ID
    -n BeforeAccountBalFile 出帐前备份的BAL文件（含路径）
    -o AfterAccountBalFile  出帐后备份的BAL文件（含路径）
    -z OutPutFile           输出文件（含路径）

Export Bal Table To File
ExpBalInfo4HB_lite.pl -p BalTableBackPath [-h]

OutPut BalInfoFile For Bss
ExpBalInfo4HB_lite.pl -b BillingCycleId -n BeforeAccountBalFile -o AfterAccountBalFile -z OutPutFile [-h]

ECHO
exit -1;
}

#将参数添加到hash的某个位置
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
        if (defined $userInfo{$recs[0]}){
            #print "已经存在用户记录,subs_id = [$userInfo{$recs[0]}[0]]\n";
            #push @{$userInfo{$recs[0]}},$recs[4];
            $userInfo{$recs[0]} = $userInfo{$recs[0]} . "|$recs[4]";
        }else{
            $userInfo{$recs[0]} = join '|',@recs;
            #print "加载用户记录,subs_id = [$recs[0]]\n";
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
    }
    print "共加载数据：[$line_num]条\n";
    
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#加载Acct_Book信息到内存
#加载ACCT_BOOK_TYPE = 'P'|'H'的数据
#加载acct_id（主键），月初余额，本月充值(*)，本月实际消费，月末余额
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
        if (defined $AcctFeeInfo{$recs[0]}){
            #print "存在重复的记录，需要进行累加!acct_id=[$acctBook{$recs[0]}[0]]\n";
            #$AcctFeeInfo{$recs[0]}[1] += $recs[2];
            $AcctFeeInfo{$recs[0]} = &addItem4Hash('AcctFeeInfo', $recs[0], 1, $recs[2]);
        }else{
            $AcctFeeInfo{$recs[0]} = "0|$recs[2]|0|0";
            #print "加载用户记录,subs_id = [$recs[0]]\n";
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
    }
    print "共加载数据：[$line_num]条\n";
    
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#加载acct_item_billing_xxx到内存
#加载acct_id（主键），月初余额，本月充值，本月实际消费(*)，月末余额
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
        if (defined $AcctFeeInfo{$recs[0]}){
            #print "存在重复的记录!ACCT_ID=[$acctItemBilling{$recs[0]}[0]]\n";
            #$AcctFeeInfo{$recs[0]}[2] += $recs[2];
            $AcctFeeInfo{$recs[0]} = &addItem4Hash('AcctFeeInfo', $recs[0], 2, $recs[2]);
        }else{
            $AcctFeeInfo{$recs[0]} = "0|0|$recs[2]|0";
            #print "加载用户记录,subs_id = [$recs[0]]\n";
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
    }
    print "共加载数据：[$line_num]条\n";
    
    warn "Data fetching terminated early by error: $DBI::errstr\n"
      if $DBI::err;
}

#加载出帐前bal信息到内存
#加载：acct_id（主键），月初余额(*)，本月充值，本月实际消费，月末余额
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
        if (defined $AcctFeeInfo{$fvRecs[1]}){
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            #$AcctFeeInfo{$fvRecs[1]}[0] += $fvCharge;
            $AcctFeeInfo{$fvRecs[1]} = &addItem4Hash('AcctFeeInfo', $fvRecs[1], 0, $fvCharge);
        }else{
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            $AcctFeeInfo{$fvRecs[1]} = "$fvCharge|0|0|0";
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
        undef $fvRecsStr;
        undef @fvRecs;
    }
    
    close BALINFOFILE;
    
    print "共加载数据：[$line_num]条\n";
    return $line_num;
}

#加载出帐后bal信息到内存
#加载：acct_id（主键），月初余额，本月充值，本月实际消费(*)，月末余额
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
        if (defined $AcctFeeInfo{$fvRecs[1]}){
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            #$AcctFeeInfo{$fvRecs[1]}[3] += $fvCharge;
            $AcctFeeInfo{$fvRecs[1]} = &addItem4Hash('AcctFeeInfo', $fvRecs[1], 3, $fvCharge);
        }else{
            my $fvCharge = $fvRecs[3] + $fvRecs[5];
            $AcctFeeInfo{$fvRecs[1]} = "0|0|0|$fvCharge";
        }
        
        print "已经加载数据：[$line_num]条\n" if ($line_num % 10000 == 0);
    }
    
    close BALINFOFILE;
    
    print "共加载数据：[$line_num]条\n";
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
    
    #连接数据库
    $dbh    = DBI->connect( "dbi:Oracle:$dbname", $user, $passwd )
      or die "Can't connect to Oracle database: $DBI::errstr\n";
    
    #将数据保存到DBM
    if ($procType_userInfo == 1){
        unlink "$workPath/userInfo_dbm.dir" or warn "无需DBM文件[userInfo_dbm.dir]。\n";
        unlink "$workPath/userInfo_dbm.pag" or warn "无需DBM文件[userInfo_dbm.pag]。$!\n";
        
        dbmopen(%userInfo, "$workPath/userInfo_dbm", 0644) || die "Cannot open DBM userInfo_dbm: $!";
    }
    if ($procType_acctFeeInfo == 1){
        unlink "$workPath/AcctFeeInfo_dbm.dir" or warn "无需DBM文件[AcctFeeInfo_dbm.dir]。\n";
        unlink "$workPath/AcctFeeInfo_dbm.pag" or warn "无需DBM文件[AcctFeeInfo_dbm.pag]。\n";
        
        dbmopen(%AcctFeeInfo, "$workPath/AcctFeeInfo_dbm", 0644) || die "Cannot open DBM AcctFeeInfo_dbm: $!";
    }
      
    $DefResType = &getDefResType();
      
    &getUserInfo();
    
    print "初始化完成，开始运行！\n";
}

#=================================================
sub unInit{
    #断开连接
    $dbh->disconnect or warn "Disconnection failed: $DBI::errstr\n";
    
    undef %userInfo;
    if ($procType_userInfo == 1){
        dbmclose(%userInfo);
        #删除工作目录下存放的DBM文件
        unlink "$workPath/userInfo_dbm.dir" or warn "删除DBM文件[userInfo_dbm.dir]错误：$!\n";
        unlink "$workPath/userInfo_dbm.pag" or warn "删除DBM文件[userInfo_dbm.pag]错误：$!\n";
    }
    
    undef %AcctFeeInfo;
    if ($procType_acctFeeInfo == 1){
        dbmclose(%AcctFeeInfo);
        #删除工作目录下存放的DBM文件
        unlink "$workPath/AcctFeeInfo_dbm.dir" or warn "删除DBM文件[AcctFeeInfo_dbm.dir]错误：$!\n";
        unlink "$workPath/AcctFeeInfo_dbm.pag" or warn "删除DBM文件[AcctFeeInfo_dbm.pag]错误：$!\n";
    }
}

#将月初余额，本月充值，本月实际消费，月末余额进行处理，归入一个结构内
#acct_id（主键），月初余额，本月充值，本月实际消费，月末余额
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

#根据加载到内存的数据匹配输出结果
#地市，号码，月初余额，本月充值，本月实际消费，月末余额
#=================================================
sub Run{
    my ($fvOutFileName) = @_;
    $fvOutFileName = &CreateOutFileName($fvOutFileName);
    print '输出文件名称:',$fvOutFileName,"\n";
    open OUTCDR, ">$fvOutFileName" or die "open OUTCDR file fail: $!\n";
    
    for my $fvSubs_id (keys %userInfo){
        my @fv_userInfo = split /\|/,$userInfo{$fvSubs_id};
        my @out_info;
        
        my $fvSubsAcctNum = $#fv_userInfo - 3;
        
        #地市
        push @out_info, $fv_userInfo[2];
        
        #号码
        push @out_info, $fv_userInfo[1];
        
        if (defined $AcctFeeInfo{$fv_userInfo[3]}){     #先赋值信用账本
            push @out_info, &getValue($AcctFeeInfo{$fv_userInfo[3]}, 0) && 0;
            push @out_info, &getValue($AcctFeeInfo{$fv_userInfo[3]}, 1) && 0;
            push @out_info, &getValue($AcctFeeInfo{$fv_userInfo[3]}, 2) && 0;
            push @out_info, &getValue($AcctFeeInfo{$fv_userInfo[3]}, 3) && 0;
            #开始累加本金账本
            if ($fvSubsAcctNum == 1){                   #当用户只有一个本金账本的时候
                $out_info[2] += &getValue($AcctFeeInfo{$fv_userInfo[4]}, 0);
                $out_info[3] += &getValue($AcctFeeInfo{$fv_userInfo[4]}, 1);
                $out_info[4] += &getValue($AcctFeeInfo{$fv_userInfo[4]}, 2);
                $out_info[5] += &getValue($AcctFeeInfo{$fv_userInfo[4]}, 3);
            }elsif($fvSubsAcctNum > 1){                 #当用户本金账本数大于1
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

#组合输出文件名
#=================================================
sub CreateOutFileName{
    return $_[0] . '.' . &getLocalTime();
}

#=================================================
sub main{
    if (defined $options{p}){
        print "开始倒出Bal表数据到：$options{p}\n";
        &expBalTableDate($options{p});
    }elsif(defined $options{b} && defined $options{n} && defined $options{o} && defined $options{z}){
        print "开始生成给BSS的数据!\n";
        
        $BalExpFile       = $options{p};
        $billing_cycle_id = $options{b};
        $Per_BalFile      = $options{n};
        $Aft_BalFile      = $options{o};
        
        &init();
        
        #处理月初余额，本月充值，本月实际消费，月末余额
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
