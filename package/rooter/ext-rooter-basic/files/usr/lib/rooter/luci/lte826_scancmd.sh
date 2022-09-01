#!/bin/sh

ROOTER=/usr/lib/rooter

log() {
	logger -t "Quectel Scancell" "$@"
}

fibdecode() {
	j=$1
	tdec=$2
	mod=$3
	length=${#j}
	jx=$j
	length=${#jx}

	str=""
	i=$((length-1))
	while [ $i -ge 0 ]
	do
		dgt="0x"${jx:$i:1}
		DecNum=`printf "%d" $dgt`
		Binary=
		Number=$DecNum
		while [ $DecNum -ne 0 ]
		do
			Bit=$(expr $DecNum % 2)
			Binary=$Bit$Binary
			DecNum=$(expr $DecNum / 2)
		done
		if [ -z $Binary ]; then
			Binary="0000"
		fi
		len=${#Binary}
		while [ $len -lt 4 ]
		do
			Binary="0"$Binary
			len=${#Binary}
		done
		revstr=""
		length=${#Binary}
		ii=$((length-1))
		while [ $ii -ge 0 ]
		do
			revstr=$revstr${Binary:$ii:1}
			ii=$((ii-1))
		done
		str=$str$revstr
		i=$((i-1))
	done
	len=${#str}
	ii=0
	lst=""
	sep=","
	hun=101
	if [ $mod = "1" ]; then
		sep=":"
		hun=1
	fi
	while [ $ii -lt $len ]
	do
		bnd=${str:$ii:1}
		if [ $bnd -eq 1 ]; then
			if [ $tdec -eq 1 ]; then
				jj=$((ii+hun))
			else
				if [ $ii -lt 9 ]; then
					jj=$((ii+501))
				else
					jj=$((ii+5001))
				fi
			fi
			if [ -z $lst ]; then
				lst=$jj
			else
				lst=$lst$sep$jj
			fi
		fi
		ii=$((ii+1))
	done
}

CURRMODEM=$(uci get modem.general.miscnum)
COMMPORT="/dev/ttyUSB"$(uci get modem.modem$CURRMODEM.commport)
uVid=$(uci get modem.modem$CURRMODEM.uVid)
uPid=$(uci get modem.modem$CURRMODEM.uPid)
model=$(uci get modem.modem$CURRMODEM.model)
ACTIVE=$(uci get modem.pinginfo$CURRMODEM.alive)
uci set modem.pinginfo$CURRMODEM.alive='0'
uci commit modem
L1=$(uci get modem.modem$CURRMODEM.L1)
length=${#L1}
L1="${L1:2:length-2}"
L1=$(echo $L1 | sed 's/^0*//')
L2=$(uci get modem.modem$CURRMODEM.L2)
L1X=$(uci get modem.modem$CURRMODEM.L1X)
if [ -z $L1X ]; then
	L1X="0"
fi

case $uVid in
	"2c7c" )
		M2='AT+QENG="neighbourcell"'
		M5=""
		M6=""
		case $uPid in
			"0125" ) # EC25-A
				EC25=$(echo $model | grep "EC25-AF")
				if [ ! -z $EC25 ]; then
					MX='400000000000003818'
				else
					MX='81a'
				fi
				M4='AT+QCFG="band",0,'$MX',0'
			;;
			"0306" )
				M1='AT+GMR'
				OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M1")
				EP06E=$(echo $OX | grep "EP06E")
				if [ ! -z "$EP06E" ]; then # EP06E
				  # M3='1a080800d5'
					M3='1a1880800d5'
				else # EP06-A
					M3="2000001003300185A"
				fi
				M4='AT+QCFG="band",0,'$M3',0'
				M6='AT+QENG="servingcell"'
				M7='AT+QCFG="nwscanmode",0'
			;;
			"030b" ) # EM060
				M3="420000A7E23B0E38DF"
				M4='AT+QCFG="band",0,'$M3',0'
			;;
			"0512" ) # EM12-G
				M3="2000001E0BB1F39DF"
				M4='AT+QCFG="band",0,'$M3',0'
			;;
			"0620" ) # EM20-G
				EM20=$(echo $model | grep "EM20")
				if [ ! -z $EM20 ]; then # EM20
					M3="20000A7E03B0F38DF"
					M4='AT+QCFG="band",0,'$M3',0'
					if [ -e /etc/qfake ]; then
						mask="42000087E2BB0F38DF"
						fibdecode $mask 1 1
						M4F='AT+QNWPREFCFG="lte_band",'$lst
						#mask5='7042000081A0090808D7'
						#fibdecode $mask5 1 1
						#M5F='AT+QNWPREFCFG="nsa_nr5g_band",'$lst
						log "Fake RM500 $M4F"
						#log "Fake Scan to All $M5F"
					fi
					
				else # EM160
					mask="20000A7E0BB0F38DF"
					fibdecode $mask 1 1
					M4='AT+QNWPREFCFG="lte_band",'$lst
				fi
			;;
			"0800" )

			;;
			* )
				M3="AT"
				M4='AT+QCFG="band",0,'$M3',0'
			;;
		esac
		
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M4")
		log "$OX"
		if [ ! -z $M5 ]; then
			OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M5")
			log "$OX"
		fi
		sleep 5
	;;
	"1199" )
		M2='AT!LTEINFO?'
		case $uPid in

			"68c0"|"9041"|"901f" ) # MC7354 EM/MC7355
				M3="101101A"
				M3X="0"
				M4='AT!BAND=11,"Test",0,'$M3,$M3X
			;;
			"9070"|"9071"|"9078"|"9079"|"907a"|"907b" ) # EM/MC7455
				M3="100030818DF"
				M3X="0"
				M4='AT!BAND=11,"Test",0,'$M3,$M3X
				if [ -e /etc/fake ]; then
					M4='AT!BAND=11,"Test",0,A300BA0E38DF,2,0,0,0'
				fi
			;;
			"9090"|"9091"|"90b1" ) # EM7565
				EM7565=$(echo "$model" | grep "7565")
				if [ ! -z $EM7565 ]; then
					M3="A300BA0E38DF"
					M3X="2"
					M4='AT!BAND=11,"Test",0,'$M3","$M3X",0,0,0"
				else
					EM7511=$(echo "$model" | grep "7511")
					if [ ! -z $EM7511 ]; then # EM7511
						M3="A300BA0E38DF"
						M3X="2"
						M4='AT!BAND=11,"Test",0,'$M3","$M3X",0,0,0"
					else
						M3="87000300385A"
						M3X="42"
						M4='AT!BAND=11,"Test",0,'$M3","$M3X",0,0,0"
					fi
				fi

			;;
			* )
				M3="AT"
			;;
		esac
		log "Set full : $M4"
		if [ -e /etc/fake ]; then
			M4='AT!BAND=11,"Test",0,'$M3,$M3X
		fi
		M1='AT!ENTERCND="A710"'
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M1")
		log "$OX"
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M4")
		log "$OX"
		M4='AT!BAND=00;!BAND=11'
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M4")
		log "$OX"
		ATCMDD='AT!ENTERCND="AWRONG"'
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	;;
	"8087"|"2cb7" )
		rm -f /tmp/scan
		echo "Cell Scanner Start ..." > /tmp/scan
		echo " " >> /tmp/scan
		if [ -e /tmp/scan$CURRMODEM ]; then
			SCX=$(cat /tmp/scan$CURRMODEM)
			echo "$SCX" >> /tmp/scan
		else
			echo "No Neighbouring cells were found" >> /tmp/scan
		fi
		echo " " >> /tmp/scan
		echo "Done" >> /tmp/scan
		exit 0
	;;
	* )
		rm -f /tmp/scanx
		echo "Scan for Neighbouring cells not supported" >> /tmp/scan
		uci set modem.pinginfo$CURRMODEM.alive=$ALIVE
		uci commit modem
		exit 0
	;;
