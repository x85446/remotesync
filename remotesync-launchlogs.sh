#!/bin/bash
echo "hellooooooooooooooooo: $1"
if [[ "$1" = "stderr" ]]; then
	tail -n 10000 -f /tmp/remotesync.stderr
else 
	tail -n 10000 -f /tmp/remotesync.stdout
fi
