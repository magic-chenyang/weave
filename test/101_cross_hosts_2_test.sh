#! /bin/bash

. "$(dirname "$0")/config.sh"

C1=10.2.1.4
C2=10.2.1.7
UNIVERSE=10.2.0.0/16
SUBNET_1=10.2.2.0/24
SUBNET_2=10.2.3.0/24
IMAGE=weaveworks/network-tester

wait_for_connections() {
    for i in $(seq 1 45); do
        if run_on $HOST1 "curl -sS http://127.0.0.1:6784/status | grep \"$SUCCESS\"" ; then
            return
        fi
        echo "Waiting for connections"
        sleep 1
    done
    echo "Timed out waiting for connections to establish" >&2
    exit 1
}

wait_for_network_tester_status() {
    for i in $(seq 1 45); do
        status=$($SSH $HOST1 curl -sS http://127.0.0.1:8080/status)
        if [ -n "$status" -a "$status" != "running" ] ; then
            return
        fi
        echo "Waiting for network tester status"
        sleep 1
    done
    echo "Timed out waiting for network tester status" >&2
    exit 1
}

start_suite "Network test over cross-host weave network (with and without IPAM)"

weave_on $HOST1 launch --ipalloc-range $UNIVERSE --ipalloc-default-subnet $SUBNET_1
weave_on $HOST2 launch --ipalloc-range $UNIVERSE --ipalloc-default-subnet $SUBNET_1 $HOST1

docker_on $HOST1 run --name=c1 -dt -p 8080:8080 $IMAGE -peers=2 $C1 $C2
weave_on  $HOST1 attach    $C1/24 c1
docker_on $HOST2 run --name=c2 -dt -p 8080:8080 $IMAGE -peers=2 $C1 $C2
weave_on  $HOST2 attach ip:$C2/24 c2

wait_for_network_tester_status
assert "echo $status" "pass"

end_suite
