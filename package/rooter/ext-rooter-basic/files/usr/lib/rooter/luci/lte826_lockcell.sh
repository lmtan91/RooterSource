#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "Quectel Lockcell" "$@"
}

if [$# -lt 1];then
    log 'Do not receive any cell info to log'
    exit 1
fi

log "PCID: $1"
log "EARFCN: $2"

exit 0