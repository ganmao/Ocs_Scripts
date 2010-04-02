#!/usr/bin/perl -w

use strict;
use lib '/ztesoft/ocs/scripts/perllib/lib/site_perl/5.8.2/aix-thread-multi';
use DBI;
use Getopt::Std;
use Time::Local;

#数据库连接配置
#=====================================================
my $vDBName     = "test_cc";    #数据库实例名
my $vDBUserName = "cc";         #数据库用户名
my $vDBPasswd   = "smart";      #数据库密码
my $vDBHead     = "";
my $vSTH        = "";

#读取参数
#=====================================================
my %options;
getopts('hp:t:o:', \%options);
$options{h} && &usage;

#用来存放bal信息和用户信息数据结构(数组的散列)
#=====================================================
#以acct_id为主键,只加载余额类型为1的数据,
#当出现多条数据时,金额相加,生效时间取最早时间,失效时间取最晚时间,bal_id,BAL_CODE等为两个id的组合"bal_id1-bal_id2"
#PRIORITY取最小值
my %vBalInfo  = ();
#以acc_nbr为主键,当出现多条记录时,取创建时间最晚的记录,创建时间相同则取第一个选择到的数据
my %vUserInfo = ();

#输出信息数据结构(数组的数组)
my @vOutUserInfo = ();

#获取当时系统时间
#=====================================================
sub vGetLocalTime{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $yday = $yday + 1900;
    return "$year$mon$yday$hour$min$sec";
}

#使用说明
#=====================================================
sub usage{
    print<<ECHO;
ExpUserInformation.pl [-p BalBackPath] [-t ProcTime] [-o OutFilePath] [-h]

ECHO
exit -1;
}

#比较两个时间大小
#将日期都转化为秒进行比较
#=====================================================
sub diffDays{
    #传入两个时间的格式为:YYYYMMDDHH24MISS
    my ($t1, $t2) = @_;
    
    my $t1_YYYY = substr($t1,0,4)-1;
    my $t1_MM   = substr($t1,4,2)-1;
    my $t1_DD   = substr($t1,6,2);
    my $t1_HH24 = substr($t1,8,2);
    my $t1_MI   = substr($t1,10,2);
    my $t1_SS   = substr($t1,12,2);
    
    my $t2_YYYY = substr($t2,0,4)-1;
    my $t2_MM   = substr($t2,4,2)-1;
    my $t2_DD   = substr($t2,6,2);
    my $t2_HH24 = substr($t2,8,2);
    my $t2_MI   = substr($t2,10,2);
    my $t2_SS   = substr($t2,12,2);
    
    my $fvTimeStamp1 = timelocal($t1_SS,$t1_MI,$t1_HH24,$t1_DD,$t1_MM,$t1_YYYY);
    my $fvTimeStamp2 = timelocal($t2_SS,$t2_MI,$t2_HH24,$t2_DD,$t2_MM,$t2_YYYY);
    
    return $fvTimeStamp1 - $fvTimeStamp2;
}