esac

# run AT command
export TIMEOUT="10"

# Configure to Scan all cell - fix issue cannot scan after locking cell
if [ ! -z "$M7" ]; then
	OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M7")
	log "$OX"
	ERR=$(echo "$OX" | grep "ERROR")
	if [ ! -z "$ERR" ]; then
		log "$ERR"
		ERR=""
	fi
fi

# Scan serving cell 
if [ ! -z "$M6" ]; then
	OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M6")
	log "$OX"
	ERR=$(echo "$OX" | grep "ERROR")
	if [ ! -z "$ERR" ]; then
		log "$ERR"
		ERR=""
	else
		echo "$OX" > /tmp/quectelScanx
	fi
fi

# Scan neighbour cell 
OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M2")
ERR=$(echo "$OX" | grep "ERROR")
if [ ! -z "$ERR" ]; then
	OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M2")
fi
if [ ! -z "$ERR" ]; then
	OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M2")
fi
log "$OX"
echo "$OX" >> /tmp/quectelScanx
rm -f /tmp/quectelScan
flg=0

#data print to UI
TYPE="-"
OPERATOR="-"
COUNTRY="-"
PROTOCOL="-"
SCHEME="-"
MCC="-"
MNC="-"
CID="-"
PCID="-"
EARFCN="-"
FREQ_BAND_IND="-"
UL_BW="-"
DL_BW="-"
TAC="-"
RSRP="-"
RSRQ="-"
RSSI="-"
SINR="-"
SRXLEV="-"
CELL_RSP="-"
SNIS="-"
SIS="-"
TXL="-"
TXH="-"

