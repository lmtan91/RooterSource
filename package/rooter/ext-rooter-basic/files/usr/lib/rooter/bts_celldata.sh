#!/bin/sh

ROOTER=/usr/lib/rooter

OX=$(qmicli -d /dev/cdc-wdm0 -p --nas-get-serving-system)
OX=$(echo $OX | tr 'a-z' 'A-Z')

TAC=$(echo $OX | grep -o "LTE TRACKING AREA CODE: \'[0-9]\{4,\}\'" | grep -o "[0-9]\{4,\}")
TAC_HEX=$(printf "%X" $TAC)
echo "Successfully got cell information"
echo "TAC: $TAC_HEX ($TAC)"

CID=$(echo $OX | grep -o "3GPP CELL ID: \'[0-9]\{0,9\}\'" | grep -o "[0-9]\{0,9\}")
CID=$(printf "%08X" $CID)
CID_HEX=${CID: -2}
CID_DEC=$(printf "%d" 0x$CID_HEX)