#读取Bal表导出信息到内存
#=====================================================
sub fLoadBalInfo{
    my($fvBalPath, $fvBalTime) = @_;
    my $fvRecordNum = 0;
    
    open BALINFOFILE, $fvBalPath.'/bal.dat.'.$fvBalTime or die "open bal.dat file fail: $!\n";
    
    foreach my $fvRecsStr (<BALINFOFILE>) {
        #print "$fvRecsStr\n";
        chomp $fvRecsStr;
        my @fvRecs = split /\|/,$fvRecsStr;
        next if $fvRecs[2] != 1;    #只加载余额类型为 1 的数据
        
        #当存在多条记录
        if (exists $vBalInfo{$fvRecs[1]}){
            $vBalInfo{$fvRecs[1]}[0]  = $vBalInfo{$fvRecs[1]}[0] . '-' . $fvRecs[0];        #BAL_ID
            #$vBalInfo{$fvRecs[1]}[1]  = $vBalInfo{$fvRecs[1]}[1] . '-' . $fvRecs[1];       #ACCT_ID
            #$vBalInfo{$fvRecs[1]}[2]  = $vBalInfo{$fvRecs[1]}[2] . '-' . $fvRecs[2];       #ACCT_RES_ID
            $vBalInfo{$fvRecs[1]}[3]  = $vBalInfo{$fvRecs[1]}[3] + $fvRecs[3];      #GROSS_BAL
            $vBalInfo{$fvRecs[1]}[4]  = $vBalInfo{$fvRecs[1]}[4] + $fvRecs[4];      #RESERVE_BAL
            $vBalInfo{$fvRecs[1]}[5]  = $vBalInfo{$fvRecs[1]}[5] + $fvRecs[5];      #CONSUME_BAL
            $vBalInfo{$fvRecs[1]}[6]  = $vBalInfo{$fvRecs[1]}[6] + $fvRecs[6];      #RATING_BAL
            $vBalInfo{$fvRecs[1]}[7]  = $vBalInfo{$fvRecs[1]}[7] + $fvRecs[7];      #BILLING_BAL
            if (defined $vBalInfo{$fvRecs[1]}[8] && $vBalInfo{$fvRecs[1]}[8] ne '' && defined $fvRecs[8] && $fvRecs[8] ne ''){
                if (&diffDays($vBalInfo{$fvRecs[1]}[8],$fvRecs[8]) < 0){
                    $vBalInfo{$fvRecs[1]}[8]  = $fvRecs[8];        #EFF_DATE
                }
            }
            if (defined $vBalInfo{$fvRecs[1]}[9] && $vBalInfo{$fvRecs[1]}[9] ne '' && defined $fvRecs[9] && $fvRecs[9] ne ''){
                if (&diffDays($vBalInfo{$fvRecs[1]}[9],$fvRecs[9]) < 0){
                    $vBalInfo{$fvRecs[1]}[9]  = $fvRecs[9];        #EXP_DATE
                }
            }
            if (defined $vBalInfo{$fvRecs[1]}[10] && $vBalInfo{$fvRecs[1]}[10] ne '' && defined $fvRecs[10] && $fvRecs[10] ne ''){
                if (&diffDays($vBalInfo{$fvRecs[1]}[10],$fvRecs[10]) < 0){
                    $vBalInfo{$fvRecs[1]}[10]  = $fvRecs[10];        #UPDATE_DATE
                }
            }
            #$vBalInfo{$fvRecs[1]}[11] = $vBalInfo{$fvRecs[1]}[11] . '-' . $fvRecs[11];      #CEIL_LIMIT
            #$vBalInfo{$fvRecs[1]}[12] = $vBalInfo{$fvRecs[1]}[12] . '-' . $fvRecs[12];      #FLOOR_LIMIT
            #$vBalInfo{$fvRecs[1]}[13] = $vBalInfo{$fvRecs[1]}[13] . '-' . $fvRecs[13];      #DAILY_CEIL_LIMIT
            #$vBalInfo{$fvRecs[1]}[14] = $vBalInfo{$fvRecs[1]}[14] . '-' . $fvRecs[14];      #DAILY_FLOOR_LIMIT
            #$vBalInfo{$fvRecs[1]}[15] = $vBalInfo{$fvRecs[1]}[15] . '-' . $fvRecs[15];      #PRIORITY
            #$vBalInfo{$fvRecs[1]}[16] = $vBalInfo{$fvRecs[1]}[16] . '-' . $fvRecs[16];      #LAST_BAL
            #$vBalInfo{$fvRecs[1]}[17] = $vBalInfo{$fvRecs[1]}[17] . '-' . $fvRecs[17];      #LAST_RECHARGE
            if (defined $vBalInfo{$fvRecs[1]}[18]){
                $vBalInfo{$fvRecs[1]}[18] = $vBalInfo{$fvRecs[1]}[18] . '-' . $fvRecs[18];      #BAL_CODE
            }else{
                $vBalInfo{$fvRecs[1]}[18] = $fvRecs[18];
            }
        }else{
            $vBalInfo{$fvRecs[1]} = [@fvRecs];
            $fvRecordNum ++;
        }
    }
    
    close BALINFOFILE;
    
    print "共加载Bal信息记录[$fvRecordNum]条!\n";
    return $fvRecordNum;
}

#从数据库中读取用户信息到内存
#=====================================================
sub fLoadUserInfo{
    #获取用户信息SQL
    my $fvSql="
    SELECT s.acc_nbr, s.subs_id, s.subs_code, s.area_id, s.acct_id credit_acct_id,
           sa.acct_id base_acct_id, NVL (s.credit_limit, 0) credit_limit,
           s.price_plan_id,
           TO_CHAR (p.created_date, 'yyyymmddhh24miss') created_date,
           TO_CHAR (p.completed_date, 'yyyymmddhh24miss') completed_date,
           p.prod_state, p.block_reason
      FROM subs s, prod p, subs_acct sa
     WHERE s.subs_id = p.prod_id AND s.subs_id = sa.subs_id";

    my $fvRecordNum = 0;
       
    $vDBHead = DBI->connect( "dbi:Oracle:$vDBName", $vDBUserName, $vDBPasswd )
        or die "Can't connect to Oracle database: $DBI::errstr\n";
    
    #链接数据库
    $vSTH = $vDBHead->prepare($fvSql)
        or die "Can't prepare SQL statement: $DBI::errstr\n";
    
    $vSTH->execute or die "Can't execute SQL statement: $DBI::errstr\n";
    
    #读取记录数据
    while ( my @fvRecs = $vSTH->fetchrow_array ) {
        #print "@fvRecs\n";
        
        #当存在多条记录
        if (exists $vUserInfo{$fvRecs[0]}){
            #如果新记录创建时间比较晚
            if (&diffDays($vUserInfo{$fvRecs[0]}[8],$fvRecs[8]) < 0 ){
                $vUserInfo{$fvRecs[0]} = [@fvRecs];
                $fvRecordNum++;
            }
        #当没有多条记录时
        }else{
            $vUserInfo{$fvRecs[0]} = [@fvRecs];
            $fvRecordNum++;
        }
    }
    warn "Data fetching terminated early by error: $DBI::errstr\n"
    if $DBI::err;
    
    #断开连接
    $vDBHead->disconnect or warn "Disconnection failed: $DBI::errstr\n";
    
    print "共加载用户信息记录[$fvRecordNum]条!\n";
    return $fvRecordNum;
}