# parse data
while IFS= read -r line
do
	case $uVid in
	"2c7c" )
		qm=$(echo $line" " | grep "+QENG:" | grep "LTE" | tr -d '"' | tr " " ",")
		if [ "$qm" ]; then
			TYPECELL=$(echo $qm | cut -d, -f2)
			if [ "$TYPECELL" = "servingcell" ]; then
				# serving cell
				TYPE="MC"
				# STATE=$(echo $qm | cut -d, -f3)
				PROTOCOL=$(echo $qm | cut -d, -f4)
				SCHEME=$(echo $qm | cut -d, -f5)
				MCC=$(echo $qm | cut -d, -f6)
				MNC=$(echo $qm | cut -d, -f7)
				CID=$(echo $qm | cut -d, -f8)
				PCID=$(echo $qm | cut -d, -f9)
				EARFCN=$(echo $qm | cut -d, -f10)
				FREQ_BAND_IND=$(echo $qm | cut -d, -f11)
				UL_BW=$(echo $qm | cut -d, -f12)
				DL_BW=$(echo $qm | cut -d, -f13)
				TAC=$(echo $qm | cut -d, -f14)
				RSRP=$(echo $qm | cut -d, -f15)
				RSRQ=$(echo $qm | cut -d, -f16)
				RSSI=$(echo $qm | cut -d, -f17)
				SINR=$(echo $qm | cut -d, -f18)
				SRXLEV=$(echo $qm | cut -d, -f19)
			else 
				# neighbour cell
				TYPE=$(echo $qm | cut -d, -f3)
				PROTOCOL=$(echo $qm | cut -d, -f4)
				EARFCN=$(echo $qm | cut -d, -f5)
				PCID=$(echo $qm | cut -d, -f6)
				RSRQ=$(echo $qm | cut -d, -f7)
				RSRP=$(echo $qm | cut -d, -f8)
				RSSI=$(echo $qm | cut -d, -f9)
				SINR=$(echo $qm | cut -d, -f10)
				SRXLEV=$(echo $qm | cut -d, -f11)  
				CELL_RSP=$(echo $qm | cut -d, -f12)
				# re-init unvalid data
				FREQ_BAND_IND="-"
				UL_BW="-"
				DL_BW="-"
				TAC="-"
				# Parse specific data for intra and iner
				if [ "$TYPE" = "inter" ]; then
					TXL=$(echo $qm | cut -d, -f13)
					TXH=$(echo $qm | cut -d, -f14)
				else
					SNIS=$(echo $qm | cut -d, -f13)
					TSL=$(echo $qm | cut -d, -f14)
					SIS=$(echo $qm | cut -d, -f15)
				fi
			fi
			# update data to file
			echo "$TYPE $OPERATOR $COUNTRY $PROTOCOL $SCHEME $MCC $MNC $CID $PCID $EARFCN $FREQ_BAND_IND $UL_BW $DL_BW $TAC $RSRP $RSRQ $RSSI $SINR $SRXLEV $CELL_RSP $SNIS $SIS $TXL $TXH" >> /tmp/quectelScan
			# update flag
			flg=1
		fi
	;;
	"1199" )
		qm=$(echo $line" " | grep "Serving:" | tr -d '"' | tr " " ",")
		if [ "$qm" ]; then
			read -r line
			qm=$(echo $line" " | tr -d '"' | tr " " ",")
			BND=$(echo $qm | cut -d, -f1)
			PCI=$(echo $qm | cut -d, -f10)
			BAND=$(/usr/bin/chan2band.sh $BND)
			RSSI=$(echo $qm | cut -d, -f13)
			echo "Band : $BAND    Signal : $RSSI (dBm) EARFCN : $BND  PCI : $PCI (current)" >> /tmp/quectelScan
			flg=1
		else
			qm=$(echo $line" " | grep "InterFreq:" | tr -d '"' | tr " " ",")
			log "$line"
			if [ "$qm" ]; then
				while [ 1 = 1 ]
				do
					read -r line
					log "$line"
					qm=""
					qm=$(echo $line" " | grep ":" | tr -d '"' | tr " " ",")
					if [ "$qm" ]; then
						break
					fi
					qm=$(echo $line" " | grep "OK" | tr -d '"' | tr " " ",")
					if [ "$qm" ]; then
						break
					fi
					qm=$(echo $line" " | tr -d '"' | tr " " ",")
					if [ "$qm" = "," ]; then
						break
					fi
					BND=$(echo $qm | cut -d, -f1)
					PCI=$(echo $qm | cut -d, -f10)
					BAND=$(/usr/bin/chan2band.sh $BND)
					RSSI=$(echo $qm | cut -d, -f8)
					echo "Band : $BAND    Signal : $RSSI (dBm) EARFCN : $BND  PCI : $PCI" >> /tmp/quectelScan
					flg=1
				done
				break
			fi
		fi
	;;
	* )
	
	;;
	esac
