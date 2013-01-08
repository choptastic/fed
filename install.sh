#!/bin/sh

if [ "$(whoami)" = "root" ]; then
	echo "Installing fed."
	cp fed.sh /usr/bin/fed
	chmod 755 /usr/bin/fed

	echo "fed installed as /usr/bin/fed"
else
	echo "Error: This must be run as root"
fi
