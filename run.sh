#!/usr/bin/env bash

cd "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"

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
