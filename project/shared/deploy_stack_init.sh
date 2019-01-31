#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

# shellcheck disable=1090
source "$BCM_GIT_DIR/env"

# iterate over endpoints and delete relevant resources
for endpoint in $(bcm cluster list --endpoints); do
    #echo $endpoint
    HOST_ENDING=$(echo "$endpoint" | tail -c 2)
    BROKER_STACK_NAME="broker-$(printf %02d "$HOST_ENDING")"
    
    # remove swarm services related to kafka
    bash -c "$BCM_LXD_OPS/remove_docker_stack.sh --stack-name=$BROKER_STACK_NAME"
done

if lxc list | grep -q "bcm-gateway-01"; then
    if lxc exec bcm-gateway-01 -- docker network ls | grep -q kafkanet; then
        lxc exec bcm-gateway-01 -- docker network remove kafkanet
    fi
fi

		;;
	*)
		# unknown option
		;;
	esac
done

if [ ! -f $BCM_ENV_FILE_PATH ]; then
	echo "BCM_ENV_FILE_PATH not set. Exiting."
	exit
else
	echo "BCM_ENV_FILE_PATH: $BCM_ENV_FILE_PATH"
fi

# shellcheck disable=SC1090
source "$BCM_ENV_FILE_PATH"
DIR_NAME="$(dirname $BCM_ENV_FILE_PATH)"

if [[ -z $BCM_IMAGE_NAME ]]; then
	echo "BCM_IMAGE_NAME not set. Exiting."
	exit
fi

if [[ -z $BCM_TIER_NAME ]]; then
	echo "BCM_TIER_NAME not set. Exiting."
	exit
fi

if [[ -z $BCM_STACK_NAME ]]; then
	echo "BCM_STACK_NAME not set. Exiting."
	exit
fi

if [[ -z $BCM_SERVICE_NAME ]]; then
	echo "BCM_SERVICE_NAME not set. Exiting."
	exit
fi

CONTAINER_NAME="bcm-$BCM_TIER_NAME-01"
if [[ $BCM_BUILD_FLAG == 1 ]]; then
	bash -c "$BCM_GIT_DIR/project/shared/docker_image_ops.sh --build --build-context=$DIR_NAME/build --container-name=$CONTAINER_NAME --priv-image-name=$BCM_IMAGE_NAME"
fi

if [[ $BCM_BUILD_FLAG == 0 ]]; then
	bash -c "$BCM_GIT_DIR/project/shared/docker_image_ops.sh --container-name=$CONTAINER_NAME --image-name=$DOCKERHUB_IMAGE --priv-image-name=$BCM_IMAGE_NAME"
fi

BCM_STACK_FILE_DIRNAME=$(dirname $BCM_ENV_FILE_PATH)

# push the stack file.
lxc file push -p -r "$BCM_STACK_FILE_DIRNAME/" "bcm-gateway-01/root/stacks/$BCM_TIER_NAME/"

# run the stack by passing in the ENV vars.

CONTAINER_STACK_DIR="/root/stacks/$BCM_TIER_NAME/$BCM_STACK_NAME"

lxc exec bcm-gateway-01 -- bash -c "source $CONTAINER_STACK_DIR/env && env BCM_IMAGE_NAME=$BCM_PRIVATE_REGISTRY/$BCM_IMAGE_NAME docker stack deploy -c $CONTAINER_STACK_DIR/$BCM_STACK_FILE $BCM_STACK_NAME"
