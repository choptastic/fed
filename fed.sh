#!/bin/bash


function find_fed() {
	if [ -e ".fed" ] ; then
		source .fed
		$editor $(find . -name "$1*" | grep -v "~$" | grep -v ".beam$" | grep -v ".jpg" | grep -v ".png" | grep -v ".jpeg" | grep -v ".gif")
	else
		if [ `pwd` == "/" ]; then
			echo Not in a fed project
		else
			cd ..
			find_fed $1
		fi
	fi
}

if [ $1 == "" ]; then
	echo "Usage: fed filename"
else
	find_fed $1
fi
