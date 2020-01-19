#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

# let's make sure the bitcoin tier exists.
if ! lxc list --format csv --columns ns | grep "RUNNING" | grep -q "bcm-bitcoin-$BCM_ACTIVE_CHAIN"; then
    bash -c "$BCM_GIT_DIR/project/tiers/bitcoin/up.sh"
fi

source ./env

# now that the bitcoin tier is up, and presumably all other tiers, we can deploy this stack.
IMAGE_NAME="bcm-tor"
bash -c "$BCM_LXD_OPS/docker_image_ops.sh --build-context=$(pwd)/build --container-name=$BCM_UNDERLAY_HOST_NAME --image-name=$IMAGE_NAME"

# push the stack files up there.
lxc file push  -p -r ./stack/ "$BCM_MANAGER_HOST_NAME"/root/toronion
lxc exec "$BCM_MANAGER_HOST_NAME" -- env DOCKER_IMAGE="$IMAGE_NAME" docker stack deploy -c "/root/toronion/stack/toronion.yml" "toronion"
