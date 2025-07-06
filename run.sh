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
nft add set inet filter local_ip '{ type ipv4_addr; flags interval; }'
nft add element inet filter cn_ip "{ $(curl -4sSkL https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/cn.cidr | grep -E '^[0-9./]+$' | paste -sd, -) }"
nft add element inet filter local_ip '{ 10.0.0.0/8 }'

nft add rule inet filter forward ip saddr != @cn_ip ip saddr != @local_ip counter meta mark set 0x1
nft add rule inet filter forward ip saddr @cn_ip counter meta mark set 0x2

tc qdisc add dev "$br_name" root handle 1: htb default 30
tc class add dev "$br_name" parent 1: classid 1:10 htb rate 100mbit ceil 100mbit quantum 10000
tc class add dev "$br_name" parent 1: classid 1:20 htb rate 800mbit ceil 800mbit quantum 100000
tc class add dev "$br_name" parent 1: classid 1:30 htb rate 100gbit ceil 100gbit quantum 10000000
tc qdisc replace dev "$br_name" parent 1:10 fq_codel target 20ms interval 200ms memory_limit 1024Mb
tc qdisc replace dev "$br_name" parent 1:20 fq_codel target 20ms interval 200ms memory_limit 1024Mb
tc qdisc replace dev "$br_name" parent 1:30 fq_codel target 20ms interval 200ms memory_limit 1024Mb
tc filter add dev "$br_name" protocol ip parent 1:0 prio 1 handle 1 fw flowid 1:10
tc filter add dev "$br_name" protocol ip parent 1:0 prio 2 handle 2 fw flowid 1:20
