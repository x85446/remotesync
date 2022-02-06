#!/usr/bin/env bash

NORM="\u001b[0m"
BOLD="\u001b[1m"
REV="\u001b[7m"
UND="\u001b[4m"
BLACK="\u001b[30m"
RED="\u001b[31m"
GREEN="\u001b[32m"
YELLOW="\u001b[33m"
BLUE="\u001b[34m"
MAGENTA="\u001b[35m"
MAGENTA1="\u001b[35m"
MAGENTA2="\u001b[35m"
MAGENTA3="\u001b[35m"
CYAN="\u001b[36m"
WHITE="\u001b[37m"
ORANGE="$YELLOW"
ERROR="${REV}Error:${NORM}"
SSHNULLS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=4"


found(){
	string="$1"
	reg="$2"

	if [ "$(uname)" == "Darwin" ]; then
		matched=$(echo "$string" | ggrep -P "$reg")
		ec=$?
	else
		matched=$(echo "$string" | grep -P "$reg")
		ec=$?
	fi
	echo "$matched"
	return "$ec"
}

clihelp::success(){
	#echo  "[   OK   ]\t$1"
	echo -e "[${GREEN}   OK   ${NORM}]\t$1"
}
clihelp::failure(){
	echo -e "[${RED} FAILED ${NORM}]\t$1"
}
clihelp::blank(){
	echo -e "\t\t$1"
}
clihelp::warn(){
	echo -e "[${YELLOW}  WARN  ${NORM}]\t$1"
}

clihelp::exitCodeStatus(){
	local ec="$1"
	local s="$2"
	local f="$3"
	if [[ "$f" = "" ]]; then
		f="${s}"
	fi
	if [[ $ec -eq 0 ]]; then
		clihelp::success "$2"
	else
		clihelp::failure "$3"
		return 1
	fi
}

clihelp::break(){
	echo -e ""
}


clihelp::section(){
	echo -en "-----------------------------------------------------\n${CYAN}$1${NORM}\n\n"

}

