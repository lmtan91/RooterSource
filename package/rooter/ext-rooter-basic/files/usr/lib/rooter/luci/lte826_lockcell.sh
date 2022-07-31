#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "Quectel Lockcell" "$@"
}

if [ $# -lt 1 ];then
    log 'Do not receive any cell info to log'
    exit 1
fi

log "PCID: $1 -- EARFCN: $2"
# Get PCID and EARFCN
PCID=$1
EARFCN=$2

# Set up info to run AT command
CURRMODEM=$(uci get modem.general.miscnum)
COMMPORT="/dev/ttyUSB"$(uci get modem.modem$CURRMODEM.commport)
uVid=$(uci get modem.modem$CURRMODEM.uVid)
uPid=$(uci get modem.modem$CURRMODEM.uPid)
model=$(uci get modem.modem$CURRMODEM.model)
ACTIVE=$(uci get modem.pinginfo$CURRMODEM.alive)
uci set modem.pinginfo$CURRMODEM.alive='0'
uci commit modem

flg=0
case $uVid in
    "2c7c" )
        case $uPid in
            "0306" )
                M1='AT+QCFG="nwscanmode",3'
                OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M1")
                ERR=$(echo "$OX" | grep "ERROR")
                if [ ! -z $ERR ];then
                    log "$ERR"
                    ERR=""
                else
                    flg=1
                fi
            ;;
            * )
                log "uPid: $uPid"
            ;;
        esac
    ;;
    * )
        log "uVid: $uVid"
    ;;
esac
if [ $flg -eq 0 ]; then
    uci set modem.pinginfo$CURRMODEM.alive=$ACTIVE
    uci commit modem
    exit 1
fi

sleep 5

# Start Lock to cellid
log "Start lock nw to cell"
export TIMEOUT="10"

M2='AT+QNWLOCK="common/lte",1,'$EARFCN',0'
OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M2")
log "$OX"
ERR=$(echo "$OX" | grep "ERROR")
if [ ! -z $ERR ];then
    log "$ERR"
    ERR=""
fi

M3='AT+QNWLOCK="common/lte",2,'$EARFCN','$PCID''
OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M3")
log "$OX"
ERR=$(echo "$OX" | grep "ERROR")
if [ ! -z $ERR ];then
    log "$ERR"
    ERR=""
fi

uci set modem.pinginfo$CURRMODEM.alive=$ACTIVE
uci commit modem
log "Finished lock nw to cell"