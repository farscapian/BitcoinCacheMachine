#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

source ./env

# first, let's make sure we deploy our direct dependencies.
bcm stack deploy clightning

# env.sh has some of our naming conventions for DOCKERVOL and HOSTNAMEs and such.
source "$BCM_GIT_DIR/project/shared/env.sh"

# prepare the image.
"$BCM_GIT_DIR/project/shared/docker_image_ops.sh" \
--build-context="$(pwd)/build" \
--container-name="$LXC_HOSTNAME" \
--image-name="$IMAGE_NAME" \
--image-tag="$IMAGE_TAG"

# push the stack and build files
lxc file push -p -r "$(pwd)/stack/" "$BCM_GATEWAY_HOST_NAME/root/stacks/$TIER_NAME/$STACK_NAME"

lxc exec "$BCM_GATEWAY_HOST_NAME" -- env IMAGE_NAME="$BCM_PRIVATE_REGISTRY/$IMAGE_NAME:$IMAGE_TAG" \
CHAIN="$BCM_ACTIVE_CHAIN" \
LXC_HOSTNAME="$LXC_HOSTNAME" \
SERVICE_PORT="$SERVICE_PORT" \
docker stack deploy -c "/root/stacks/$TIER_NAME/$STACK_NAME/stack/$STACK_FILE" "$STACK_NAME-$BCM_ACTIVE_CHAIN"

ENDPOINT=$(bcm get-ip)
wait-for-it -t 0 "$ENDPOINT:$SERVICE_PORT"

# let's the the pariing URL from the container output
PAIRING_OUTPUT_URL=$(lxc exec "$BCM_GATEWAY_HOST_NAME" --  docker service logs "spark-$BCM_ACTIVE_CHAIN""_spark" | grep 'Pairing URL: ' | awk '{print $5}')
SPARK_URL=${PAIRING_OUTPUT_URL/0.0.0.0/$ENDPOINT}

xdg-open "$SPARK_URL" &
