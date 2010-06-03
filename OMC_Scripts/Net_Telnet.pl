#/usr/bin/perl -w

use lib './';

use strict;
use Net::Telnet;
use Switch;

my $hostip = '10.45.4.129';
my $username = 'zxin10';
my $passwd = 'zxin10';

my $t = Net::Telnet->new(  Timeout => 5,
                            Prompt => '/[\$%#>]\s*$/');

$t->open($hostip);
$t->login($username, $passwd);
$t->cmd("cd /home/zxin10/impsys/imp/.");

my @lines = $t->cmd("./imptool -c");
my $line_num = 0;
foreach my $line (@lines){
    my ($v_pno,$v_peerip,$v_module,$v_ossice,$v_status,$v_sendc,$v_recvc,$v_breadc,$v_linitc);
    
    if ($line_num >= 3 && $line_num != $#lines){
        #print $line;
        
        #解析每一列的数据
        my $math_num = 0;
        foreach my $en ($line =~ m/([\d.]+)\s*/g){
            $math_num++;
            switch ($math_num){
                case 1 {$v_pno      = $en}
                case 2 {$v_peerip   = $en}
                case 3 {$v_module   = $en}
                case 4 {$v_ossice   = $en}
                case 5 {$v_status   = $en}
                case 6 {$v_sendc    = $en}
                case 7 {$v_recvc    = $en}
                case 8 {$v_breadc   = $en}
                case 9 {$v_linitc   = $en}
            }
        }
    
        #根据每一列的数据信息进行判断
        print "【$v_peerip】主机状态【$v_status】，发送消息【$v_sendc】，收到消息【$v_recvc】。\n";
    }

    $line_num++;
}

$t->close;