#!/bin/bash

set -Eeuox pipefail
cd "$(dirname "$0")"

BCM_CLUSTER_ENDPOINT_NAME=
IS_MASTER=0
BCM_ENDPOINT_DIR=
BCM_PROVIDER_NAME=
BCM_LXD_PHYSICAL_INTERFACE=

for i in "$@"; do
	case $i in
	--endpoint-name=*)
		BCM_CLUSTER_ENDPOINT_NAME="${i#*=}"
		shift # past argument=value
		;;
	--master)
		IS_MASTER=1
		shift # past argument=value
		;;
	--endpoint-dir=*)
		BCM_ENDPOINT_DIR="${i#*=}"
		shift # past argument=value
		;;
	--provider=*)
		BCM_PROVIDER_NAME="${i#*=}"
		shift # past argument=value
		;;
	--network-interface=*)
		BCM_LXD_PHYSICAL_INTERFACE="${i#*=}"
		shift # past argument=value
		;;
	*)
		# unknown option
		;;
	esac
done

# create the file
mkdir -p $BCM_ENDPOINT_DIR
ENV_FILE=$BCM_ENDPOINT_DIR/.env
touch $ENV_FILE

# generate an LXD secret for the new VM lxd endpoint.
export BCM_CLUSTER_ENDPOINT_NAME=$BCM_CLUSTER_ENDPOINT_NAME
export BCM_PROVIDER_NAME=$BCM_PROVIDER_NAME
BCM_LXD_SECRET="$(apg -n 1 -m 30 -M CN)"
export BCM_LXD_SECRET="$BCM_LXD_SECRET"

if [[ $BCM_PROVIDER_NAME == "multipass" ]]; then
	BCM_LXD_PHYSICAL_INTERFACE="ens3"
fi

# if we're using SSH to provision, we need to figure out which
# physical interfaces are availble. We need to do this interactively
# over SSH.
if [[ $BCM_PROVIDER_NAME == "ssh" ]]; then
	# first let's check on the remote SSH service.
	wait-for-it -t 30 "$BCM_SSH_HOSTNAME:22"

	ssh -t "$BCM_SSH_USERNAME@$BCM_SSH_HOSTNAME" ip link show

	read -rp "Enter the name of the physical network interface you want to use for the data path:  " BCM_LXD_PHYSICAL_INTERFACE

	# TODO clean this up, error check.
fi

export BCM_LXD_PHYSICAL_INTERFACE="$BCM_LXD_PHYSICAL_INTERFACE"

if [ $IS_MASTER -eq 1 ]; then
	envsubst <./env/master_defaults.env >$ENV_FILE
elif [ $IS_MASTER -ne 1 ]; then
	envsubst <./env/member_defaults.env >$ENV_FILE
else
	echo "Incorrect usage. Please specify whether $BCM_CLUSTER_ENDPOINT_NAME is an LXD cluster master or member."
fi
