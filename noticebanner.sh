noticeBanner(){
	changed="$1"
	from="$2"
	to="$3"
	timer="$4"
	# echo "changed: $changed"
	# echo "from: $from"
	# echo "to: $to"
	# echo "timer: $timer"
	#echo "banner: $changed $from $to $timer"
	if [[ $timer -gt 0 ]]; then
		if [ "$(uname)" == "Darwin" ]; then
			out=$(calling="$$";me="$BASHPID";echo "NBchild: $changed ($calling->$me)">>/tmp/remotesyncpids;alerter -message "$to" -title "$calling->$me" -subtitle "$from" -actions stdout,stderr  -showLabel xxx -timeout $timer)
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
}
echo "NB ($$): starting $@" >> /tmp/remotesyncpids
BANNER_OSXLOGVIEWPROGRAM=terminal
noticeBanner "$@"
echo "NB ($$): exiting " >> /tmp/remotesyncpids 