configValidation(){
	local fullhalt=0;
	LOCAL_LINE_len=${#LOCAL_LINE[@]}
	for (( i = 0; i < $LOCAL_LINE_len; i++ )); do
		ll=${LOCAL_LINE[$i]}
		rl=${REMOTE_LINE[$i]}
		rs=${REMOTE_SERVER[$i]}
		rstype="remote"
		rp=${REMOTE_PATH[$i]}
		if [[ "$rs" == *":"* ]]; then
			rstype=remote
		else
			rstype=local
		fi
		echo "$ll $rl"
		if [[ ! -e "$ll"  ]]; then
			if [[ $ON_BAD_LOCAL_ENTRY = "SKIP" ]]; then
				clihelp::warn "Local path $ll does not exist.  Mapping dropped."
				LINE_STATUS[$i]="skipped"
			elif [[ $ON_BAD_LOCAL_ENTRY = "HALT" ]]; then
				fullhalt=1;
				clihelp::failure "Local path $ll does not exist.  Will halt."
			fi
		else
			clihelp::success "local path exists"
			if [[ -d "$ll" ]]; then
				ltype="dir"
				rp_dir="$rp"
				LOCAL_DIR[$i]="$ll"
			else
				ltype="file"
				ll_dir=$(dirname "$ll")
				LOCAL_DIR[$i]="$ll_dir"
				rp_dir=$(dirname "$rp")
				rp_file=$(basename -- "$rp")
				rp_ext="${rp_file##*.}"
				rp_filehead="${rp_file%.*}"
			fi
		fi
		LINE_TYPE[$i]="$ltype"
		clihelp::success "line detected as a $ltype"
		canssh=0;

		if [[ $rstype = "remote" ]]; then
			ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=2 $rs "ls" >> /dev/null 2>&1
			if [[ $? -ne 0  ]]; then
				if [[ $ON_BAD_REMOTE_HOST_ENTRY = "SKIP" ]]; then
					clihelp::warn "Remote host $rs unaccessable. Mapping dropped."
					LINE_STATUS[$i]="skipped"
				elif [[ $ON_BAD_REMOTE_HOST_ENTRY = "HALT" ]]; then
					clihelp::failure "Remote host $rs does not exist. Will halt."
					fullhalt=1;
				fi
			else
				canssh=1;	
				clihelp::success "remote host $rs is accessable"
			fi
		elif [[ rstype = "local" ]]; then
			if [[ ! -e "$rl"  ]]; then
				if [[ $ON_BAD_LOCAL_ENTRY = "SKIP" ]]; then
					clihelp::warn "Local-remote path $rl does not exist.  Mapping dropped."
					LINE_STATUS[$i]="skipped"
				elif [[ $ON_BAD_LOCAL_ENTRY = "HALT" ]]; then
					fullhalt=1;
					clihelp::failure "Local-remote path $rl does not exist.  Will halt."
				fi
			else
				clihelp::success "Local-remote path exists"
				if [[ -d "$rl" ]]; then
					ltype="dir"
					rp_dir="$rl"
				else
					ltype="file"
					ll_dir=$(dirname "$rl")
					LOCAL_DIR[$i]="$ll_dir"
					rp_dir=$(dirname "$rp")
					rp_file=$(basename -- "$rp")
					rp_ext="${rp_file##*.}"
					rp_filehead="${rp_file%.*}"
				fi
			fi
		fi
		if [[ $canssh -eq 1 ]]; then
			ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=2 $rs "ls $rp_dir" >> /dev/null 2>&1
			if [[ $? -ne 0  ]]; then
				if [[ $ON_BAD_REMOTE_PATH_ENTRY = "SKIP" ]]; then
					clihelp::warn "Remote path $rp unaccessable. Mapping dropped."
					LINE_STATUS[$i]="skipped"
				elif [[ $ON_BAD_REMOTE_PATH_ENTRY = "HALT" ]]; then
					clihelp::failure "Remote path $rp does not exist. Will halt."
					fullhalt=1;
				elif [[ $ON_BAD_REMOTE_PATH_ENTRY = "CREATE" ]]; then
					ssh $SSHNULLS $rs "mkdir -p $rp_dir" >> /dev/null 2>&1
					clihelp::warn "Remote path $rp created."
				fi
			else
				clihelp::success "remote path exists"
			fi
		fi
	done
	if [[ $fullhalt -ne 0 ]]; then
		clihelp::failure "Blocking errrors, exiting"
		exit
	fi
}

configProcessing(){
	config="$1"
	LOCAL_LINE_len=${#LOCAL_LINE[@]}
	for (( i = 0; i < $LOCAL_LINE_len; i++ )); do
		#suffing new arrays to improve speed
		if [[ ${LINE_STATUS[$i]} != "skipped" ]]; then
			USE_LOCAL_DIR+=("${LOCAL_DIR[$i]}")
			USE_LOCAL_LINE+=("${LOCAL_LINE[$i]}");
			USE_REMOTE_LINE+=("${REMOTE_LINE[$i]}");
			USE_REMOTE_SERVER+=("${REMOTE_SERVER[$i]}");
			USE_LINE_MODE+=("${LINE_MODE[$i]}");
			USE_LINE_EXCLUDE+=("${LINE_EXCLUDE[$i]}")
			USE_LINE_TYPE+=("${LINE_TYPE[$i]}")
		fi
	done
	#make watches unique entries
	WATCHES=($(echo "${USE_LOCAL_DIR[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
	watchline=""
	echo "Monitoring the following directories"
	for value in "${WATCHES[@]}"; do
		watchline="$watchline $value"
		echo "  - $value"
	done
	watchline="$watchline $config"
	echo "  - $config"
}

presync(){
	for value in "${USE_LOCAL_LINE[@]}"; do
		syncit $value
	done
}

_debugconf(){
	#echo "$1"
	:
}

loadconf(){
	readarray -t confRay <<< "$(cat $1)"
	unset LOCAL_LINE
	declare -ag LOCAL_LINE
	unset LOCAL_DIR
	declare -ag LOCAL_DIR
	unset REMOTE_LINE
	declare -ag REMOTE_LINE
	unset REMOTE_SERVER
	declare -ag REMOTE_SERVER
	unset REMOTE_PATH
	declare -ag REMOTE_PATH
	unset LINE_STATUS
	declare -ag LINE_STATUS
	unset LINE_EXCLUDE
	declare -ag LINE_EXCLUDE
	unset LINE_MODE
	declare -ag LINE_MODE
	unset WATCHES
	declare -ag WATCHES
	unset watchline
	declare -g watchline
	unset USE_LOCAL_LINE
	declare -ag USE_LOCAL_LINE
	unset USE_LOCAL_DIR
	declare -ag USE_LOCAL_DIR
	unset USE_REMOTE_LINE
	declare -ag USE_REMOTE_LINE
	unset USE_REMOTE_SERVER
	declare -ag USE_REMOTE_SERVER
	unset USE_LINE_TYPE
	declare -ag USE_LINE_TYPE
	unset USE_LINE_MODE
	declare -ag USE_LINE_MODE
	unset USE_LINE_EXCLUDE
	declare -ag USE_LINE_EXCLUDE

	confRay_len=${#confRay[@]}
	for (( i = 0; i < $confRay_len; i++ )); do
		confline=$(echo "${confRay[$i]}" | tr -s " ")
		_debugconf " the conf: $confline"
		re="^\s*$"
		matched=$(found "$confline" "$re")
		if [[ $? -ne 0 ]]; then
			#not a blank
			re="\s*#.*"
			matched=$(found "$confline" "$re")
			if [[ $? -ne 0 ]]; then
				#not a comment
				re2='\s*[\w_]+[=]{1}["]*[\w\s\/]+["]*'
				matched=$(found "$confline" "$re2")
				if [[ $? -eq 0 ]]; then
					_debugconf "var"
					eval "$confline"
				else
					#a map line
					re3=" "^\s*\$""
					matched=$(found "$confline" "$re3")
					if [[ $? -ne 0 ]]; then
						IFS=" " read -r -a lineRay <<< "$confline"
						#ll=("$(echo $confline| awk -F ' ' '{print $1}')")
						ll="${lineRay[0]}"
						ll="${ll//"~"/${HOME}}"
						l2=$(realpath $ll  2>/dev/null)
						if [[ $? -eq 0 ]]; then
							ll=$l2
						fi
						#rl=("$(echo $confline| awk -F ' ' '{print $2}')")
						rl="${lineRay[1]}"
						#lm=("$(echo $confline| awk -F ' ' '{print $3}')")
						lm="${lineRay[2]}"
						ed="${lineRay[3]}"
						ed="${ed//"~"/$HOME}"
						if [[ $lm = "" || $ed = "" ]]; then
							clihelp::failure "Line $(( $i + 1 )) $config: malformed map directive. Ensure your setting the RTYPE and EPATH"
							clihelp::blank "${CYAN}$confline${NORM}"
							exit
						fi
						if [[ ! "$lm" =~ ^(BIMIRROR|MIRROR|UPDATE)$ ]]; then
							clihelp::failure "Line $(( $i + 1 )) $config: malformed remote directive (RDIREC). Valid entries are: BIMIRROR MIRROR UPDATE"
							clihelp::blank "${CYAN}$confline${NORM}"
							exit
						fi
						if [[ ! -e "$ed" ]]; then
							if [[ ! "$ed" =~ ^(GIT|NONE)$ ]]; then
								clihelp::failure "Line $(( $i + 1 )) $config: malformed exclude directive (EDIREC). Valid entries are: GIT NONE <filepath>"
								clihelp::blank "${CYAN}$confline${NORM}"
								exit
							fi
						fi
						rs=$(echo $rl| awk -F ':' '{print $1}');
						rp=$(echo $rl| awk -F ':' '{print $2}');
						LOCAL_LINE+=("$ll");
						REMOTE_LINE+=("$rl");
						REMOTE_SERVER+=("$rs");
						REMOTE_PATH+=("$rp");
						LINE_STATUS+=("ok");
						LINE_MODE+=("$lm")
						LINE_EXCLUDE+=("$ed")
						LINE_TYPE+=("unk")
					fi
				fi
			else 
				_debugconf "comment"
			fi
		else
			_debugconf "blank"
		fi
	done
	clihelp::success "configuration loaded"
}

_dosync(){
	method="$1"
	localP="$2"
	remoteP="$3"
	mode="$4"
	exclude="$5"
	if [[ $VERBOSITY -lt 5 ]]; then
		options="-aHAXx"
	else
		options="-aHAXxv"
	fi
	if [[ $method = "scp" ]]; then
		# echo "scp \"$localP\" \"$remoteP\""
		scp $SSHNULLS "$localP" "$remoteP" 2>/dev/null
	elif [[ $method = "rsync" ]]; then
		if [[ $mode = "MIRROR" ]]; then
			echo "here"
			echo "rsync \"$options\" --numeric-ids --delete \"$exclude\" -ae \"ssh $SSHNULLS -q -T -o Compression=no -x\" \"$localP/\" \"$remoteP\" "
			rsync "$options" --numeric-ids --delete "$exclude" -ae "ssh $SSHNULLS -q -T -o Compression=no -x" "$localP/" "$remoteP"
		elif [[ $mode = "BIMIRROR" ]]; then
			rsync "$options" -u --numeric-ids "$exclude" -ae "ssh $SSHNULLS -q -T -o Compression=no -x" "$localP/" "$remoteP"
			#echo rsync "$options" --numeric-ids "$exclude" -ae "\"ssh $SSHNULLS -q -T -o Compression=no -x\"" "$remoteP/" "$localP"
			rsync "$options" -u --numeric-ids "$exclude" -ae "ssh $SSHNULLS" "$remoteP/" "$localP"
		elif [[ $mode = "UPDATE" ]]; then
			rsync "$options" --numeric-ids "$exclude" -ae "ssh $SSHNULLS -q -T -o Compression=no -x" "$localP/" "$remoteP"
		fi
	fi
}

syncit(){
	fileChanged="$1"
	file_monitor_ray_len=${#file_monitor_ray[@]}
	USE_LOCAL_LINE_len=${#USE_LOCAL_LINE[@]}
	for (( i = 0; i < "$USE_LOCAL_LINE_len"; i++ )); do
		localPath="${USE_LOCAL_LINE[$i]}"
		if [[ "$fileChanged" == *"$localPath"* ]]; then
			type="${USE_LINE_TYPE[$i]}"
			remotePath=${USE_REMOTE_LINE[$i]}
			remoteServer=${USE_REMOTE_SERVER[$i]}
			DIRNAME=$(dirname "$localPath")
			FILENAME=$(basename -- "$localPath")
			EXTENSION="${FILENAME##*.}"
			FILEHEAD="${FILENAME%.*}"

			noticeSound "$BEFORESOUND"
			#echo "mybeforebanner $BEFOREBANNER $AFTERBANNER"
			#sh -c "notificationBannerlaunch \"Changed: $FILENAME\" \"$localPath ->\" \"$remotePath\" \"$BEFOREBANNER\""
			notificationBannerlaunch "terminalnotifier" "Changed: $FILENAME" "$localPath ->" "$remotePath" "$BEFOREBANNER" &

			#echo "notificationBannerlaunch \"Changed: $FILENAME\" \"$localPath ->\" \"$remotePath\" \"$BEFOREBANNER\" " &
			
			#notificationBannerlaunch "xxxREADY: $remotePath" "" "" "$AFTERBANNER" &
			echo -e "${ORANGE}Sync:${NORM}\t$localPath ${ORANGE}-->${NORM} $remotePath"
			if [[ $type = "dir" ]]; then
				mode="${USE_LINE_MODE[$i]}"
				if [[ ${USE_LINE_EXCLUDE[$i]} = "NONE" ]]; then
					exclude=""
				elif [[ ${USE_LINE_EXCLUDE[$i]} = "GIT" ]]; then
					exclude="--exclude=.git/"
				else
					exclude="--exclude-from=${USE_LINE_EXCLUDE[$i]}"
				fi
				_dosync "rsync" "$localPath" "$remotePath" "$mode" "$exclude"
			else
				_dosync "scp" "$localPath" "$remotePath"
			fi
			noticeSound "$AFTERSOUND"
			notificationBannerlaunch "terminalnotifier" "READY: $remoteServer" "$FILENAME" "$remotePath" "$AFTERBANNER" &
			# /usr/bin/env bash -c "/Users/travis/workspace/scripts/remotesync/noticebanner.sh \"READY: $remotePath\" \"\" \"\" \"$AFTERBANNER\"" &
			# forkpid=$!
			# echo "noticebanner after ($forkpid)" >> /tmp/remotesyncpids
		fi
	done

}

noticeSound(){
	sound="$1"
	#echo "sound play $1"
	if [ "$(uname)" == "Darwin" ]; then
		if [[ -e "$sound" ]]; then
			afplay "$sound" &
		fi
	elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
		OSX=0;
	fi
}

notificationBannerlaunchlaunch(){
	/usr/bin/env bash -c "/Users/travis/workspace/scripts/remotesync/noticebanner.sh \"$1\" \"$2\" \"$3\" \"$4\"" &
	forkpid=$!
	echo "forked noticebanner ($BASHPID-->$forkpid)" >> /tmp/remotesyncpids
}

notificationBannerlaunch(){
	method="$1"
	changed="$2"
	from="$3"
	to="$4"
	timer="$5"
	#echo "banner: $changed $from $to $timer"
	echo "NB ($$): starting $@" >> /tmp/remotesyncpids
	if [[ $timer -gt 0 ]]; then
		if [ "$(uname)" == "Darwin" ]; then
			if [[ $method = "alerter" ]]; then
				#out=$(calling="$$";me="$BASHPID";echo "NBchild: $changed ($calling->$me)">>/tmp/remotesyncpids;alerter -message "$to" -title "$calling->$me" -subtitle "$from" -actions stdout,stderr  -showLabel xxx -timeout $timer)
				out=$(alerter -message "$to" -title "$changed" -subtitle "$from" -actions stdout,stderr  -showLabel xxx -timeout $timer)
			elif [[ $method = "terminalnotifier" ]]; then

				#out=$(calling="$$";me="$BASHPID";echo "NBchild: $changed ($calling->$me)">>/tmp/remotesyncpids;terminal-notifier -message "$to" -title "$calling->$me" -subtitle "$from")
				out=$(terminal-notifier -message "$to" -title "$changed" -subtitle "$from")
			fi
			echo "NB ($$): out returns: '$out'" >> /tmp/remotesyncpids
			if [[ $out = "stderr" ]]; then
				open -a $BANNER_OSXLOGVIEWPROGRAM "/usr/local/bin/remotesync-stderr.sh"
			elif [[ $out = "stdout" ]]; then
				open -a $BANNER_OSXLOGVIEWPROGRAM "/usr/local/bin/remotesync-stdout.sh"
			fi
		elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
			OSX=0;
			base64_decode_flag="-d"
		fi
	fi
	echo "NB ($$): exiting " >> /tmp/remotesyncpids 
}

osxNativeBanner(){
	changed="$1"
	from="$2"
	to="$3"
	timer="$4"
}

main(){
	config="$1"
	loadconfig=1;
	declare -gi count
	count=0;
	while :
	do
		if [[ $loadconfig -eq 1 ]]; then
			clihelp::section "Load Configuration"
			loadconf "$config"
			clihelp::section "Config Validation"
			configValidation
			clihelp::section "Config Processing"
			configProcessing "$config"
			clihelp::section "Presync new Maps"
			presync
			clihelp::section "Start Watching"
			loadconfig=0;
		fi
		change=$(fswatch -r -L -1 ${watchline} || echo "hardstop") || "ech huo"
		echo -e "${ORANGE}Changed:${NORM}$change"
		if [[ $change = "$config" ]]; then
			loadconfig=1;
		else
			syncit "$change"
		fi
	done
}

config=${1:-"${HOME}/.syncconf"}
echo "config: $config"
if [[ ! -e $config ]]; then
	echo -en "Useage: \t$0 <configuration_file>\n\t\t$0 ~/.syncconf\n"
else
	mainpid="$$"
	echo "started up with the pids $mainpid and $BASHPID" > /tmp/remotesyncpids
	main "$config"
fi