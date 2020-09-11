#!/bin/bash

set -Eeuox pipefail
cd "$(dirname "$0")"

docker stop zeronet

docker system prune -f
