#!/bin/bash

set -Eeuo pipefail
cd "$(dirname "$0")"

# shellcheck disable=SC1090
source "$BCM_GIT_DIR/.env"

bcm project undeploy --project-name="$BCM_PROJECT_NAME" --cluster-name="$BCM_CLUSTER_NAME" --force || true

bcm cluster destroy --cluster-name="$BCM_CLUSTER_NAME"

if [[ -d "$BCM_UNENCRYPTED_VIEW_DIR" ]]; then
	fusermount -u -q "$BCM_UNENCRYPTED_VIEW_DIR" || true
	sleep 2
	sudo rm -Rf "$BCM_UNENCRYPTED_VIEW_DIR"
	sudo rm -Rf "$BCM_ENCRYPTED_DIR"
fi

if [[ -d $BCM_RUNTIME_DIR/.gnupg ]]; then
	sudo rm -Rf "$BCM_RUNTIME_DIR/.gnupg"
fi

if [[ -d $BCM_PASSWORDS_DIR ]]; then
	sudo rm -Rf "$BCM_PASSWORDS_DIR"
fi

sudo lxd init --auto

bcm show