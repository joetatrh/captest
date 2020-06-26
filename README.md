# captest - OpenShift capabilities(7) tester

## TL;DR

View the Linux capabilities granted to your pod by OpenShift:

```
$ oc create -f https://raw.githubusercontent.com/joetatrh/captest/master/job.captest.yml

$ oc logs job/captest
chown             allowed
dac_override      allowed
fowner            allowed
fsetid            allowed
net_bind_service  allowed
net_raw           allowed
setpcap           allowed
sys_chroot        allowed

audit_control     denied
audit_read        denied
audit_write       denied
block_suspend     denied
dac_read_search   denied
ipc_lock          denied
ipc_owner         denied
kill              denied
lease             denied
linux_immutable   denied
mac_admin         denied
mac_override      denied
mknod             denied
net_admin         denied
net_broadcast     denied
setfcap           denied
setgid            denied
setuid            denied
sys_admin         denied
sys_boot          denied
sys_module        denied
sys_nice          denied
sys_pacct         denied
sys_ptrace        denied
sys_rawio         denied
sys_resource      denied
sys_time          denied
sys_tty_config    denied
syslog            denied
wake_alarm        denied

OpenShift securityContextConstraints: restricted
OpenShift serviceAccountName command: oc -n captest get pod/captest-wtvm6 -o jsonpath='{.spec.serviceAccountName}{"\n"}'

sleeping for one hour from 2020-06-25 19:31:34 UTC , then exiting...
$ 

$ # view the OpenShift serviceAccount under which your pod runs
$ oc -n captest get pod/captest-wtvm6 -o jsonpath='{.spec.serviceAccountName}{"\n"}'
default
```

## About captest

The `captest` container helps you troubleshoot your `SecurityContextConstraints`.

It tells you which of the Linux `capabilities(7)` it was allowed to use inside your container.

`captest` *also* reports the OpenShift SCC under which the pod runs, which is _especially_ helpful when troubleshooting in OpenShift.

## About capabilities(7)

Linux uses the [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) facility to grant special privileges to process.

By declaring which capabilities they require, processes are allowed to do things that would normally be restricted to the `root` user-- like setting the clock (`sys_time`) or listening on a low-numbered privileged port (`net_bind_service`).

## Capabilities in OpenShift: SecurityContextConstraints

