#!/bin/bash

if [[ "$(id -u)" != "0" ]]
then
	echo "$0: uid is \"$(id -u)\", not \"0\"; aborting"
	exit 1
fi

TESTS_DIR=/opt/captest/tests

for CAPABILITY in $(filecap -d)
do
	test_file="${TESTS_DIR}/${CAPABILITY}"
	cap_spec="$(echo ${CAPABILITY} | sed -e 's/^/cap_/g' -e 's/$/=+eip/g')"

	\cp -a -f /bin/true "${test_file}"
	setcap "${cap_spec}" "${test_file}"
done
