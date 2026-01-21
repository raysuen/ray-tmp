#!/bin/bash
#by raysuen
#v1.0

# Function: Convert integer IP to dotted decimal IP
ntoa(){
    awk '{c=256;print int($0/(c**3))"."int(($0%(c**3))/(c**2))"."int(($0%(c**2))/c)"."$0%c}' <<<$1
}

# Function: Convert dotted decimal IP to integer
aton(){
    awk '{c=256;split($0,ip,".");print ip[4]+ip[3]*c+ip[2]*(c**2)+ip[1]*(c**3)}' <<<$1
}

# Function: Convert subnet mask (numeric form, e.g.,24) to integer mask
dtom(){
    local i=$((~0))
    ((i<<=(32-$1)))
    echo $i
}

# Function: Convert dotted decimal subnet mask to integer mask
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

# 【English Version Help Function】
usage(){
    cat << EOF
=============================================
CalcIP.sh - IPv4 Subnet/Broadcast Address Calculator
=============================================
Purpose: Calculate the subnet address and broadcast address for a given IPv4 address

Usage: ./CalcIP.sh [parameters]

Required Parameters:
  -a <IPv4 Address>   Specify the IPv4 address to calculate (dotted decimal format, e.g.,192.168.1.100)
  -m <Subnet Mask>    Specify the subnet mask, supporting two formats:
                      1. Numeric form (0-32): e.g.,24 (corresponding to 255.255.255.0)
                      2. Dotted decimal form: e.g.,255.255.255.128

Optional Parameter:
  -h                  Display this help information and exit

Examples:
  1. Calculate with numeric mask: ./CalcIP.sh -a 192.168.1.100 -m 24
  2. Calculate with dotted decimal mask: ./CalcIP.sh -a 192.168.2.50 -m 255.255.255.128
  3. View help: ./CalcIP.sh -h

Notes:
  - Only IPv4 addresses are supported (IPv6 is not compatible)
  - Numeric subnet mask must be in the range 0-32
  - Invalid IP/mask input will cause abnormal calculation results
=============================================
EOF
    exit 0
}

# Main Logic
[ $# -lt 2 ] && { usage; exit; }

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
        *)
            echo "Error: Invalid parameter!"
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
# Fix broadcast address calculation (handle integer overflow for cross-environment compatibility)
broadcast=$(( (subnet) | (~mask & 0xFFFFFFFF) ))

echo "subnet: $(ntoa $subnet)"
echo "broadcast: $(ntoa $broadcast)"