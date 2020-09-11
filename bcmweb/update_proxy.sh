#!/bin/bash
#rename to "provision_aws" sinc eit only needs to run once

set -Eeuox pipefail

source ./env

# pull zeronet image
ZERONET_IMAGE="$ZERONET_BASE_DOCKER_IMAGE"
if docker image list | grep -q "$ZERONET_IMAGE"; then
    docker image pull "$ZERONET_IMAGE"
fi

# pull nginx image
NGINX_IMAGE="nginx:latest"
if docker image list | grep -q "$NGINX_IMAGE"; then
    docker image pull "$NGINX_IMAGE"
fi

#zeronet docker
# if there's an existing running instance, let's kill it so we start from fresh.
ZERONET_CONTAINER_NAME="zeronet"
if docker ps | grep -q "$ZERONET_CONTAINER_NAME"; then
    docker kill "$ZERONET_CONTAINER_NAME"
    sleep 3
fi

#run zeronet docker
if ! docker ps | grep -q zeronet; then
    docker run --name "$ZERONET_CONTAINER_NAME" -d \
    -e ENABLE_TOR=true \
    -v "$DATA_DIR":/root/data \
    -v "$LOG_DIR":/root/log \
    -p 127.0.0.1:43111:43110 \
    "$ZERONET_BASE_DOCKER_IMAGE"

    #wait-for-it -t 30 127.0.0.1:43110
fi

#nginx
# if there's an existing running instance, let's kill it so we start from fresh.
NGINX_CONTAINER_NAME="nginx-proxy-$SITE_NAME"
if docker ps | grep -q "$NGINX_CONTAINER_NAME"; then
    docker kill "$NGINX_CONTAINER_NAME"
    sleep 3
fi

#nginx-proxy-bcmweb
#docker system prune -f >> /dev/null
docker run -d --name="$NGINX_CONTAINER_NAME" \
-p 8080:8080 \
-v "$(pwd)/site/nginx-proxy.conf:/etc/nginx/nginx.conf:ro" \
-v "$(pwd)/site/logs:/var/log/nginx" \
"$NGINX_IMAGE"

echo $(pwd)

#coputer - 127.0.0.1:43110
#zeronet docker - 43110
#nginx - 127.0.0.1:8080 -> 127.0.0.1:43110