In OpenShift, [`SecurityContextConstraints`](https://docs.openshift.com/container-platform/4.4/authentication/managing-security-context-constraints.html) (SCCs) control which capabilities are denied (dropped) and allowed (added).

All containers inherit a [default set of capabilities](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities), and the specific SCC assigned to your pod at runtime adds or drops further capabilities from that set.

SCCs aren't assigned directly to pods; they're bound to `ServiceAccounts`.  A `ServiceAccount`, in turn, is selected to run a pod.

(If you run a pod that doesn't appear to have the capabilities you were expecting, you'll need to consider its `SecurityContextConstraint`, the `ServiceAccount` under which it runs, and the binding between the two.)

## Using the captest container

### Standalone

Build and run the `captest` container.  Really!  That's it.

```
$ cd container-captest
$ make
$ make run
```

### captest inside OpenShift

`captest` works just fine inside OpenShift.  But if you want to make it _useful_, you need to use OpenShift's [Downward API](https://docs.openshift.com/container-platform/4.4/nodes/containers/nodes-containers-downward-api.html).

(This is a fancy way of saying "create your pod definition such that the `.metadata.annotations` field appears as a file inside the pod".)

The Downward API is how `captest` knows the `SecurityContextConstraint` it was assigned at runtime.  (And when troubleshooting capabilities, finding the SCC assigned to your pod is the most important step.)

The `job.captest.yml` file creates a pod with the appropriate Downward API fields:

```
# job.captest.yml
---
apiVersion: batch/v1
kind: Job
metadata:
  name: captest
spec:
  template:
    metadata:
      labels:
        captest: test
      name: captest
    spec:
      containers:
      - name: captest
        image: quay.io/jteagno/captest
        volumeMounts:
        - name: pod-info
          mountPath: /downward_api
          readOnly: true
      volumes:
      - name: pod-info
        downwardAPI:
          defaultMode: 444
          items:
          - path: pod_annotations
            fieldRef:
              fieldPath: metadata.annotations
          - path: pod_namespace
            fieldRef:
              fieldPath: metadata.namespace
          - path: pod_name
            fieldRef:
              fieldPath: metadata.name
      restartPolicy: Never
```

# Deep dive

## Deep dive: `net_bind_service`

`captest` ships with a proof-of-concept test.

As a non-root user inside a container, you can see for yourself what happens when you try listening on a privileged port, an action that requires the `net_bind_service` capability.

## Testing with `net_bind_service` allowed

1. Create a new project
```
$ oc new-project captest1
```
2. Create a `captest` container
```
$ oc create -f https://raw.githubusercontent.com/joetatrh/captest/master/job.captest.yml
job.batch/captest created
```
3. Confirm that the container runs under the default SCC `restricted`, and that the container is allowed to bind to privileged ports (`net_bind_service`)
```
$ oc logs job/captest
...
net_bind_service  allowed
...
OpenShift securityContextConstraints: restricted
...
```
4. Look at the file `/opt/captest/bin/nc.with.net_bind_service` inside the `captest` container.\
This binary is a copy of `netcat` on which the `net_bind_service` capability has been requested.
```
$ oc exec -it job/captest -- /bin/bash
bash-5.0$ filecap /opt/captest/bin/nc.with.net_bind_service
set       file                 capabilities
effective /opt/captest/bin/nc.with.net_bind_service     net_bind_service
```
5. Enter the container and validate that you're not the `root` user.  Now run `nc.with.net_bind_service`, and tell it to listen on port 23.
```
bash-5.0$ whoami
1000590000

bash-5.0$ /opt/captest/bin/nc.with.net_bind_service -l 127.0.0.1 23 &
[1] 70

bash-5.0$ echo "i am sending to port 23" | nc 127.0.0.1 23
i am sending to port 23
[1]+  Done    /opt/captest/bin/nc.with.net_bind_service -l 127.0.0.1 23
```
6. Success!\
You weren't `root`, but you were still able to listen on a privileged port inside the container!

## Testing with `net_bind_service` dropped

1. Create a new `SecurityContextConstraint` `no-netbindsvc` based on the default SCC `restricted`, but dropping `NET_BIND_SERVICE`.\
Use `jq` to modify the `restricted` SCC's definition.
```
$ sudo dnf -y install jq

$ oc get scc/restricted -o json | jq '.metadata = {} | .metadata.name = "no-netbindsvc" | .metadata.annotations."kubernetes.io/description" = "A copy of the restricted SCC, but with NET_BIND_SERVICE dropped" | .requiredDropCapabilities += ["NET_BIND_SERVICE"]' | oc apply -f -
securitycontextconstraints.security.openshift.io/no-netbindsvc created
```
2. Validate the new `SecurityContextConstraint` `no-netbindsvc` for accuracy.
```
$ oc get scc/no-netbindsvc -o yaml
...
metadata:
  annotations:
    ...
    kubernetes.io/description: A copy of the restricted SCC, but with NET_BIND_SERVICE dropped
    ...
  name: no-netbindsvc
...
requiredDropCapabilities:
...
- NET_BIND_SERVICE
...
```
3. Create a new project
```
$ oc new-project captest2
```
4. Bind the `no-netbindsvc` SCC to the `default` `ServiceAccount` under which pods run.
```
$ oc adm policy add-scc-to-user no-netbindsvc -z default -n captest2
clusterrole.rbac.authorization.k8s.io/system:openshift:scc:no-netbindsvc added: "default"
```
5. Create a `captest` container
```
$ oc create -f https://raw.githubusercontent.com/joetatrh/captest/master/job.captest.yml
job.batch/captest created
```
6. Confirm that the container runs under the new SCC `no-netbindsvc`, and that the container is *not* allowed to bind to privileged ports (`net_bind_service`).
```
$ oc logs job/captest
...
net_bind_service  denied
...
OpenShift securityContextConstraints: no-netbindsvc
...
```
7. Enter the container and try to use `/opt/captest/bin/nc.with.net_bind_service` to listen on port 23.\
Success!  Even though you've created the same container as last time, non-`root` users are no longer allowed to bind to privileged ports.
```
$ oc exec -it job/captest -- /bin/bash
bash-5.0$ /opt/captest/bin/nc.with.net_bind_service -l 127.0.0.1 23
bash: /opt/captest/bin/nc.with.net_bind_service: Operation not permitted
```
