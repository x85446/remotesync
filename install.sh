#!/usr/bin/env bash

NORM="$(tput sgr0)"
BOLD="$(tput bold)"
REV="$(tput smso)"
UND="$(tput smul)"
BLACK="$(tput setaf 0)"
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
MAGENTA="$(tput setaf 90)"
MAGENTA1="$(tput setaf 91)"
MAGENTA2="$(tput setaf 92)"
MAGENTA3="$(tput setaf 93)"
CYAN="$(tput setaf 6)"
WHITE="$(tput setaf 7)"
ORANGE="$(tput setaf 172)"
ERROR="${REV}Error:${NORM}"
SSHNULLS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=10"
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
	local bad="$4"
	if [[ "$f" = "" ]]; then
		f="${s}"
	fi
	if [[ $ec -eq 0 ]]; then
		clihelp::success "$2"
	else
		if [[ $bad = "" || $bad = "failure" ]]; then
			clihelp::failure "$3"
		else
			clihelp::warn "$3"
		fi
		return 1
	fi
}

clihelp::break(){
	echo -e ""
}


clihelp::section(){
	echo -en "-----------------------------------------------------\n${CYAN}$1${NORM}\n\n"

}

clihelp::whichOS(){
	if [ "$(uname)" == "Darwin" ]; then
		echo "mac"        
	elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
		# Determine OS platform
		UNAME=$(uname | tr "[:upper:]" "[:lower:]")
		# If Linux, try to determine specific distribution
		if [ "$UNAME" == "linux" ]; then
	    	# If available, use LSB to identify distribution
	    	hash lsb_release
	    	if [[ $? -eq 0 ]]; then
	    		lsb_release -is
	    		return
	    	else
	    		if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
	    			export DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
	    			echo "$DISTRO"
	    			return
	    		# Otherwise, use release info file
	    	else
	    		export DISTRO=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1)
	    		echo "$DISTRO"
	    		return
	    	fi
	    fi
			# For everything else (or if above failed), just use generic identifier
			[ "$DISTRO" == "" ] && export DISTRO=$UNAME
			echo "$UNAME"
			unset UNAME
			return
		fi
	elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
		echo "win32"
	elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
		echo "win64"
	fi
}


_hashcheck(){
	program="$1" >> /dev/null 2>&1
	hash "$program"
	return $?
}

_alertInstaller(){
	cd /tmp
	curl -L https://github.com/vjeantet/alerter/releases/download/002/alerter_v002_darwin_amd64.zip -o alerter.zip
	unzip alerter
	sudo cp alerter /usr/local/bin/alerter
	return $ec
}

_brew(){
	program="$1"
	brew install "$program"
	return $?
}

_apt(){
	program="$1"
	apt -y install "$program"
	return $?
}

packageManager(){
	checker="$1"
	program="$2"
	packageManager="$3"
	iprog="$4"
	$checker $program
	if [[ $? -ne 0 ]]; then
		clihelp::warn "$program missing...insalling"
		pushd . >> /dev/null
		$packageManager "$iprog"
		popd >> /dev/null
		$checker "$program"
		if [[ $? -ne 0 ]]; then
			clihelp::error "$program failed to install.  Aborting"
			overallec=1
			return
		fi
	fi
	clihelp::success "$program is installed."
}


prereqs(){
	declare -gi overallec=0;
	if [ "$(uname)" == "Darwin" ]; then
		packageManager _hashcheck alerter _alertpackageManager
		packageManager _hashcheck fswatch _brew
		packageManager _hashcheck rsync _brew
		packageManager _hashcheck ggrep _brew
		packageManager _hashcheck realpath _brew

	elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
		packageManager _hashcheck fswatch _apt
	fi
	desired_rsync=3.1.2;
	rsync_version=$(rsync --version | head -n1 | cut -d " " -f4)
	if  [[ "$(printf '%s\n' "$desired_rsync" "$rsync_version" | sort -V | head -n1)" = "$desired_rsync" ]]; then
		clihelp::success "rsync version is $rsync_version."
	else
		clihelp::failure "rsync version is $rsync_version.  Expecting >$desired_rsync"
		overallec=1;
	fi
	if [[ $overallec -ne 0 ]]; then
		clihelp::failure "prerequisites not met"
		echo "Errors must be fixed to continue"
	else
		clihelp::success "all prerequisites passed"
		clihelp::break
	fi
}

install(){
	if [[ ! -e ~/.syncconf ]]; then
		cp configExample ~/.syncconf

	else
		echo "~/.synconf file already exists, updates to your config need to be manual."
	fi
	echo "copying remotesync.sh, remotesync-stdout.sh, remotesync-stderr.sh to /usr/local/bin"
	echo "[33mEnter your sudo password:[0m"
	sudo cp remotesync.sh /usr/local/bin/
	sudo cp remotesync-stderr.sh /usr/local/bin/
	sudo cp remotesync-stdout.sh /usr/local/bin/
		#cp remotesync-start.sh /usr/local/bin/
		if [ "$(uname)" == "Darwin" ]; then
			echo "installing a .plist file to /Libary/LaunchDaemons/"
			sudo cp com.remotesync.plist /Library/LaunchDaemons/
			launchctl unload -w /Library/LaunchDaemons/com.remotesync.plist
			#launchctl load -w /Library/LaunchDaemons/com.remotesync.plist
		elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
			echo "need to create a unit file"
		fi
	}
	clihelp::section "Prerequisites"
	prereqs
	clihelp::section "Install"
	install