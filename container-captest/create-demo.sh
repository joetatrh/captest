#!/bin/bash

if [[ "$(id -u)" != "0" ]]
then
	echo "$0: uid is \"$(id -u)\", not \"0\"; aborting"
	exit 1
fi

# the leading backslash means "ignore any alias for this command"
\cp -a /usr/bin/ncat /opt/captest/bin/nc.with.net_bind_service

setcap cap_net_bind_service=+eip /opt/captest/bin/nc.with.net_bind_service
