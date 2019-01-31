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
	--image-name=*)
		DOCKER_HUB_IMAGE="${i#*=}"
		shift # past argument=value
		;;
	--registry=*)
		BCM_PRIVATE_REGISTY="${i#*=}"
		shift # past argument=value
		;;
	--priv-image-name=*)
		BCM_IMAGE_NAME="${i#*=}"
		shift # past argument=value
		;;
	--build)
		BCM_HELP_FLAG=1
		shift # past argument=value
		;;
	--build-context=*)
		BUILD_CONTEXT="${i#*=}"
		shift # past argument=value
		;;
	*)
		# unknown option
		;;
	esac
done

if [[ -z $LXC_HOST ]]; then
	echo "LXC_HOST is empty. Exiting"
	exit
fi

if [[ -z $BCM_IMAGE_NAME ]]; then
	echo "BCM_IMAGE_NAME is empty. Exiting"
	exit
fi

if [[ -z $BCM_PRIVATE_REGISTY ]]; then
	echo "BCM_PRIVATE_REGISTY is empty. Exiting"
	exit
fi

FULLY_QUALIFIED_IMAGE_NAME="$BCM_PRIVATE_REGISTY/$BCM_IMAGE_NAME"

if ! lxc list --format csv -c n | grep -q "$LXC_HOST"; then
	echo "LXC host '$LXC_HOST' doesn't exist. Exiting"
	exit
fi

if [[ ! -z $DOCKER_HUB_IMAGE ]]; then
	lxc exec "$LXC_HOST" -- docker pull "$DOCKER_HUB_IMAGE"
fi

# if the user has asked us to build an image, we will do so
if [[ $BCM_HELP_FLAG == 1 ]]; then
	# make sure they have passed a build context directory.
	if [[ -d $BUILD_CONTEXT ]]; then
		# let's make sure there's a dockerfile
		if [[ ! -f "$BUILD_CONTEXT/Dockerfile" ]]; then
			echo "There was no Dockerfile found in the build context."
			exit
		fi

		if [[ ! -z $FULLY_QUALIFIED_IMAGE_NAME ]]; then
			echo "Pushing contents of the build context to LXC host '$LXC_HOST'."
			lxc file push -r -p "$BUILD_CONTEXT/" "$LXC_HOST/root"
			lxc exec "$LXC_HOST" -- docker build -t "$FULLY_QUALIFIED_IMAGE_NAME" /root/build/
			IMAGE_TAGGED_FLAG=1
		else
			echo "BCM_IMAGE_NAME was empty."
			exit
		fi
	else
		echo "The build context '$BUILD_CONTEXT' directory does not exist."
	fi
fi

if [[ $IMAGE_TAGGED_FLAG == 0 ]]; then
	lxc exec "$LXC_HOST" -- docker tag "$DOCKER_HUB_IMAGE" "$FULLY_QUALIFIED_IMAGE_NAME"
fi

lxc exec "$LXC_HOST" -- docker push "$FULLY_QUALIFIED_IMAGE_NAME"
