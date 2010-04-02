部署前提:
select * from omc_kpi where kpi_id = 'schedule'
select * from omc_kpi_type where kpi_type = '03'
看一下以上两个语句是否在OMC中有数据,如果没有请现场部署OMC的人员添加,具体添加可以咨询周忠克


1,CommonENV.sh是通用的变量和函数调用,还有链接数据库的用户名和密码,请现场修改
2,其他每个进程都放入crontable,可以参考头部的注释
3,PorcessDailyRecurrEvent.sh--每天日租处理脚本
4,PorcessFirstRecurrEvent.sh--每天首日租处理脚本
5,RefreshRuleCache.sh--每日进程刷新脚本,请在CommonENV.sh中刷新需要更新的脚本
6,将单停,双停的job运行时间都调整到凌晨3点
