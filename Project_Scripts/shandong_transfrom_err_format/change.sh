#!/usr/bin/ksh

cdrType=$1

if [[ ${cdrType} = "in" ]]
then
    for file in `ls -1 in6_cdr100_*_20100529.r`
    do
        #echo ${file}
        echo "begin proc ${file} ..."
        awk -f in.awk ${file}
    done
elif [[ ${cdrType} = "sm" ]]
then
    for file in `ls -1 in6_cdr300_*_20100529.r`
    do
        #echo ${file}
        echo "begin proc ${file} ..."
        awk -f sm.awk ${file}
    done
elif [[ ${cdrType} = "ps" ]]
then
    for file in `ls -1 in6_cdr200_*_20100530.r`
    do
        #echo ${file}
        echo "begin proc ${file} ..."
        awk -f ps.awk ${file}
    done
elif [[ ${cdrType} = "vac" ]]
then
    for file in `ls -1 in6_cdr400_*_20100531.r`
    do
        #echo ${file}
        echo "begin proc ${file} ..."
        awk -f vac.awk ${file}
    done
fi
