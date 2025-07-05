#!/usr/bin/env bash

cd "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")" || return 1

source .env

SCALE="${SCALE:-1}"

if [ -z "$TOKEN" ]; then
    echo "Empty TOKEN"
    exit 1
fi

if [ -z "$ORG_NAME" ]; then
    echo "Empty ORG_NAME"
    exit 1
fi

docker compose up --scale github-runner="$SCALE" -d

br_name=$(docker network ls --filter name=self-hosted-runners_default --format 'br-{{.ID}}')

nft delete table inet filter
tc qdisc del dev "$br_name" root

nft add table inet filter
nft add chain inet filter forward '{ type filter hook forward priority 0; }'
nft add set inet filter cn_ip '{ type ipv4_addr; flags interval; }'
nft add element inet filter cn_ip "{ $(curl -4sSkL https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/cn.cidr | grep -E '^[0-9./]+$' | paste -sd, -) }"

nft add rule inet filter forward ip saddr != @cn_ip counter meta mark set 0x1

tc qdisc add dev "$br_name" root handle 1: htb default 20 r2q 1000
tc class add dev "$br_name" parent 1: classid 1:10 htb rate 120mbit ceil 120mbit
tc class add dev "$br_name" parent 1: classid 1:20 htb rate 1gbit ceil 1gbit
tc qdisc replace dev "$br_name" parent 1:10 fq_codel
tc qdisc replace dev "$br_name" parent 1:20 fq_codel
tc filter add dev "$br_name" protocol ip parent 1:0 prio 1 handle 1 fw flowid 1:10