done < /tmp/quectelScanx

rm -f /tmp/quectelScanx
if [ $flg -eq 0 ]; then
	echo "No Neighbouring cells were found" >> /tmp/quectelScan
fi

case $uVid in
	"2c7c" )
		if [ $uPid != "0800" ]; then
			if [ $uPid = 0620 -o $uPid = "0800" -o $uPid = "030b" ]; then
				EM20=$(echo $model | grep "EM20")
				if [ ! -z $EM20 ]; then # EM20
					M2='AT+QCFG="band",0,'$L1',0'
					if [ -e /etc/fake ]; then
						fibdecode $L1 1 1
						M2F='AT+QNWPREFCFG="lte_band",'$lst
						log "Fake EM160 Band Set "$M2F
					fi
				else
					fibdecode $L1 1 1
					M2='AT+QNWPREFCFG="lte_band",'$lst
				fi
			else
				M4='AT+QCFG="band",0,'$L1',0'
			fi
			OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M4")
			log "$OX"
		fi
	;;
	"1199" )
		M1='AT!ENTERCND="A710"'
		case $uPid in

			"68c0"|"9041"|"901f" ) # MC7354 EM/MC7355
				M4='AT!BAND=11,"Test",0,'$L1X,0
			;;
			"9070"|"9071"|"9078"|"9079"|"907a"|"907b" ) # EM/MC7455
				M4='AT!BAND=11,"Test",0,'$L1X,0
				if [ -e /etc/fake ]; then
					M4='AT!BAND=11,"Test",0,'$L1X','$L2',0,0,0'
				fi
			;;
			"9090"|"9091"|"90b1" )
				M4='AT!BAND=11,"Test",0,'$L1X','$L2',0,0,0'
			;;
		esac
		log "Set back : $M4"
		if [ -e /etc/fake ]; then
			M4='AT!BAND=11,"Test",0,00000100030818DF,0'
		fi
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M1")
		log "$OX"
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M4")
		log "$OX"
		M4='AT!BAND=00;!BAND=11'
		OX=$($ROOTER/gcom/gcom-locked "$COMMPORT" "run-at.gcom" "$CURRMODEM" "$M4")
		log "$OX"
		ATCMDD='AT!ENTERCND="AWRONG"'
		OX=$($ROOTER/gcom/gcom-locked "/dev/ttyUSB$CPORT" "run-at.gcom" "$CURRMODEM" "$ATCMDD")
	;;
esac
uci set modem.pinginfo$CURRMODEM.alive=$ACTIVE
uci commit modem

log "Finished Scan"
