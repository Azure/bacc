#!/usr/bin/env bash

# script to await a pool downsizing to 0
set -e

poolid=$1
timeout=${2:-5}

((i=timeout*2))
while [ "$i" -ne 0 ]; do
    ((i=i-1))
    count=$(az batch node list --pool-id $poolid --query "length([])")
    if [ "$count" -eq 0 ]; then
        break
    fi
    sleep 30
done
