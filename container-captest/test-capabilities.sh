#!/bin/bash

cd /opt/captest/tests/

declare -a allowed
declare -a denied

for TEST in $(ls -1 * | sort)
do
	if ./${TEST} &>/dev/null
	then
		allowed+=("${TEST}")
	else
		denied+=("${TEST}")
	fi
done

# print results inside a subshell so that they all can be formatted together
(
	for t in ${allowed[*]} ; do echo "${t} allowed" ; done
	echo
	for t in ${denied[*]} ; do echo "${t} denied" ; done
) | column -t --table-empty-lines
echo

# if running in OpenShift, show the pod's SCC (for troubleshooting capabilities(7))
if [[ -d /downward_api ]]
then
	pod_scc="$(cat /downward_api/pod_annotations | grep '^openshift.io/scc=' | awk -F= '{print $2}' | tr -d '"')"
	pod_namespace="$(cat /downward_api/pod_namespace)"
	pod_name="$(cat /downward_api/pod_name)"
	command_get_serviceaccountname="oc -n ${pod_namespace} get pod/${pod_name} -o jsonpath='{.spec.serviceAccountName}{\"\\n\"}'"

	(
		echo "OpenShift securityContextConstraints: ${pod_scc}"
		echo "OpenShift serviceAccountName command: ${command_get_serviceaccountname}"
	) | column -t -s: -o:
	echo
fi

echo "sleeping for one hour from $(date "+%F %T %Z") , then exiting..."
sleep 1h