#初始化程序
#=====================================================
sub fInitialization{
    if (defined $options{p} && defined $options{t} &&defined $options{o}){
        print "传入bal文件路径:$options{p}\n";
        print "传入bal备份时间:$options{t}\n";
        print "输出话单文件路径:$options{o}\n";
        &fLoadBalInfo($options{p},$options{t});
    }else{
        &usage;
    }
    
    &fLoadUserInfo;
}

#退出程序
#=====================================================
sub fUnInit{
    %vBalInfo  = ();
    %vUserInfo = ();
}

#生成单挑的输出数据
#=====================================================
sub fCreateOutCdr{
    my ($key) = @_;
    my @cdr = ();
    
    push @cdr,'1';                      #Servicekey
    push @cdr,$vUserInfo{$key}[0]  || '';      #MSISDN
    push @cdr,$vUserInfo{$key}[10] || '';     #LifeState
    push @cdr,'3';                      #MissState
    push @cdr,$vUserInfo{$key}[6]  || '0';      #CreditLimit
    push @cdr,'3';                      #BlackState
    push @cdr,'0';                      #CurMonPkgType
    #AccountLeft
    
    $vBalInfo{$vUserInfo{$key}[4]}[3] = 0 if (!defined $vBalInfo{$vUserInfo{$key}[4]}[3]);
    $vBalInfo{$vUserInfo{$key}[4]}[5] = 0 if (!defined $vBalInfo{$vUserInfo{$key}[4]}[5]);
    $vBalInfo{$vUserInfo{$key}[5]}[3] = 0 if (!defined $vBalInfo{$vUserInfo{$key}[5]}[3]);
    $vBalInfo{$vUserInfo{$key}[5]}[5] = 0 if (!defined $vBalInfo{$vUserInfo{$key}[5]}[5]);
    
    #获取信用账本余额(不含RESERVE_BAL)+本金账本余额(不含RESERVE_BAL)
    push @cdr,$vBalInfo{$vUserInfo{$key}[4]}[3]
             +$vBalInfo{$vUserInfo{$key}[4]}[5]
             +$vBalInfo{$vUserInfo{$key}[5]}[3]
             +$vBalInfo{$vUserInfo{$key}[5]}[5] || '0';
             
    push @cdr,substr($vUserInfo{$key}[9],0,8) || '';                      #ServiceStart
    if (defined $vBalInfo{$vUserInfo{$key}[5]}[9]){
        push @cdr,substr($vBalInfo{$vUserInfo{$key}[5]}[9],0,8)  || '';    #CallServiceStop
    }else{
        push @cdr,'20370101';
    }
    push @cdr,'20370101';       #AccountStop
    push @cdr,'20370101';       #DeleteTime
    
    #第13~31字段,都直接赋值为0
    for (my $i=1;$i<=19;$i++){
        push @cdr,'0';
    }
    
    return @cdr;
}

#根据用户信息匹配余额信息,生成输出数据
#=====================================================
sub fProcUsersInfo{
    #遍历%vUserInfo
    for my $vUserInfo_key (keys %vUserInfo){
        push @vOutUserInfo, [&fCreateOutCdr($vUserInfo_key)];
    }
}

#组合输出文件名
#{Userinformation}+{YYYYMMDD}+{_}+{OCS}+{00}+{00}+{_}+{4位索引号}+{.unl}
#=====================================================
sub fCreateOutFileName{
    return 'Userinformation' . substr(&vGetLocalTime,0,8) . '_OCS0000_0001.unl';
}

#将内存中信息生成文件输出
#=====================================================
sub fOutPutCdr{
    my $fvOutFileName = &fCreateOutFileName;
    $fvOutFileName = $options{o} . '/' . &fCreateOutFileName;
    print '输出文件名称:',&fCreateOutFileName,"\n";
    open OUTCDR, ">$fvOutFileName" or die "open OUTCDR file fail: $!\n";
    
    for my $fvRow (@vOutUserInfo){
        print OUTCDR join '|',@$fvRow;
        print OUTCDR "\n";
    }
    
    close OUTCDR;
}

#main
#=====================================================
sub main{
    &fInitialization;
    
    &fProcUsersInfo;
    
    &fOutPutCdr;
    
    &fUnInit;
}

&main;
