#!/bin/bash

#function
ntoa(){
    awk '{c=256;print int($0/c^3)"."int($0%c^3/c^2)"."int($0%c^3%c^2/c)"."$0%c^3%c^2%c}' <<<$1
}

aton(){
    awk '{c=256;split($0,ip,".");print ip[4]+ip[3]*c+ip[2]*c^2+ip[1]*c^3}' <<<$1
}

dtom(){
    local i=$((~0))
    ((i<<=(32-$1)))
    echo $i
}

atom(){
    local mask=$(aton $1)
    local i=0
    local n=0
    for((i=31;i>=0;i--)); do
        if [[ $((mask&(1<<$i))) -gt 0 ]]; then
            ((n++))
        fi
    done
    echo $(dtom $n)
}

usage(){
    echo "Usage: -a "
    echo " -m "
    echo " -h README"
    exit
}

#main
[ $# -lt 2 ] && { usage;exit;}

while getopts a:m:h OPTION; do
    case $OPTION in
        a)
            ip=$OPTARG
            ;;
        m)
            netmask=$OPTARG
            ;;
        h)
            usage
            ;;
        esac
done

[[ -z $ip || -z $netmask ]] && usage

ipn=$(aton $ip)

if [[ ${#netmask} -le 2 ]]; then
    mask=$(dtom $netmask)
else
    mask=$(atom $netmask)
fi

subnet=$((ipn&mask))
broadcast=$((~(subnet^mask)))

echo "subnet: $(ntoa $subnet)"
echo "broadcast: $(ntoa $broadcast)"