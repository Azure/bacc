#!/usr/bin/env bash
set -e

poolid=$1
timeout=${2:-5}
index=${3:-0}

# wait for resize to complete; this will take a while; let's wait for
# 5 minutes tops
((i=timeout*2))
while [ "$i" -ne 0 ]; do
    ((i=i-1))
    status=$(az batch node list --pool-id $poolid --query "[$index].state" -o tsv)
    if [ "$status" == "idle" ]; then
        break
    fi
    sleep 30
done
echo "$status"
